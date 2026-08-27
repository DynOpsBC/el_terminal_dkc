codeunit 72045 "DOPSWHS Movement Mgmt"
{
    Access = Public;
    Permissions =
        tabledata Item = R,
        tabledata "Item Tracking Code" = R,
        tabledata Location = R,
        tabledata Bin = R,
        tabledata "Item Journal Template" = RIMD,
        tabledata "Item Journal Batch" = RIMD,
        tabledata "Item Journal Line" = RIMD,
        tabledata "Warehouse Journal Template" = RIMD,
        tabledata "Warehouse Journal Batch" = RIMD,
        tabledata "Warehouse Journal Line" = RIMD,
        tabledata "Reservation Entry" = RIMD,
        tabledata "Whse. Item Tracking Line" = RIMD;

    procedure EnsureDeviceJournalBatch(UserId: Code[50]): Code[10]
    var
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        BatchName: Code[10];
    begin
        BatchName := CopyStr('DOPS-' + CopyStr(DelChr(UserId, '=', ' /\.:;,*?<>|'), 1, 5), 1, 10);
        if BatchName = 'DOPS-' then
            BatchName := 'DOPS-USER';

        EnsureReclassTemplate(ItemJournalTemplate);
        if not ItemJournalBatch.Get(ItemJournalTemplate.Name, BatchName) then begin
            ItemJournalBatch.Init();
            ItemJournalBatch."Journal Template Name" := ItemJournalTemplate.Name;
            ItemJournalBatch.Name := BatchName;
            ItemJournalBatch.Description := CopyStr('DOPSWHS mobile ' + UserId, 1, MaxStrLen(ItemJournalBatch.Description));
            ItemJournalBatch.Recurring := false;
            ItemJournalBatch.Insert(true);
        end else
            if ItemJournalBatch.Recurring then begin
                ItemJournalBatch.Recurring := false;
                ItemJournalBatch.Modify(true);
            end;

        exit(BatchName);
    end;

    /// <summary>Geriye dönük sarmalayıcı — lot izlemesiz ürünler.</summary>
    procedure AdHocMove(FromBinCode: Code[20]; ToBinCode: Code[20]; ItemNo: Code[20]; LpNo: Code[20]; Qty: Decimal; UserId: Code[50])
    begin
        AdHocMove(FromBinCode, ToBinCode, ItemNo, LpNo, Qty, UserId, '');
    end;

    procedure AdHocMove(FromBinCode: Code[20]; ToBinCode: Code[20]; ItemNo: Code[20]; LpNo: Code[20]; Qty: Decimal; UserId: Code[50]; LotNo: Code[50])
    var
        Setup: Record "DOPSWHS Setup";
        LocationCode: Code[10];
    begin
        Setup.Get('');
        // The mobile form captures bins, not a location. Resolve the location from the source bin
        // (the bins are location-scoped) so the reclass posts where the bin actually lives, instead
        // of forcing the Setup default location (which may not own this bin).
        LocationCode := ResolveLocationForBin(FromBinCode, Setup."Default Location Code");
        ExecuteAdHocMove(LocationCode, FromBinCode, ToBinCode, ItemNo, LpNo, Qty, UserId, LotNo, '');
    end;

    /// <summary>
    /// Posts a bin-to-bin move in an explicitly known location. LP operations use this overload so
    /// an identically named bin in another location can never receive the stock accidentally.
    /// </summary>
    procedure AdHocMoveAtLocation(LocationCode: Code[10]; FromBinCode: Code[20]; ToBinCode: Code[20]; ItemNo: Code[20]; LpNo: Code[20]; Qty: Decimal; UserId: Code[50]; LotNo: Code[50])
    begin
        ExecuteAdHocMove(LocationCode, FromBinCode, ToBinCode, ItemNo, LpNo, Qty, UserId, LotNo, '');
    end;

    /// <summary>
    /// Posts a lot/serial tracked bin move in an explicitly known location.
    /// Serial quantity is expressed in the item's base unit and must be one.
    /// </summary>
    procedure AdHocMoveTrackedAtLocation(LocationCode: Code[10]; FromBinCode: Code[20]; ToBinCode: Code[20]; ItemNo: Code[20]; LpNo: Code[20]; Qty: Decimal; UserId: Code[50]; LotNo: Code[50]; SerialNo: Code[50])
    begin
        ExecuteAdHocMove(LocationCode, FromBinCode, ToBinCode, ItemNo, LpNo, Qty, UserId, LotNo, SerialNo);
    end;

    local procedure ExecuteAdHocMove(LocationCode: Code[10]; FromBinCode: Code[20]; ToBinCode: Code[20]; ItemNo: Code[20]; LpNo: Code[20]; Qty: Decimal; UserId: Code[50]; LotNo: Code[50]; SerialNo: Code[50])
    var
        Location: Record Location;
        FromBin: Record Bin;
        ToBin: Record Bin;
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalLine: Record "Item Journal Line";
        ItemJnlPostBatch: Codeunit "Item Jnl.-Post Batch";
        Telemetry: Codeunit "DOPSWHS Telemetry";
        CustomDimensions: Dictionary of [Text, Text];
        BatchName: Code[10];
    begin
        if ItemNo = '' then
            Error('Item No. is required for ad-hoc moves.');
        if Qty <= 0 then
            Error('Quantity must be greater than zero.');
        if LocationCode = '' then
            Error('Cannot determine a location for bin %1. Set a Default Location Code in DOPSWHS Setup, or scan a bin that exists in a warehouse location.', FromBinCode);
        if FromBinCode = '' then
            Error('Source bin is required.');
        if ToBinCode = '' then
            Error('Target bin is required.');
        if FromBinCode = ToBinCode then
            Error('Source bin and target bin must be different.');
        if not Location.Get(LocationCode) then
            Error('Location %1 does not exist.', LocationCode);
        if not FromBin.Get(LocationCode, FromBinCode) then
            Error('Source bin %1 does not exist in location %2.', FromBinCode, LocationCode);
        if not ToBin.Get(LocationCode, ToBinCode) then
            Error('Target bin %1 does not exist in location %2.', ToBinCode, LocationCode);
        Item.Get(ItemNo);
        if (Item."Item Tracking Code" <> '') and ItemTrackingCode.Get(Item."Item Tracking Code") then begin
            if (ItemTrackingCode."Lot Specific Tracking" or ItemTrackingCode."Lot Warehouse Tracking") and (LotNo = '') then
                Error('%1 lot takipli maddesi için lot numarası zorunludur.', ItemNo);
            if (ItemTrackingCode."SN Specific Tracking" or ItemTrackingCode."SN Warehouse Tracking") and (SerialNo = '') then
                Error('%1 seri takipli maddesi için seri numarası zorunludur.', ItemNo);
        end;
        if (SerialNo <> '') and (Qty <> 1) then
            Error('%1 seri numarası tek bir temel birimi temsil eder; hareket miktarı 1 olmalıdır.', SerialNo);

        // Yönlendirilmiş (Directed Put-away and Pick) lokasyonda Item Journal
        // bin taşıyamaz — post adjustment bin'den (W-99-...) geçer ve raf
        // seviyesinde hareket OLMAZ. Doğru araç: Warehouse Reclass Journal
        // (Movement) — bin'den bin'e, ILE'ye dokunmadan.
        if Location."Directed Put-away and Pick" then begin
            RegisterWhseMove(LocationCode, FromBinCode, ToBinCode, ItemNo, Qty, UserId, LotNo, SerialNo);
            CustomDimensions.Add('Category', 'Movement');
            // Hareketi yapan operatör terminalden parametre olarak geliyor
            // (UserId parametresi). Paylaşımlı BC hesabı ile ayırt edilemezdi;
            // log satırına operatör alanları da yazılır.
            Telemetry.AddUserDimensions(CustomDimensions, UserId);
            Session.LogMessage('DOPSWHS-Move-AdHocWhse', StrSubstNo('Directed whse move item %1 qty %2 from %3 to %4 lp %5', ItemNo, Qty, FromBinCode, ToBinCode, LpNo), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
            exit;
        end;
        EnsureReclassTemplate(ItemJournalTemplate);
        BatchName := EnsureDeviceJournalBatch(UserId);

        // Takılı satır koruması (whse yolundakiyle aynı gerekçe): post tüm
        // sayfayı işler; önceki başarısız denemenin artığı her yeni hareketi
        // düşürür. Bizim sayfamızda post öncesi ne varsa artıktır — temizle.
        PurgeStaleItemLines(ItemJournalTemplate.Name, BatchName);

        CreateReclassLine(ItemJournalTemplate.Name, BatchName, LocationCode, FromBinCode, ToBinCode, ItemNo, LpNo, Qty, ItemJournalLine);
        // Lot/seri izlemeli ürün: reclass satırına item tracking bağla — yoksa
        // post zorunlu izleme bilgisi eksik hatasıyla düşer.
        // DİKKAT (17 Tem saha hatası): satırın kendi "Lot No."/"New Lot No."
        // alanları DOLDURULMAZ — reservation entry (tracking spec) varken
        // codeunit 22 satır alanlarının boş olmasını şart koşar ("New Lot No.
        // must be equal to ''"). İzleme yalnızca AddItemTracking'in oluşturduğu
        // reservation kaydında taşınır (lot/seri + yeni lot/seri).
        if (LotNo <> '') or (SerialNo <> '') then
            AddItemTracking(ItemJournalLine, LotNo, SerialNo);
        CustomDimensions.Add('Category', 'Movement');
        Telemetry.AddUserDimensions(CustomDimensions, UserId);
        Session.LogMessage('DOPSWHS-Move-AdHoc', StrSubstNo('Ad-hoc move item %1 qty %2 from %3 to %4 lp %5', ItemNo, Qty, FromBinCode, ToBinCode, LpNo), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
        // Post via batch codeunit (22/23) rather than "Item Jnl.-Post" (241): the latter raises a
        // "Do you want to post?" Confirm that fails as a client callback over the API / on the handheld.
        ItemJnlPostBatch.SetSuppressCommit(true);
        ItemJnlPostBatch.Run(ItemJournalLine);
    end;

    /// <summary>Geriye dönük imza: operatör kimliği belgenin atamasından okunur.</summary>
    procedure RegisterDirected(var WhseActivityHeader: Record "Warehouse Activity Header")
    begin
        RegisterDirected(WhseActivityHeader, '');
    end;

    /// <summary>
    /// Ambar aktivitesini kaydeder. OperatorUserId = işlemi yapan WMS operatörü;
    /// boşsa belgeye atanmış kullanıcıya düşülür. NEDEN: tüm çağrılar paylaşımlı
    /// servis hesabıyla geldiği için UserId() "kim kaydetti" sorusunu cevaplamıyor.
    /// </summary>
    procedure RegisterDirected(var WhseActivityHeader: Record "Warehouse Activity Header"; OperatorUserId: Code[50])
    var
        WhseActivityLine: Record "Warehouse Activity Line";
        // QM (BC 28) devre dışı — bkz. QualityMgmtBridge.Codeunit.al
        // QualityBridge: Codeunit "DOPSWHS Quality Mgmt Bridge";
        WhseActivityRegister: Codeunit "Whse.-Activity-Register";
        Telemetry: Codeunit "DOPSWHS Telemetry";
        CustomDimensions: Dictionary of [Text, Text];
        Operator: Code[50];
    begin
        if OperatorUserId <> '' then
            Operator := OperatorUserId
        else
            Operator := WhseActivityHeader."Assigned User ID";

        CustomDimensions.Add('Category', 'Movement');
        Telemetry.AddUserDimensions(CustomDimensions, Operator);
        Session.LogMessage('DOPSWHS-Move-RegisterDirected', StrSubstNo('Register warehouse activity %1 type %2', WhseActivityHeader."No.", Format(WhseActivityHeader.Type)), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);

        // MS Quality Management lot/serial block guard — QM (BC 28) devre dışı.
        // BC 28'e geçince aşağıdaki bloğun yorumunu kaldırın.
        // WhseActivityLine.SetRange("Activity Type", WhseActivityHeader.Type);
        // WhseActivityLine.SetRange("No.", WhseActivityHeader."No.");
        // if WhseActivityLine.FindSet() then
        //     repeat
        //         QualityBridge.VerifyNotBlocked(
        //             WhseActivityLine."Lot No.",
        //             WhseActivityLine."Serial No.",
        //             '');
        //     until WhseActivityLine.Next() = 0;

        WhseActivityLine.SetRange("Activity Type", WhseActivityHeader.Type);
        WhseActivityLine.SetRange("No.", WhseActivityHeader."No.");
        if WhseActivityLine.FindFirst() then
            WhseActivityRegister.Run(WhseActivityLine);
    end;

    /// <summary>
    /// Claims an unassigned directed movement for the local WMS user. The
    /// shared Business Central service account is deliberately not used as the
    /// warehouse operator identity.
    /// </summary>
    procedure ClaimDirected(var WhseActivityHeader: Record "Warehouse Activity Header"; RequestingUserId: Code[50])
    var
        LockedHeader: Record "Warehouse Activity Header";
    begin
        if RequestingUserId = '' then
            Error('WMS kullanıcı kimliği boş olamaz. Terminal oturumunu yenileyin.');

        LockedHeader.LockTable();
        if not LockedHeader.Get(LockedHeader.Type::Movement, WhseActivityHeader."No.") then
            Error('Hareket belgesi %1 artık bulunamıyor. Listeyi yenileyin.', WhseActivityHeader."No.");
        if (LockedHeader."Assigned User ID" <> '') and
           (LockedHeader."Assigned User ID" <> RequestingUserId)
        then
            Error('Hareket belgesi %1, %2 kullanıcısına atanmış.', LockedHeader."No.", LockedHeader."Assigned User ID");

        if LockedHeader."Assigned User ID" <> RequestingUserId then begin
            LockedHeader."Assigned User ID" := CopyStr(RequestingUserId, 1, MaxStrLen(LockedHeader."Assigned User ID"));
            LockedHeader.Modify(true);
        end;
        WhseActivityHeader := LockedHeader;
    end;

    /// <summary>
    /// Updates a movement Take/Place pair together. Writing only the tapped
    /// row leaves its companion at zero and prevents warehouse registration.
    /// </summary>
    procedure ConfirmDirectedLineFor(var WhseActivityLine: Record "Warehouse Activity Line"; QtyToHandle: Decimal; LotNo: Code[50]; SerialNo: Code[50]; RequestingUserId: Code[50])
    var
        WhseActivityHeader: Record "Warehouse Activity Header";
        CompanionLine: Record "Warehouse Activity Line";
    begin
        if RequestingUserId = '' then
            Error('WMS kullanıcı kimliği boş olamaz. Terminal oturumunu yenileyin.');
        if WhseActivityLine."Activity Type" <> WhseActivityLine."Activity Type"::Movement then
            Error('%1 ambar aktivitesi yönlendirilmiş hareket değildir.', WhseActivityLine."No.");
        if not WhseActivityHeader.Get(WhseActivityHeader.Type::Movement, WhseActivityLine."No.") then
            Error('Hareket belgesi %1 artık bulunamıyor. Listeyi yenileyin.', WhseActivityLine."No.");
        if WhseActivityHeader."Assigned User ID" <> RequestingUserId then
            Error('Hareket belgesi %1 bu kullanıcıya atanmış değil.', WhseActivityLine."No.");
        // Eş satırı, kullanıcının seçtiği yeni lotu yazmadan önce mevcut
        // satır anahtarlarıyla bul. Aksi halde lotu boş oluşturulmuş Place satırı,
        // lot girilen Take satırıyla artık eşleşmez.
        WhseActivityLine.LockTable();
        if not WhseActivityLine.Get(
             WhseActivityLine."Activity Type", WhseActivityLine."No.", WhseActivityLine."Line No.")
        then
            Error('Hareket satırı %1 artık bulunamıyor. Belgeyi yenileyin.', WhseActivityLine."Line No.");
        if (QtyToHandle <= 0) or (QtyToHandle > WhseActivityLine."Qty. Outstanding") then
            Error('%1 satırı için hareket miktarı 0 ile %2 arasında olmalıdır.', WhseActivityLine."Line No.", WhseActivityLine."Qty. Outstanding");

        CompanionLine.SetRange("Activity Type", WhseActivityLine."Activity Type");
        CompanionLine.SetRange("No.", WhseActivityLine."No.");
        CompanionLine.SetRange("Whse. Document Type", WhseActivityLine."Whse. Document Type");
        CompanionLine.SetRange("Whse. Document No.", WhseActivityLine."Whse. Document No.");
        CompanionLine.SetRange("Whse. Document Line No.", WhseActivityLine."Whse. Document Line No.");
        CompanionLine.SetRange("Item No.", WhseActivityLine."Item No.");
        CompanionLine.SetRange("Variant Code", WhseActivityLine."Variant Code");
        CompanionLine.SetRange("Unit of Measure Code", WhseActivityLine."Unit of Measure Code");
        CompanionLine.SetRange("Lot No.", WhseActivityLine."Lot No.");
        CompanionLine.SetRange("Serial No.", WhseActivityLine."Serial No.");
        CompanionLine.SetRange("Package No.", WhseActivityLine."Package No.");
        CompanionLine.SetRange("LP No.", WhseActivityLine."LP No.");
        if WhseActivityLine."Action Type" = WhseActivityLine."Action Type"::Take then
            CompanionLine.SetRange("Action Type", CompanionLine."Action Type"::Place)
        else
            CompanionLine.SetRange("Action Type", CompanionLine."Action Type"::Take);
        if CompanionLine.Count() <> 1 then
            Error(
                '%1 hareket satırı için lot/seri/LP bilgileriyle eşleşen tek bir karşı satır bulunamadı. Belgeyi BC''de yeniden oluşturun.',
                WhseActivityLine."Line No.");
        CompanionLine.FindFirst();

        EnsureDirectedMovementTracking(WhseActivityLine, QtyToHandle, LotNo, SerialNo);
        WhseActivityLine.Validate("Lot No.", LotNo);
        WhseActivityLine.Validate("Serial No.", SerialNo);
        WhseActivityLine.Validate("Qty. to Handle", QtyToHandle);
        WhseActivityLine.Modify(true);
        CompanionLine.Validate("Lot No.", LotNo);
        CompanionLine.Validate("Serial No.", SerialNo);
        CompanionLine.Validate("Qty. to Handle", QtyToHandle);
        CompanionLine.Modify(true);
    end;

    local procedure EnsureDirectedMovementTracking(WhseActivityLine: Record "Warehouse Activity Line"; QtyToHandle: Decimal; LotNo: Code[50]; SerialNo: Code[50])
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        if QtyToHandle <= 0 then
            exit;
        if not Item.Get(WhseActivityLine."Item No.") then
            exit;
        if (Item."Item Tracking Code" = '') or (not ItemTrackingCode.Get(Item."Item Tracking Code")) then
            exit;
        if (ItemTrackingCode."Lot Specific Tracking" or ItemTrackingCode."Lot Warehouse Tracking") and (LotNo = '') then
            Error(
                '%1 ürününün %2 hareket satırında lot numarası zorunludur. %3 rafındaki stok lotlarından birini seçin.',
                WhseActivityLine."Item No.", WhseActivityLine."Line No.", WhseActivityLine."Bin Code");
        if (ItemTrackingCode."SN Specific Tracking" or ItemTrackingCode."SN Warehouse Tracking") and (SerialNo = '') then
            Error(
                '%1 ürününün %2 hareket satırında seri numarası zorunludur. %3 rafındaki stok serisini okutun.',
                WhseActivityLine."Item No.", WhseActivityLine."Line No.", WhseActivityLine."Bin Code");
    end;

    procedure RegisterDirectedFor(var WhseActivityHeader: Record "Warehouse Activity Header"; RequestingUserId: Code[50])
    var
        LockedHeader: Record "Warehouse Activity Header";
    begin
        if RequestingUserId = '' then
            Error('WMS kullanıcı kimliği boş olamaz. Terminal oturumunu yenileyin.');
        LockedHeader.LockTable();
        if not LockedHeader.Get(LockedHeader.Type::Movement, WhseActivityHeader."No.") then
            Error('Hareket belgesi %1 artık bulunamıyor. Listeyi yenileyin.', WhseActivityHeader."No.");
        if LockedHeader."Assigned User ID" <> RequestingUserId then
            Error('Hareket belgesi %1 bu kullanıcıya atanmış değil.', LockedHeader."No.");
        WhseActivityHeader := LockedHeader;
        RegisterDirected(WhseActivityHeader, RequestingUserId);
    end;

    local procedure EnsureReclassTemplate(var ItemJournalTemplate: Record "Item Journal Template")
    begin
        ItemJournalTemplate.SetRange(Type, ItemJournalTemplate.Type::Transfer);
        if not ItemJournalTemplate.FindFirst() then begin
            ItemJournalTemplate.Init();
            ItemJournalTemplate.Name := 'RECLASS';
            ItemJournalTemplate.Type := ItemJournalTemplate.Type::Transfer;
            ItemJournalTemplate.Description := 'Item Reclass Journal';
            ItemJournalTemplate.Insert(true);
        end;
    end;

    local procedure ResolveLocationForBin(FromBinCode: Code[20]; DefaultLocation: Code[10]): Code[10]
    var
        Bin: Record Bin;
    begin
        if FromBinCode = '' then
            exit(DefaultLocation);
        // Prefer the configured default location when the bin actually exists there.
        if (DefaultLocation <> '') and Bin.Get(DefaultLocation, FromBinCode) then
            exit(DefaultLocation);
        // Otherwise find the location that owns this bin code.
        Bin.SetRange(Code, FromBinCode);
        if Bin.FindFirst() then
            exit(Bin."Location Code");
        exit(DefaultLocation);
    end;

    // ---- Yönlendirilmiş lokasyon: Warehouse Reclass Journal (bin-to-bin) ----

    local procedure RegisterWhseMove(LocationCode: Code[10]; FromBinCode: Code[20]; ToBinCode: Code[20]; ItemNo: Code[20]; Qty: Decimal; UserId: Code[50]; LotNo: Code[50]; SerialNo: Code[50])
    var
        Item: Record Item;
        FromBin: Record Bin;
        ToBin: Record Bin;
        WhseJournalTemplate: Record "Warehouse Journal Template";
        WhseJournalLine: Record "Warehouse Journal Line";
        WhseJnlRegisterBatch: Codeunit "Whse. Jnl.-Register Batch";
        BatchName: Code[10];
    begin
        FromBin.Get(LocationCode, FromBinCode);
        ToBin.Get(LocationCode, ToBinCode);
        Item.Get(ItemNo);

        EnsureWhseReclassTemplate(WhseJournalTemplate);
        BatchName := EnsureWhseJournalBatch(WhseJournalTemplate.Name, LocationCode);

        // Saha hatası ("The Item does not exist. No.=''"): register TÜM sayfayı
        // postalar; önceki başarısız denemeden takılı (yarım/bozuk) satır varsa
        // her yeni hareketi düşürür. DOPS-MOBIL bizim özel sayfamız — başarılı
        // post satırları zaten siler, burada ne varsa artıktır: temizle.
        PurgeStaleWhseLines(WhseJournalTemplate.Name, BatchName, LocationCode);

        WhseJournalLine.Init();
        WhseJournalLine.Validate("Journal Template Name", WhseJournalTemplate.Name);
        WhseJournalLine.Validate("Journal Batch Name", BatchName);
        WhseJournalLine.Validate("Location Code", LocationCode);
        WhseJournalLine."Line No." := NextWhseLineNo(WhseJournalTemplate.Name, BatchName, LocationCode);
        WhseJournalLine."Registering Date" := WorkDate();
        WhseJournalLine."User ID" := CopyStr(UserId, 1, MaxStrLen(WhseJournalLine."User ID"));
        WhseJournalLine.Validate("Entry Type", WhseJournalLine."Entry Type"::Movement);
        WhseJournalLine.Validate("Item No.", ItemNo);
        WhseJournalLine.Validate("Unit of Measure Code", Item."Base Unit of Measure");
        WhseJournalLine.Validate("From Zone Code", FromBin."Zone Code");
        WhseJournalLine.Validate("From Bin Code", FromBinCode);
        WhseJournalLine.Validate("To Zone Code", ToBin."Zone Code");
        WhseJournalLine.Validate("To Bin Code", ToBinCode);
        WhseJournalLine.Validate(Quantity, Qty);
        WhseJournalLine.Insert(true);

        // Saha hatası (17 Tem): "Item tracking lines ... must account for the
        // same quantity" — whse journal izlemeyi satır alanından DEĞİL, bağlı
        // "Whse. Item Tracking Line" kaydından okur (UI'daki Item Tracking
        // Lines sayfasının kod karşılığı).
        if (LotNo <> '') or (SerialNo <> '') then
            AddWhseItemTracking(WhseJournalLine, LotNo, SerialNo);

        // Item Jnl.-Post Batch'in ambar karşılığı — confirm diyaloğu açmadan
        // register eder (web servis bağlamı).
        WhseJnlRegisterBatch.SetSuppressCommit(true);
        WhseJnlRegisterBatch.Run(WhseJournalLine);
    end;

    local procedure AddWhseItemTracking(WhseJnlLine: Record "Warehouse Journal Line"; LotNo: Code[50]; SerialNo: Code[50])
    var
        WhseItemTrackingLine: Record "Whse. Item Tracking Line";
        EntryNo: Integer;
    begin
        WhseItemTrackingLine.Reset();
        if WhseItemTrackingLine.FindLast() then
            EntryNo := WhseItemTrackingLine."Entry No.";
        WhseItemTrackingLine.Init();
        WhseItemTrackingLine."Entry No." := EntryNo + 1;
        WhseItemTrackingLine."Item No." := WhseJnlLine."Item No.";
        WhseItemTrackingLine."Variant Code" := WhseJnlLine."Variant Code";
        WhseItemTrackingLine."Location Code" := WhseJnlLine."Location Code";
        WhseItemTrackingLine."Source Type" := Database::"Warehouse Journal Line";
        // DİKKAT — BC'nin bilinen alan TERSLİĞİ (saha hatası "Tracking total: 0"):
        // whse journal için base app "Source ID"ye BATCH adını, "Source Batch
        // Name"e TEMPLATE adını yazar (ItemTrackingManagement.SplitWhseJnlLine
        // aramayı bu terslikle yapar). Düz eşleme kayıt bulunamamasına yol açar.
        WhseItemTrackingLine."Source ID" := WhseJnlLine."Journal Batch Name";
        WhseItemTrackingLine."Source Batch Name" := WhseJnlLine."Journal Template Name";
        WhseItemTrackingLine."Source Ref. No." := WhseJnlLine."Line No.";
        WhseItemTrackingLine."Qty. per Unit of Measure" := WhseJnlLine."Qty. per Unit of Measure";
        WhseItemTrackingLine.Validate("Quantity (Base)", WhseJnlLine."Qty. (Base)");
        WhseItemTrackingLine."Lot No." := LotNo;
        WhseItemTrackingLine."Serial No." := SerialNo;
        // Reclass: aynı lot/seri hedef bin'e taşınır.
        WhseItemTrackingLine."New Lot No." := LotNo;
        WhseItemTrackingLine."New Serial No." := SerialNo;
        WhseItemTrackingLine.Insert();
    end;

    local procedure EnsureWhseReclassTemplate(var WhseJournalTemplate: Record "Warehouse Journal Template")
    begin
        if WhseJournalTemplate.Get('RECLASS') then
            exit;
        WhseJournalTemplate.Init();
        WhseJournalTemplate.Name := 'RECLASS';
        WhseJournalTemplate.Description := 'BCWMS directed bin-to-bin moves';
        WhseJournalTemplate.Validate(Type, WhseJournalTemplate.Type::Reclassification);
        WhseJournalTemplate.Insert(true);
    end;

    // Warehouse Journal Batch anahtarı lokasyon içerir (template + name + location).
    local procedure EnsureWhseJournalBatch(TemplateName: Code[10]; LocationCode: Code[10]): Code[10]
    var
        WhseJournalBatch: Record "Warehouse Journal Batch";
        BatchName: Code[10];
    begin
        BatchName := 'DOPS-MOBIL';
        if not WhseJournalBatch.Get(TemplateName, BatchName, LocationCode) then begin
            WhseJournalBatch.Init();
            WhseJournalBatch."Journal Template Name" := TemplateName;
            WhseJournalBatch.Name := BatchName;
            WhseJournalBatch."Location Code" := LocationCode;
            WhseJournalBatch.Description := 'BCWMS mobil ad-hoc hareketler';
            WhseJournalBatch.Insert(true);
        end;
        exit(BatchName);
    end;

    local procedure PurgeStaleItemLines(TemplateName: Code[10]; BatchName: Code[10])
    var
        StaleLine: Record "Item Journal Line";
        StaleReservEntry: Record "Reservation Entry";
    begin
        StaleLine.SetRange("Journal Template Name", TemplateName);
        StaleLine.SetRange("Journal Batch Name", BatchName);
        if not StaleLine.IsEmpty() then
            StaleLine.DeleteAll(true);
        StaleReservEntry.SetRange("Source Type", Database::"Item Journal Line");
        StaleReservEntry.SetRange("Source ID", TemplateName);
        StaleReservEntry.SetRange("Source Batch Name", BatchName);
        if not StaleReservEntry.IsEmpty() then
            StaleReservEntry.DeleteAll(true);
    end;

    local procedure PurgeStaleWhseLines(TemplateName: Code[10]; BatchName: Code[10]; LocationCode: Code[10])
    var
        StaleLine: Record "Warehouse Journal Line";
        StaleTracking: Record "Whse. Item Tracking Line";
    begin
        StaleLine.SetRange("Journal Template Name", TemplateName);
        StaleLine.SetRange("Journal Batch Name", BatchName);
        StaleLine.SetRange("Location Code", LocationCode);
        if not StaleLine.IsEmpty() then
            StaleLine.DeleteAll(true);
        // Takılı satırların tracking kayıtları da temizlenir (ters alan
        // eşlemesiyle: Source ID = batch, Source Batch Name = template).
        StaleTracking.SetRange("Source Type", Database::"Warehouse Journal Line");
        StaleTracking.SetRange("Source ID", BatchName);
        StaleTracking.SetRange("Source Batch Name", TemplateName);
        StaleTracking.SetRange("Location Code", LocationCode);
        if not StaleTracking.IsEmpty() then
            StaleTracking.DeleteAll(true);
    end;

    local procedure NextWhseLineNo(TemplateName: Code[10]; BatchName: Code[10]; LocationCode: Code[10]): Integer
    var
        ExistingLine: Record "Warehouse Journal Line";
    begin
        ExistingLine.SetRange("Journal Template Name", TemplateName);
        ExistingLine.SetRange("Journal Batch Name", BatchName);
        ExistingLine.SetRange("Location Code", LocationCode);
        if ExistingLine.FindLast() then
            exit(ExistingLine."Line No." + 10000);
        exit(10000);
    end;

    // Reclass satırına item tracking: aynı lot/seri kaynaktan düşülüp hedefe
    // yazılır. Standart desen: Create Reserv. Entry ile
    // Prospect rezervasyon kaydı (item journal post bunu tracking spec olarak okur).
    local procedure AddItemTracking(var ItemJnlLine: Record "Item Journal Line"; LotNo: Code[50]; SerialNo: Code[50])
    var
        TempReservEntry: Record "Reservation Entry";
        ReservEntry: Record "Reservation Entry";
        CreateReservEntry: Codeunit "Create Reserv. Entry";
    begin
        TempReservEntry."Lot No." := LotNo;
        TempReservEntry."New Lot No." := LotNo;
        TempReservEntry."Serial No." := SerialNo;
        TempReservEntry."New Serial No." := SerialNo;
        CreateReservEntry.CreateReservEntryFor(
            Database::"Item Journal Line",
            ItemJnlLine."Entry Type".AsInteger(),
            ItemJnlLine."Journal Template Name",
            ItemJnlLine."Journal Batch Name",
            0,
            ItemJnlLine."Line No.",
            ItemJnlLine."Qty. per Unit of Measure",
            ItemJnlLine.Quantity,
            ItemJnlLine."Quantity (Base)",
            TempReservEntry);
        CreateReservEntry.CreateEntry(
            ItemJnlLine."Item No.", ItemJnlLine."Variant Code", ItemJnlLine."Location Code",
            ItemJnlLine.Description, 0D, 0D, 0, Enum::"Reservation Status"::Prospect);

        // Create Reserv. Entry, ForReservEntry'deki "New Lot No."yu Prospect
        // kaydına TAŞIMIYOR (saha hatası: New Lot No. boş kaldı) — oluşan
        // kayıtları bulup reclass hedef lotunu doğrudan yaz.
        ReservEntry.SetRange("Source Type", Database::"Item Journal Line");
        ReservEntry.SetRange("Source Subtype", ItemJnlLine."Entry Type".AsInteger());
        ReservEntry.SetRange("Source ID", ItemJnlLine."Journal Template Name");
        ReservEntry.SetRange("Source Batch Name", ItemJnlLine."Journal Batch Name");
        ReservEntry.SetRange("Source Ref. No.", ItemJnlLine."Line No.");
        if LotNo <> '' then
            ReservEntry.SetRange("Lot No.", LotNo);
        if SerialNo <> '' then
            ReservEntry.SetRange("Serial No.", SerialNo);
        if ReservEntry.FindSet(true) then
            repeat
                if ReservEntry."New Lot No." = '' then begin
                    ReservEntry."New Lot No." := LotNo;
                end;
                if ReservEntry."New Serial No." = '' then
                    ReservEntry."New Serial No." := SerialNo;
                ReservEntry.Modify();
            until ReservEntry.Next() = 0;
    end;

    local procedure CreateReclassLine(TemplateName: Code[10]; BatchName: Code[10]; LocationCode: Code[10]; FromBinCode: Code[20]; ToBinCode: Code[20]; ItemNo: Code[20]; LpNo: Code[20]; Qty: Decimal; var ItemJournalLine: Record "Item Journal Line")
    var
        ExistingLine: Record "Item Journal Line";
        NextLineNo: Integer;
    begin
        ExistingLine.SetRange("Journal Template Name", TemplateName);
        ExistingLine.SetRange("Journal Batch Name", BatchName);
        if ExistingLine.FindLast() then
            NextLineNo := ExistingLine."Line No." + 10000
        else
            NextLineNo := 10000;

        ItemJournalLine.Init();
        ItemJournalLine."Journal Template Name" := TemplateName;
        ItemJournalLine."Journal Batch Name" := BatchName;
        ItemJournalLine."Line No." := NextLineNo;
        ItemJournalLine."Posting Date" := WorkDate();
        ItemJournalLine."Document No." := CopyStr('DOPS-' + Format(Today(), 0, '<Year4><Month,2><Day,2>'), 1, MaxStrLen(ItemJournalLine."Document No."));
        ItemJournalLine."Entry Type" := ItemJournalLine."Entry Type"::Transfer;
        ItemJournalLine.Validate("Item No.", ItemNo);
        ItemJournalLine.Validate("Location Code", LocationCode);
        ItemJournalLine.Validate("New Location Code", LocationCode);
        ItemJournalLine.Validate("Bin Code", FromBinCode);
        ItemJournalLine.Validate("New Bin Code", ToBinCode);
        ItemJournalLine.Validate(Quantity, Qty);
        ItemJournalLine."Package No." := LpNo;
        ItemJournalLine.Insert(true);
    end;
}
