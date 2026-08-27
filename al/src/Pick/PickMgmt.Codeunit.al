codeunit 72046 "DOPSWHS Pick Mgmt"
{
    Access = Public;

    procedure AssignToMe(var Pick: Record "Warehouse Activity Header")
    var
        CurrentUserId: Code[50];
    begin
        // Terminalde WMS oturumu yoksa operatör BC hesabı olarak üstlenir.
        // İş kuralı kontrolü ClaimPick'te: pick başkasındaysa reddedilir.
        CurrentUserId := CopyStr(UserId(), 1, MaxStrLen(CurrentUserId));
        ClaimPick(Pick, CurrentUserId, SelfClaimReasonLbl);
    end;

    /// <summary>
    /// Bir toplamayı ÜSTLENME (self-claim). İş kuralı: toplama ya boşta olmalı ya
    /// da zaten aynı operatörde olmalı; başkasındaysa reddedilir. Yönetici zorla
    /// devretmek isterse ReassignPick kullanır (o yol bilerek açık bırakıldı).
    ///
    /// NEDEN kilitli yeniden okuma: sayfadan/API'den gelen Rec, karar anından
    /// önce okunmuş olabilir (stale). İki terminal aynı anda "Üzerime Al" derse
    /// ikisi de "boşta" görüp yazar ve son yazan kazanırdı. LockTable + Get ile
    /// karar GÜNCEL satır üzerinde ve kilit altında verilir; ikinci operatör
    /// hata alır. BC'nin kendi Modify çakışması bu senaryoyu yakalamaz, çünkü
    /// her iki yazma da teknik olarak geçerlidir.
    /// </summary>
    procedure ClaimPick(var Pick: Record "Warehouse Activity Header"; RequestedUserId: Code[50]; Reason: Text[250])
    var
        LockedPick: Record "Warehouse Activity Header";
        CurrentOwner: Code[50];
    begin
        EnsurePick(Pick);
        if RequestedUserId = '' then
            RequestedUserId := CopyStr(UserId(), 1, MaxStrLen(RequestedUserId));

        LockedPick.LockTable();
        if not LockedPick.Get(LockedPick.Type::Pick, Pick."No.") then
            Error(PickGoneErr, Pick."No.");

        CurrentOwner := LockedPick."Assigned User ID";
        if (CurrentOwner <> '') and (CurrentOwner <> RequestedUserId) then
            Error(PickTakenErr, Pick."No.", OperatorLabel(CurrentOwner));

        if CurrentOwner = RequestedUserId then begin
            // Zaten kendisinde: terminal aynı butona iki kez basabilir, hata verme.
            Pick := LockedPick;
            exit;
        end;

        // Bkz. ReassignPick: WMS operatörü Warehouse Employee olmayabilir; ilişki
        // doğrulamasını tetiklemeden doğrudan yaz ki atama kalıcı olsun.
        LockedPick."Assigned User ID" := RequestedUserId;
        LockedPick.Modify(true);
        Pick := LockedPick;

        // Üstlenmeyi yapan = üstlenen operatörün kendisi; geçmiş ve telemetri
        // paylaşımlı BC hesabını değil bu kimliği göstermeli.
        LogAssignment(Pick."No.", '', RequestedUserId, Reason, RequestedUserId);
        SyncPickingOrderAssignment(Pick."No.", RequestedUserId);
        // Webhook bilerek tetiklenmiyor: bildirim "işin elinden alındı" anlamı
        // taşıyor; boştaki bir işi üstlenmek kimseyi ilgilendirmiyor.
        Log('Pick.Claim', Pick."No.", RequestedUserId);
    end;

    /// <summary>
    /// Terminalden gelen İŞLEM çağrıları için sahiplik kontrolü (satır onayı,
    /// LP başlatma, tote bağlama, register). Toplama atanmamışsa ya da doğrulanabilir
    /// biçimde başka bir kullanıcıdaysa hata verir.
    /// </summary>
    procedure EnsurePickOperator(var Pick: Record "Warehouse Activity Header")
    var
        FreshPick: Record "Warehouse Activity Header";
    begin
        EnsurePick(Pick);
        // Güncel atama veritabanından okunur: terminaldeki kopya, sorumlu belgeyi
        // devrettikten sonra da eski sahibi gösteriyor olabilir.
        if not FreshPick.Get(FreshPick.Type::Pick, Pick."No.") then
            Error(PickGoneErr, Pick."No.");
        CheckOwnership(FreshPick."No.", FreshPick."Assigned User ID");
    end;

    /// <summary>Operatörü ekranda okunur biçimde yazar: "Ahmet Yılmaz (AHMET)".</summary>
    procedure OperatorLabel(UserIdValue: Code[50]): Text
    var
        LocalUser: Record "DOPSWHS Local User";
    begin
        if UserIdValue = '' then
            exit(UnassignedLbl);
        if StrLen(UserIdValue) <= MaxStrLen(LocalUser.Username) then
            if LocalUser.Get(CopyStr(UserIdValue, 1, MaxStrLen(LocalUser.Username))) then
                if LocalUser."Display Name" <> '' then
                    exit(StrSubstNo('%1 (%2)', LocalUser."Display Name", UserIdValue));
        exit(UserIdValue);
    end;

    /// <summary>
    /// ZORUNLU ATAMA + sahiplik kuralı. Çağıranın kimliği bilinmiyorsa (paylaşımlı
    /// BC hesabı) elde olan tek kimlik UserId()'dir.
    /// </summary>
    local procedure CheckOwnership(PickNo: Code[20]; Owner: Code[50])
    begin
        // Atanmamış toplama terminalden işlenemez: aksi halde iki operatör aynı
        // belgede paralel çalışıp aynı satırı iki kez toplayabiliyordu.
        if Owner = '' then
            Error(PickUnassignedErr, PickNo);
        if Owner = UserId() then
            exit;
        // Paylaşımlı BC hesabı gerçeği: terminal operatörleri "DOPSWHS Local User"
        // olarak oturum açar, BC'ye ise ortak bir AAD hesabıyla bağlanır. Atama bir
        // yerel kullanıcıdaysa sunucu, isteği gerçekten O operatörün gönderip
        // göndermediğini DOĞRULAYAMAZ; yanlış yere iş durdurmamak için geçilir.
        // Asıl koruma üstlenme anındadır (ClaimPick) — orada ikinci operatör
        // zaten reddedilir. Kimliği taşıyan istemciler ConfirmPickLineFor ile
        // tam (strict) kontrole girer.
        if IsLocalOperator(Owner) then
            exit;
        Error(PickOwnedByOtherErr, PickNo, OperatorLabel(Owner));
    end;

    /// <summary>Çağıranın kimliği BİLİNİYORSA uygulanan tam kontrol.</summary>
    local procedure CheckOwnershipFor(PickNo: Code[20]; Owner: Code[50]; RequestingUserId: Code[50])
    begin
        if Owner = '' then
            Error(PickUnassignedErr, PickNo);
        if Owner = RequestingUserId then
            exit;
        Error(PickOwnedByOtherErr, PickNo, OperatorLabel(Owner));
    end;

    /// <summary>Satırın bağlı olduğu toplama başlığı üzerinden sahiplik kontrolü.</summary>
    local procedure CheckLineOwnership(var PickLine: Record "Warehouse Activity Line"; RequestingUserId: Code[50])
    var
        PickHeader: Record "Warehouse Activity Header";
    begin
        if not PickHeader.Get(PickHeader.Type::Pick, PickLine."No.") then
            Error(PickGoneErr, PickLine."No.");
        if RequestingUserId = '' then
            CheckOwnership(PickHeader."No.", PickHeader."Assigned User ID")
        else
            CheckOwnershipFor(PickHeader."No.", PickHeader."Assigned User ID", RequestingUserId);
    end;

    local procedure IsLocalOperator(UserIdValue: Code[50]): Boolean
    var
        LocalUser: Record "DOPSWHS Local User";
    begin
        if UserIdValue = '' then
            exit(false);
        // Code[50] değer Username'e (Code[20]) sığmıyorsa yerel kullanıcı olamaz;
        // CopyStr ile kırpıp yanlış eşleşme üretmeyelim.
        if StrLen(UserIdValue) > MaxStrLen(LocalUser.Username) then
            exit(false);
        exit(LocalUser.Get(CopyStr(UserIdValue, 1, MaxStrLen(LocalUser.Username))));
    end;

    /// <summary>
    /// Atama geçmişi. PerformedByUserId = işlemi FİİLEN yapan kimlik; boş
    /// bırakılırsa oturumun BC hesabına düşülür.
    ///
    /// NEDEN ayrı parametre: terminalden gelen bütün çağrılar paylaşımlı servis
    /// hesabıyla geldiği için "Reassigned By" her satırda aynı hesabı (DYNOPS)
    /// yazıyordu; kimin üstlendiği geçmişten okunamıyordu.
    /// </summary>
    local procedure LogAssignment(PickNo: Code[20]; FromUserId: Code[50]; ToUserId: Code[50]; Reason: Text[250]; PerformedByUserId: Code[50])
    var
        History: Record "DOPSWHS Pick Reassign Hist";
    begin
        History.Init();
        History."Pick No." := PickNo;
        History."From User" := FromUserId;
        History."To User" := ToUserId;
        if PerformedByUserId <> '' then
            History."Reassigned By" := PerformedByUserId
        else
            History."Reassigned By" := CopyStr(UserId(), 1, MaxStrLen(History."Reassigned By"));
        History.DateTime := CurrentDateTime();
        History.Reason := Reason;
        History.Insert(true);
    end;

    /// <summary>
    /// Pick'teki atamayı, o pick'i doğuran "Toplanacak Siparişler" (Picking Order)
    /// kaydına da yazar. Terminalden "Üzerime Al" yapan operatör masadaki
    /// listede de görünsün diye — aksi halde bağ tek yönlü kalıyor ve sorumlu
    /// pick'i kimin aldığını Toplanacak Siparişler ekranından göremiyordu.
    /// </summary>
    local procedure SyncPickingOrderAssignment(PickNo: Code[20]; NewUserId: Code[50])
    var
        PickingHeader: Record "DOPSWHS Picking Order Header";
    begin
        if PickNo = '' then
            exit;
        PickingHeader.SetRange("Warehouse Pick No.", PickNo);
        if not PickingHeader.FindSet(true) then
            exit;
        repeat
            if PickingHeader."Assigned User ID" <> NewUserId then begin
                // Doğrudan yaz: alanın TableRelation'ı Warehouse Employee ve
                // WMS operatörü orada kayıtlı olmayabilir (Validate reddederdi).
                PickingHeader."Assigned User ID" := NewUserId;
                PickingHeader.Modify(true);
            end;
        until PickingHeader.Next() = 0;
    end;

    procedure StartShippingLP(var Pick: Record "Warehouse Activity Header"; TemplateCode: Code[20]): Code[20]
    var
        LP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
        EffectiveTemplateCode: Code[20];
    begin
        EnsurePick(Pick);
        EffectiveTemplateCode := TemplateCode;
        if EffectiveTemplateCode = '' then
            EffectiveTemplateCode := 'PALLET-EUR';

        LPMgt.Build(EffectiveTemplateCode, Pick."Location Code", '', LP);
        // Operatör: belgeyi üstlenmiş kullanıcı (uç nokta EnsurePickOperator ile
        // sahipliği zaten doğruluyor), servis hesabı değil.
        Log('Pick.StartShippingLP', Pick."No.", Pick."Assigned User ID");
        exit(LP."No.");
    end;

    procedure StopShippingLP(var Pick: Record "Warehouse Activity Header"; LpNo: Code[20]; PrintLabel: Boolean): Code[18]
    begin
        exit(StopShippingLP(Pick, LpNo, PrintLabel, ''));
    end;

    procedure StopShippingLP(var Pick: Record "Warehouse Activity Header"; LpNo: Code[20]; PrintLabel: Boolean; PrinterId: Code[50]): Code[18]
    var
        LP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        EnsurePick(Pick);
        LP.Get(LpNo);
        ValidateLPForPick(LP, Pick, false);
        LPMgt.Stop(LP, PrintLabel, PrinterId);
        Log('Pick.StopShippingLP', Pick."No.", Pick."Assigned User ID");
        exit(LP.SSCC);
    end;

    procedure RegisterShortPick(var PickLine: Record "Warehouse Activity Line"; ShortQty: Decimal; ReasonCode: Code[20])
    var
        Reason: Record "DOPSWHS Short Pick Reason";
    begin
        // Eksik toplama bildirimi de bir işlemdir: belge başkasındaysa/atanmamışsa reddet.
        CheckLineOwnership(PickLine, '');
        if ShortQty < 0 then
            Error('Short quantity cannot be negative.');
        if ReasonCode <> '' then
            Reason.Get(ReasonCode);

        PickLine.Validate("Qty. to Handle", ShortQty);
        PickLine.Modify(true);
        // Eksik bildiren operatör = belgeyi üstlenen kullanıcı; uç nokta ayrı
        // kimlik taşımıyor, o yüzden atamadan okunur.
        Log('Pick.Short.' + ReasonCode, PickLine."No.", PickOperator(PickLine."No."));
    end;

    /// <summary>
    /// Satır onayı — çağıranın kimliği bilinmiyor (pickLines PATCH yolu).
    /// Sahiplik, oturumun BC kullanıcısı üzerinden kontrol edilir.
    /// </summary>
    procedure ConfirmPickLine(var PickLine: Record "Warehouse Activity Line"; QtyToHandle: Decimal; LotNo: Code[50])
    begin
        ConfirmPickLineInternal(PickLine, QtyToHandle, LotNo, '');
    end;

    /// <summary>
    /// Satır onayı — çağıran operatör kimliğini AÇIKÇA bildirir (terminal WMS
    /// oturumu). Paylaşımlı BC hesabında sahipliği kesin doğrulayabilen tek yol
    /// budur: toplama başkasındaysa satır onaylanamaz.
    /// </summary>
    procedure ConfirmPickLineFor(var PickLine: Record "Warehouse Activity Line"; QtyToHandle: Decimal; LotNo: Code[50]; RequestingUserId: Code[50])
    begin
        if RequestingUserId = '' then
            Error(RequestingUserRequiredErr);
        ConfirmPickLineInternal(PickLine, QtyToHandle, LotNo, RequestingUserId);
    end;

    local procedure ConfirmPickLineInternal(var PickLine: Record "Warehouse Activity Line"; QtyToHandle: Decimal; LotNo: Code[50]; RequestingUserId: Code[50])
    var
        CompanionLine: Record "Warehouse Activity Line";
        WhseShipmentLine: Record "Warehouse Shipment Line";
    begin
        if PickLine."Activity Type" <> PickLine."Activity Type"::Pick then
            Error('Warehouse activity %1 must be a Pick.', PickLine."No.");

        // Belge hâlâ bu operatörde mi? Satır bazında her onayda doğrulanır;
        // sorumlu toplamayı toplama sırasında devretmiş olabilir.
        CheckLineOwnership(PickLine, RequestingUserId);

        // El terminalindeki toplama fiziksel bir raf/bin doğrulamasıdır. Kaynak
        // rafı boş bir satırın miktarını onaylamak, terminalde gerçekte hangi
        // raftan ürün alındığını kanıtsız bırakır ve yanlış stok hareketine yol
        // açar. Böyle bir pick genellikle eksik bin content/setup nedeniyle
        // oluşur; operatöre düşürmek yerine sunucuda kesin olarak reddedilir.
        EnsurePickLineHasBin(PickLine, QtyToHandle);

        PickLine.Validate("Qty. to Handle", QtyToHandle);
        EnsurePickLot(PickLine, LotNo);
        PickLine.Validate("Lot No.", LotNo);
        PickLine.Modify(true);

        // Directed pick'te aynı sevkiyat satırına bağlı Take ve Place satırları
        // aynı lotu taşımalıdır. Terminal tek satır gösterir; BC tarafında eş
        // satırları burada senkronlarız ki Register "Lot No. must have a value"
        // hatası vermesin.
        CompanionLine.SetRange("Activity Type", PickLine."Activity Type");
        CompanionLine.SetRange("No.", PickLine."No.");
        CompanionLine.SetRange("Whse. Document Type", PickLine."Whse. Document Type");
        CompanionLine.SetRange("Whse. Document No.", PickLine."Whse. Document No.");
        CompanionLine.SetRange("Whse. Document Line No.", PickLine."Whse. Document Line No.");
        CompanionLine.SetRange("Item No.", PickLine."Item No.");
        CompanionLine.SetRange("Variant Code", PickLine."Variant Code");
        CompanionLine.SetFilter("Line No.", '<>%1', PickLine."Line No.");
        if CompanionLine.FindSet(true) then
            repeat
                CompanionLine.Validate("Qty. to Handle", QtyToHandle);
                CompanionLine.Validate("Lot No.", LotNo);
                CompanionLine.Modify(true);
            until CompanionLine.Next() = 0;

        // Pick'te girilen lot bağlı Warehouse Shipment satırında da görünür.
        if (PickLine."Whse. Document Type" = PickLine."Whse. Document Type"::Shipment) and
           WhseShipmentLine.Get(PickLine."Whse. Document No.", PickLine."Whse. Document Line No.")
        then begin
            WhseShipmentLine."DOPSWHS Lot No." := LotNo;
            WhseShipmentLine.Modify(true);
        end;

        // Satır onayı sahadaki EN SIK işlem; "bu satırı kim okuttu" sorusu
        // ancak burada kayıt altına alınırsa cevaplanabiliyor.
        Log('Pick.ConfirmLine', PickLine."No.", EffectiveOperator(PickLine."No.", RequestingUserId));
    end;

    /// <summary>Lot takipli toplama satırlarında mobil lot seçimini zorunlu kılar.</summary>
    procedure PickLineRequiresLot(PickLine: Record "Warehouse Activity Line"): Boolean
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        if not Item.Get(PickLine."Item No.") then
            exit(false);
        if Item."Item Tracking Code" = '' then
            exit(false);
        if not ItemTrackingCode.Get(Item."Item Tracking Code") then
            exit(false);
        exit(
            ItemTrackingCode."Lot Specific Tracking" or
            ItemTrackingCode."Lot Warehouse Tracking" or
            ItemTrackingCode."Lot Sales Outbound Tracking");
    end;

    local procedure EnsurePickLot(PickLine: Record "Warehouse Activity Line"; LotNo: Code[50])
    begin
        if (PickLine."Qty. to Handle" <= 0) or (not PickLineRequiresLot(PickLine)) then
            exit;
        if LotNo = '' then
            Error(
                '%1 ürününün %2 toplama satırında lot numarası zorunludur. %3 rafındaki stok lotlarından birini seçin.',
                PickLine."Item No.", PickLine."Line No.", PickLine."Bin Code");
    end;

    procedure RegisterPick(var Pick: Record "Warehouse Activity Header")
    begin
        RegisterPickInternal(Pick, '');
    end;

    /// <summary>
    /// Terminal için strict register yolu. Paylaşımlı BC hesabı yerine WMS
    /// oturumundaki gerçek operatör kimliğini taşır; belge son anda başka birine
    /// devredildiyse kayıt işlemi kilit altında reddedilir.
    /// </summary>
    procedure RegisterPickFor(var Pick: Record "Warehouse Activity Header"; RequestingUserId: Code[50])
    begin
        if RequestingUserId = '' then
            Error(RequestingUserRequiredErr);
        RegisterPickInternal(Pick, RequestingUserId);
    end;

    local procedure RegisterPickInternal(var Pick: Record "Warehouse Activity Header"; RequestingUserId: Code[50])
    var
        PickLine: Record "Warehouse Activity Line";
        PickingHeader: Record "DOPSWHS Picking Order Header";
        LockedPick: Record "Warehouse Activity Header";
        PickNo: Code[20];
        // QM (BC 28) devre dışı — bkz. QualityMgmtBridge.Codeunit.al
        // QualityBridge: Codeunit "DOPSWHS Quality Mgmt Bridge";
        WhseActivityRegister: Codeunit "Whse.-Activity-Register";
    begin
        EnsurePick(Pick);
        // Eş zamanlılık: iki terminal aynı belgeyi aynı anda kaydetmeye çalışabilir.
        // Kilit alıp yeniden okuyoruz; belge artık yoksa (öteki kaydetmiş) anlaşılır
        // bir mesaj veririz — aksi halde BC'nin ham "record not found" hatası düşerdi.
        LockedPick.LockTable();
        if not LockedPick.Get(LockedPick.Type::Pick, Pick."No.") then
            Error(PickGoneErr, Pick."No.");
        Pick := LockedPick;
        // Kaydetme de bir işlemdir: atanmamış ya da başkasındaki belge kaydedilemez.
        if RequestingUserId = '' then
            CheckOwnership(Pick."No.", Pick."Assigned User ID")
        else
            CheckOwnershipFor(Pick."No.", Pick."Assigned User ID", RequestingUserId);
        PickNo := Pick."No.";
        // Kaydeden operatör: belge sahibi (CheckOwnership hemen üstte doğruladı).
        Log('Pick.Register', Pick."No.", EffectiveOperator(Pick."No.", RequestingUserId));
        EnsurePickHasBins(Pick);
        if Pick."DOPSWHS Pick Mode" = Pick."DOPSWHS Pick Mode"::Multi then
            EnsureAllMultiPickLinesScanned(Pick);

        // Microsoft Quality Management block guard — QM (BC 28) devre dışı.
        // BC 28'e geçince aşağıdaki bloğun yorumunu kaldırın. Register if any
        // pick line carries a Lot/Serial currently under an open inspection.
        // Error format matches BCWMSApp.QcErrorParser so the mobile/web UI
        // renders a friendly " QC BLOCK" banner.
        // PickLine.SetRange("Activity Type", Pick.Type);
        // PickLine.SetRange("No.", Pick."No.");
        // if PickLine.FindSet() then
        //     repeat
        //         QualityBridge.VerifyNotBlocked(
        //             PickLine."Lot No.",
        //             PickLine."Serial No.",
        //             '');
        //     until PickLine.Next() = 0;

        PickLine.SetRange("Activity Type", Pick.Type);
        PickLine.SetRange("No.", Pick."No.");
        if PickLine.FindFirst() then begin
            PreparePackingOrders(Pick);
            WhseActivityRegister.Run(PickLine);
            PickingHeader.SetRange("Warehouse Pick No.", PickNo);
            if PickingHeader.FindSet(true) then
                repeat
                    PickingHeader.Status := PickingHeader.Status::Completed;
                    PickingHeader."Completed DateTime" := CurrentDateTime();
                    PickingHeader.Modify(true);
                until PickingHeader.Next() = 0;
        end;
    end;

    local procedure EnsurePickLineHasBin(PickLine: Record "Warehouse Activity Line"; QtyToHandle: Decimal)
    begin
        if QtyToHandle <= 0 then
            exit;
        PickLine.TestField("Location Code");
        if PickLine."Bin Code" = '' then
            Error(PickLineBinRequiredErr, PickLine."No.", PickLine."Line No.", PickLine."Item No.");
    end;

    local procedure EnsurePickHasBins(var Pick: Record "Warehouse Activity Header")
    var
        PickLine: Record "Warehouse Activity Line";
    begin
        PickLine.SetRange("Activity Type", Pick.Type);
        PickLine.SetRange("No.", Pick."No.");
        PickLine.SetRange("Action Type", PickLine."Action Type"::Take);
        PickLine.SetFilter(Quantity, '>0');
        if PickLine.FindSet() then
            repeat
                EnsurePickLineHasBin(PickLine, PickLine.Quantity);
            until PickLine.Next() = 0;
    end;

    local procedure EnsureAllMultiPickLinesScanned(var Pick: Record "Warehouse Activity Header")
    var
        PickLine: Record "Warehouse Activity Line";
    begin
        PickLine.SetRange("Activity Type", Pick.Type);
        PickLine.SetRange("No.", Pick."No.");
        PickLine.SetRange("Action Type", PickLine."Action Type"::Take);
        if PickLine.FindSet() then
            repeat
                if PickLine."Qty. to Handle" < PickLine.Quantity then
                    Error('Complete all items before posting. Bin %1, item %2 still has %3 remaining.',
                        PickLine."Bin Code", PickLine."Item No.", PickLine.Quantity - PickLine."Qty. to Handle");
            until PickLine.Next() = 0;
    end;

    local procedure PreparePackingOrders(var Pick: Record "Warehouse Activity Header")
    var
        PickLine: Record "Warehouse Activity Line";
        Handled: Dictionary of [Code[20], Boolean];
    begin
        // ELOG: register'dan ÖNCE, pick'teki her satış siparişi için paketleme
        // kaydı (DOPSWHS Packing Order) hazırlanır. Eskiden Action Type=Take +
        // Source Type=Sales Line filtreleniyordu; ancak Whse.-Shipment-Create-Pick
        // ile üretilen satırlarda bu alanlar beklenenden farklı olabildiği için
        // paketleme kuyruğu BOŞ kalıyordu. Artık tüm pick satırlarını dolaşıp
        // Source No.'yu doğrudan satış siparişi olarak deniyoruz (tekilleştirilmiş).
        PickLine.SetRange("Activity Type", Pick.Type);
        PickLine.SetRange("No.", Pick."No.");
        if PickLine.FindSet() then
            repeat
                if (PickLine."Source No." <> '') and (not Handled.ContainsKey(PickLine."Source No.")) then begin
                    Handled.Add(PickLine."Source No.", true);
                    UpsertPackingOrder(Pick, PickLine);
                end;
            until PickLine.Next() = 0;
    end;

    // Bir satış siparişi için paketleme kaydını oluşturur/günceller (Ready).
    // Source No. bir satış siparişi değilse sessizce atlar.
    local procedure UpsertPackingOrder(var Pick: Record "Warehouse Activity Header"; var PickLine: Record "Warehouse Activity Line")
    var
        PackingOrder: Record "DOPSWHS Packing Order";
        PickingHeader: Record "DOPSWHS Picking Order Header";
        SalesHeader: Record "Sales Header";
        PackingOrderExists: Boolean;
    begin
        if not SalesHeader.Get(SalesHeader."Document Type"::Order, PickLine."Source No.") then
            exit;

        PackingOrderExists := PackingOrder.Get(PickLine."Source No.");
        if PackingOrderExists then begin
            if PackingOrder.Status = PackingOrder.Status::"In Progress" then
                Error('Sales order %1 is already being packed.', PickLine."Source No.");
            PackingOrder.Status := PackingOrder.Status::Ready;
            PackingOrder."Session Entry No." := 0;
        end else begin
            PackingOrder.Init();
            PackingOrder."Sales Order No." := PickLine."Source No.";
        end;
        PackingOrder."Pick No." := Pick."No.";
        // Toplamada kullanılan ana sepeti paketlemeye taşı: paketleyici
        // "ürünler hangi sepette" bilgisini terminalde görsün.
        PackingOrder."Main LP No." := Pick."DOPSWHS Main LP No.";
        // Toplama grubunun akış tipini paketlemeye taşı: terminaldeki V2
        // sekmeleri (Multi / Mono / Tek SKU) listeyi bu alanla filtreliyor.
        // Pick başlığı ana kaynaktır; özel grup kaydı bazı eski/standart
        // pick'lerde bulunmadığında modu boş bırakmak V2 kuyruğundan kaydı
        // tamamen gizliyordu. Grup kaydında dolu bir mod varsa onu tercih et.
        PackingOrder."Order Flow Mode" := Pick."DOPSWHS Pick Mode";
        PickingHeader.SetRange("Warehouse Pick No.", Pick."No.");
        if PickingHeader.FindFirst() then
            if PickingHeader."Order Flow Mode" <> PickingHeader."Order Flow Mode"::" " then
                PackingOrder."Order Flow Mode" := PickingHeader."Order Flow Mode";
        PackingOrder."Warehouse Shipment No." := PickLine."Whse. Document No.";
        PackingOrder."Location Code" := Pick."Location Code";
        PackingOrder."Customer No." := SalesHeader."Sell-to Customer No.";
        PackingOrder."Customer Name" := SalesHeader."Sell-to Customer Name";
        PackingOrder."Ready DateTime" := CurrentDateTime();
        if PackingOrderExists then
            PackingOrder.Modify(true)
        else
            PackingOrder.Insert(true);
    end;

    /// <summary>
    /// YÖNETİCİ yolu: belgeyi zorla devreder. Toplama başka bir operatörde olsa
    /// bile geçer — depo sorumlusu vardiya değişiminde/arızada işi devralabilmeli.
    /// Operatörün kendi kendine üstlenmesi bu yoldan DEĞİL, ClaimPick'ten geçer.
    /// </summary>
    procedure ReassignPick(var Pick: Record "Warehouse Activity Header"; NewUserId: Code[50]; Reason: Text[250])
    var
        LockedPick: Record "Warehouse Activity Header";
        WebhookMgmt: Codeunit "DOPSWHS Webhook Mgmt";
        FromUserId: Code[50];
    begin
        EnsurePick(Pick);
        if NewUserId = '' then
            Error(NewUserRequiredErr);

        // Kilitli yeniden okuma: "kimden kime" geçmişi ekrandaki eski değerle
        // değil, güncel sahiple yazılsın; iki sorumlu aynı anda devrederse
        // ikincisi birincisinin yazdığını görerek üzerine yazar.
        LockedPick.LockTable();
        if not LockedPick.Get(LockedPick.Type::Pick, Pick."No.") then
            Error(PickGoneErr, Pick."No.");

        FromUserId := LockedPick."Assigned User ID";
        // "Assigned User ID" TableRelation'ı Warehouse Employee'dir. WMS operatörü
        // (ör. DYNOPS) her zaman bir Warehouse Employee olmayabilir; Validate bu
        // durumda değeri reddedip alanı boş bırakabiliyordu. Atamanın her koşulda
        // kalıcı olması için ilişki doğrulamasını tetiklemeden doğrudan yazılır.
        LockedPick."Assigned User ID" := CopyStr(NewUserId, 1, MaxStrLen(LockedPick."Assigned User ID"));
        LockedPick.Modify(true);
        Pick := LockedPick;

        // Devri YAPAN kimlik bu yoldan gelmiyor (masa/Pick Board çağrısı): boş
        // geçilir ve oturumun BC kullanıcısına düşülür. Web istemcisinde bu
        // gerçek sorumludur; terminalden gelirse servis hesabı kalır.
        LogAssignment(Pick."No.", FromUserId, NewUserId, Reason, '');

        // Masadaki "Toplanacak Siparişler" listesi de aynı operatörü göstersin.
        SyncPickingOrderAssignment(Pick."No.", Pick."Assigned User ID");

        WebhookMgmt.OnPickReassigned(Pick."No.", FromUserId, NewUserId);
        // Mesaja kimden kime bilgisi konur: telemetride devir zinciri tek
        // satırdan okunabilsin (wmsUserId burada devri yapanı gösterir).
        Log('Pick.Reassign', StrSubstNo(ReassignLogTxt, Pick."No.", OperatorOrNone(FromUserId), NewUserId), '');
    end;

    /// <summary>
    /// YÖNETİCİ yolu: atamayı kaldırır, toplama terminalde yeniden üstlenilebilir
    /// hale gelir. ReassignPick boş kullanıcıyı kabul etmediği için ayrı yol.
    /// </summary>
    procedure ReleasePick(var Pick: Record "Warehouse Activity Header"; Reason: Text[250])
    var
        LockedPick: Record "Warehouse Activity Header";
        FromUserId: Code[50];
    begin
        EnsurePick(Pick);
        LockedPick.LockTable();
        if not LockedPick.Get(LockedPick.Type::Pick, Pick."No.") then
            Error(PickGoneErr, Pick."No.");
        if LockedPick."Assigned User ID" = '' then
            exit;

        FromUserId := LockedPick."Assigned User ID";
        LockedPick."Assigned User ID" := '';
        LockedPick.Modify(true);
        Pick := LockedPick;

        // Atamayı kaldıran kimlik de masa tarafından gelir (bkz. ReassignPick).
        LogAssignment(Pick."No.", FromUserId, '', Reason, '');
        SyncPickingOrderAssignment(Pick."No.", '');
        Log('Pick.Unassign', StrSubstNo(ReleaseLogTxt, Pick."No.", OperatorOrNone(FromUserId)), '');
    end;

    // ELOG saha ziyareti: toplama sırasında sipariş başına tote (sepet) bağlama.
    // Terminal ürün okutunca satırın kaynak siparişi için atanmış tote'u sorar;
    // yoksa okutulan yeni tote'u bu siparişe bağlar. Aynı tote aynı pick içinde
    // birden çok siparişe hizmet edebilir (bulk/batch); farklı bir pick'in
    // kapatılmamış tote'u yeniden bağlanamaz.
    procedure AssignTote(var Pick: Record "Warehouse Activity Header"; SourceOrderNo: Code[20]; LpNo: Code[20])
    var
        Assignment: Record "DOPSWHS Pick Tote Assignment";
        OtherAssignment: Record "DOPSWHS Pick Tote Assignment";
        LP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
        Operator: Code[50];
    begin
        // Tote bağlama toplamanın parçasıdır: belge bu operatörde olmalı.
        EnsurePickOperator(Pick);
        if SourceOrderNo = '' then
            Error(SourceOrderRequiredErr);
        LP.Get(LpNo);
        EnsureSourceOrderInPick(Pick, SourceOrderNo);
        ValidateLPForPick(LP, Pick, true);

        // Sepeti bağlayan operatör = belgeyi üstlenen kullanıcı. Eskiden bu alana
        // UserId() yazılıyordu; paylaşımlı hesap yüzünden her satır aynı kimliği
        // gösteriyor ve "sepeti kim bağladı" izlenemiyordu.
        Operator := EffectiveOperator(Pick."No.", '');
        if Operator = '' then
            Operator := CopyStr(UserId(), 1, MaxStrLen(Operator));

        OtherAssignment.SetRange("LP No.", LpNo);
        OtherAssignment.SetRange(Packed, false);
        OtherAssignment.SetFilter("Pick No.", '<>%1', Pick."No.");
        if not OtherAssignment.IsEmpty() then
            Error(ToteBusyErr, LpNo);

        if Assignment.Get(Pick."No.", SourceOrderNo) then begin
            Assignment."LP No." := LpNo;
            Assignment.Packed := false;
            Assignment."Assigned By User" := CopyStr(Operator, 1, MaxStrLen(Assignment."Assigned By User"));
            Assignment."Assigned DateTime" := CurrentDateTime();
            Assignment.Modify(true);
        end else begin
            Assignment.Init();
            Assignment."Pick No." := Pick."No.";
            Assignment."Source Order No." := SourceOrderNo;
            Assignment."LP No." := LpNo;
            Assignment."Location Code" := Pick."Location Code";
            Assignment."Assigned By User" := CopyStr(Operator, 1, MaxStrLen(Assignment."Assigned By User"));
            Assignment."Assigned DateTime" := CurrentDateTime();
            Assignment.Insert(true);
        end;

        // LP yaşam döngüsü: Built tote pick'e Assigned olur (Release paketlemede).
        if LP.Status = LP.Status::Built then
            LPMgt.Assign(LP, Enum::"DOPSWHS Assigned Doc Type"::WhsePick, Pick."No.");

        Log('Pick.AssignTote', Pick."No.", Operator);
    end;

    local procedure EnsureSourceOrderInPick(Pick: Record "Warehouse Activity Header"; SourceOrderNo: Code[20])
    var
        PickLine: Record "Warehouse Activity Line";
    begin
        PickLine.SetRange("Activity Type", Pick.Type);
        PickLine.SetRange("No.", Pick."No.");
        PickLine.SetRange("Source Type", Database::"Sales Line");
        PickLine.SetRange("Source No.", SourceOrderNo);
        if PickLine.IsEmpty() then
            Error('Sales order %1 is not a source order of pick %2.', SourceOrderNo, Pick."No.");
    end;

    local procedure ValidateLPForPick(LP: Record "DOPSWHS LP Header"; Pick: Record "Warehouse Activity Header"; AllowAssignedToThisPick: Boolean)
    begin
        LP.TestField("Location Code");
        Pick.TestField("Location Code");
        if LP."Location Code" <> Pick."Location Code" then
            Error(
                'LP %1 belongs to location %2, but pick %3 belongs to location %4.',
                LP."No.", LP."Location Code", Pick."No.", Pick."Location Code");
        if LP.Status in [LP.Status::Used, LP.Status::Unbuilt] then
            Error('LP %1 cannot be used for picking because its status is %2.', LP."No.", LP.Status);
        if LP.Status = LP.Status::Assigned then begin
            if not AllowAssignedToThisPick then
                Error('LP %1 is already assigned to %2 %3.', LP."No.", LP."Assigned Document Type", LP."Assigned Document No.");
            if (LP."Assigned Document Type" <> LP."Assigned Document Type"::WhsePick) or
               (LP."Assigned Document No." <> Pick."No.")
            then
                Error('LP %1 is already assigned to %2 %3.', LP."No.", LP."Assigned Document Type", LP."Assigned Document No.");
        end;
    end;

    procedure GetToteForOrder(PickNo: Code[20]; SourceOrderNo: Code[20]): Code[20]
    var
        Assignment: Record "DOPSWHS Pick Tote Assignment";
    begin
        if Assignment.Get(PickNo, SourceOrderNo) then
            exit(Assignment."LP No.");
        exit('');
    end;

    /// <summary>
    /// Toplama grubunun (Picking Order) toplayıcısını değiştirir — MASA/YÖNETİCİ
    /// yolu. NewUserId boş verilirse atama kaldırılır.
    ///
    /// NEDEN buraya taşındı: aynı kodu List ve Card sayfaları ayrı ayrı yazıyor,
    /// ikisi de ekrandaki (stale) kayıt üzerinden Modify ediyordu. İki sorumlu
    /// aynı grubu aynı anda atarsa biri diğerinin yazdığını sessizce eziyordu.
    /// Burada kayıt kilit altında yeniden okunur, durum doğrulanır, sonra yazılır.
    /// </summary>
    procedure SetPickingOrderPicker(var PickingHeader: Record "DOPSWHS Picking Order Header"; NewUserId: Code[50]; Reason: Text[250])
    var
        LockedHeader: Record "DOPSWHS Picking Order Header";
        PickHeader: Record "Warehouse Activity Header";
    begin
        LockedHeader.LockTable();
        if not LockedHeader.Get(PickingHeader."Entry No.") then
            Error(PickingOrderGoneErr, PickingHeader."Entry No.");
        if LockedHeader.Status = LockedHeader.Status::Completed then
            Error(PickingOrderCompletedErr, LockedHeader."Entry No.");

        // Atama aksiyonu yerel WMS kullanıcı listesini kullanır; kilitli
        // kayıt üzerindeki değeri tek adımda kalıcı hale getiririz.
        LockedHeader."Assigned User ID" := CopyStr(NewUserId, 1, MaxStrLen(LockedHeader."Assigned User ID"));
        LockedHeader.Modify(true);
        PickingHeader := LockedHeader;

        if LockedHeader."Warehouse Pick No." = '' then
            exit;
        // Pick kaydedilmiş/silinmişse grup ataması yine de güncel kalsın: hata verme.
        if not PickHeader.Get(PickHeader.Type::Pick, LockedHeader."Warehouse Pick No.") then
            exit;

        if NewUserId <> '' then begin
            ReassignPick(PickHeader, NewUserId, Reason);
            exit;
        end;

        // Atamayı kaldırma: ReassignPick boş kullanıcıyı kabul etmez, ayrı yol.
        ReleasePick(PickHeader, Reason);
    end;

    local procedure EnsurePick(var Pick: Record "Warehouse Activity Header")
    begin
        if Pick.Type <> Pick.Type::Pick then
            Error('Warehouse activity %1 must be a Pick.', Pick."No.");
    end;

    /// <summary>
    /// İşlemi yapan operatörü belirler: çağıran kimliğini AÇIKÇA bildirdiyse o
    /// kullanılır, aksi halde belgeyi üstlenmiş kullanıcıya bakılır.
    /// NEDEN: paylaşımlı BC hesabı yüzünden UserId() operatörü göstermiyor;
    /// atama alanı elimizdeki tek güvenilir "kim çalışıyor" kaynağı.
    /// </summary>
    local procedure EffectiveOperator(PickNo: Code[20]; RequestingUserId: Code[50]): Code[50]
    begin
        if RequestingUserId <> '' then
            exit(RequestingUserId);
        exit(PickOperator(PickNo));
    end;

    /// <summary>Belgeyi üstlenmiş operatör — veritabanından GÜNCEL okunur.</summary>
    local procedure PickOperator(PickNo: Code[20]): Code[50]
    var
        PickHeader: Record "Warehouse Activity Header";
    begin
        if PickNo = '' then
            exit('');
        if not PickHeader.Get(PickHeader.Type::Pick, PickNo) then
            exit('');
        exit(PickHeader."Assigned User ID");
    end;

    /// <summary>Log mesajında boş kimliği okunur hale getirir.</summary>
    local procedure OperatorOrNone(UserIdValue: Code[50]): Text
    begin
        if UserIdValue = '' then
            exit(NoOperatorTxt);
        exit(UserIdValue);
    end;

    /// <summary>
    /// İşlemi YAPAN operatörle birlikte loglar. Operatör parametresi BİLEREK
    /// zorunlu: her çağrı yeri "kim yaptı" sorusuna cevap vermek zorunda kalsın,
    /// sessizce servis hesabına düşmesin. Bilinmiyorsa açıkça '' geçilir
    /// (telemetri bunu 'actorSource=BC' ile işaretler).
    /// </summary>
    local procedure Log(Category: Text; Message: Text; OperatorUserId: Code[50])
    var
        Telemetry: Codeunit "DOPSWHS Telemetry";
    begin
        Telemetry.LogInfo(Category, Message, OperatorUserId);
    end;

    var
        SourceOrderRequiredErr: Label 'Source order no. is required to assign a tote.';
        ToteBusyErr: Label 'Tote %1 is still in use by another pick. Complete or release it first.', Comment = '%1 = LP No.';
        PickTakenErr: Label 'Toplama %1 şu anda %2 kullanıcısında. Üzerinize alamazsınız; devir için depo sorumlusundan yeniden atama isteyin.', Comment = '%1 = Pick No., %2 = operatör';
        PickOwnedByOtherErr: Label 'Toplama %1 %2 kullanıcısında. Bu belgede işlem yapamazsınız.', Comment = '%1 = Pick No., %2 = operatör';
        PickUnassignedErr: Label 'Toplama %1 kimseye atanmadı. İşleme başlamadan önce "Üzerime Al" ile toplamayı üstlenin.', Comment = '%1 = Pick No.';
        PickGoneErr: Label 'Toplama %1 artık açık değil — kaydedilmiş ya da silinmiş olabilir. Listeyi yenileyin.', Comment = '%1 = Pick No.';
        PickingOrderGoneErr: Label 'Toplama grubu %1 bulunamadı — silinmiş olabilir. Listeyi yenileyin.', Comment = '%1 = Entry No.';
        PickingOrderCompletedErr: Label 'Toplama grubu %1 tamamlandı; ataması değiştirilemez.', Comment = '%1 = Entry No.';
        NewUserRequiredErr: Label 'Atanacak kullanıcı seçilmedi.';
        RequestingUserRequiredErr: Label 'İşlemi yapan operatör kimliği gönderilmedi.';
        PickLineBinRequiredErr: Label '%1 toplamasının %2 satırında (%3 ürünü) kaynak raf/bin boş. Bin içeriğini düzeltip pick''i yeniden oluşturun; rafı belli olmayan satır terminalden onaylanamaz.', Comment = '%1 = Pick No., %2 = Line No., %3 = Item No.';
        SelfClaimReasonLbl: Label 'Terminalden üzerine alındı.';
        UnassignedLbl: Label 'atanmamış';
        // Telemetri mesajları çevrilmez (Locked): log sorguları dile göre değişmemeli.
        ReassignLogTxt: Label '%1: %2 -> %3', Locked = true;
        ReleaseLogTxt: Label '%1: %2 -> (none)', Locked = true;
        NoOperatorTxt: Label '(none)', Locked = true;
}
