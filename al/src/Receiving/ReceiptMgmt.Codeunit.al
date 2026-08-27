codeunit 72043 "DOPSWHS Receipt Mgmt"
{
    Access = Public;
    Permissions =
        tabledata "Reservation Entry" = rimd,
        tabledata "Whse. Item Tracking Line" = rimd,
        tabledata "Lot No. Information" = rimd;

    /// <summary>Geriye dönük imza: operatör kimliği belgenin atamasından okunur.</summary>
    procedure PostReceipt(var WhseReceiptHeader: Record "Warehouse Receipt Header"; PrintReport: Boolean; Invoice: Boolean)
    begin
        PostReceipt(WhseReceiptHeader, PrintReport, Invoice, '');
    end;

    /// <summary>
    /// Mal kabul kaydı. OperatorUserId = işlemi yapan WMS operatörü; terminal
    /// kimliği taşıyorsa buradan geçirir, taşımıyorsa belgeye atanmış kullanıcıya
    /// düşülür. NEDEN: BC'ye tüm çağrılar paylaşımlı servis hesabıyla geldiği
    /// için UserId() "kim postaladı" sorusunu cevaplamıyor.
    /// </summary>
    procedure PostReceipt(var WhseReceiptHeader: Record "Warehouse Receipt Header"; PrintReport: Boolean; Invoice: Boolean; OperatorUserId: Code[50])
    begin
        PostReceipt(WhseReceiptHeader, PrintReport, Invoice, OperatorUserId, '');
    end;

    procedure PostReceipt(var WhseReceiptHeader: Record "Warehouse Receipt Header"; PrintReport: Boolean; Invoice: Boolean; OperatorUserId: Code[50]; PrinterId: Code[50])
    var
        WhseReceiptLine: Record "Warehouse Receipt Line";
        PostedWhseReceiptHeader: Record "Posted Whse. Receipt Header";
        PostedWhseReceiptLine: Record "Posted Whse. Receipt Line";
        WhsePostReceipt: Codeunit "Whse.-Post Receipt";
        LpPropagation: Codeunit "DOPSWHS LP Propagation";
        PrintDispatcher: Codeunit "DOPSWHS Print Dispatcher";
        Telemetry: Codeunit "DOPSWHS Telemetry";
        LpNo: Code[20];
        ReceiptNo: Code[20];
        PostedNo: Code[20];
    begin
        if PrintReport then begin
            EnsureReceiptReportConfigured();
            PrintDispatcher.EnsureDocumentPrinter(PrinterId, Enum::"DOPSWHS IWX Report Usage"::Receipt);
        end;
        // Posting deletes the working receipt. Preserve the keys which are
        // needed to stamp the posted document and finish the LP afterwards.
        ReceiptNo := WhseReceiptHeader."No.";
        LpNo := WhseReceiptHeader."DOPSWHS LP No.";
        Log('Receipt.Post', ReceiptNo, EffectiveOperator(OperatorUserId, WhseReceiptHeader."Assigned User ID"));
        WhseReceiptLine.SetRange("No.", ReceiptNo);
        if WhseReceiptLine.FindFirst() then
            WhsePostReceipt.Run(WhseReceiptLine);

        PostedWhseReceiptHeader.SetRange("Whse. Receipt No.", ReceiptNo);
        if PostedWhseReceiptHeader.FindLast() then
            PostedNo := PostedWhseReceiptHeader."No.";

        // The normal propagation helper reads the working header, but that
        // row no longer exists after Whse.-Post Receipt. Stamp from the value
        // captured above so the posted lines and the LP never lose the link.
        if (PostedNo <> '') and (LpNo <> '') then begin
            if PostedWhseReceiptHeader.Get(PostedNo) then
                if PostedWhseReceiptHeader."DOPSWHS LP No." = '' then begin
                    PostedWhseReceiptHeader."DOPSWHS LP No." := LpNo;
                    PostedWhseReceiptHeader.Modify(true);
                end;
            PostedWhseReceiptLine.SetRange("No.", PostedNo);
            PostedWhseReceiptLine.SetRange("LP No.", '');
            if PostedWhseReceiptLine.FindSet(true) then
                repeat
                    PostedWhseReceiptLine."LP No." := LpNo;
                    PostedWhseReceiptLine.Modify(true);
                until PostedWhseReceiptLine.Next() = 0;
        end;
        LpPropagation.StampPostedReceiptHeader(ReceiptNo, PostedNo);
        LpPropagation.StampPostedReceiptLines(ReceiptNo, PostedNo);

        if PrintReport then begin
            ClearLastError();
            if not QueuePostedReceiptPrint(PostedNo, PrinterId) then
                Telemetry.LogWarning(
                    'Print.ReceiptFailed',
                    CopyStr(StrSubstNo('Receipt %1 posted, but its print job could not be queued: %2', PostedNo, GetLastErrorText()), 1, 250),
                    EffectiveOperator(OperatorUserId, WhseReceiptHeader."Assigned User ID"));
        end;

        if LpNo <> '' then
            AssignLP(LpNo, ReceiptNo);
    end;

    local procedure EnsureRequiredSupplierLots(WhseReceiptHeader: Record "Warehouse Receipt Header")
    var
        WhseReceiptLine: Record "Warehouse Receipt Line";
        LotNo: Code[50];
        SerialNo: Code[50];
        ExpiryDate: Date;
        SupplierLotNo: Code[50];
    begin
        WhseReceiptLine.SetRange("No.", WhseReceiptHeader."No.");
        WhseReceiptLine.SetFilter("Qty. to Receive", '>0');
        if WhseReceiptLine.FindSet() then
            repeat
                if ReceiptLineRequiresSupplierLot(WhseReceiptLine) then begin
                    GetItemTracking(WhseReceiptLine, LotNo, SerialNo, ExpiryDate);
                    GetSupplierLot(WhseReceiptLine, LotNo, SupplierLotNo);
                    if SupplierLotNo = '' then
                        Error(
                            'Mal kabul kaydedilemez. %1 ürününün %2 satırında tedarikçi lotu eksik.',
                            WhseReceiptLine."Item No.", WhseReceiptLine."Line No.");
                end;
            until WhseReceiptLine.Next() = 0;
    end;

    [TryFunction]
    local procedure QueuePostedReceiptPrint(PostedReceiptNo: Code[20]; PrinterId: Code[50])
    var
        PostedReceipt: Record "Posted Whse. Receipt Header";
        ReportSelection: Record "DOPSWHS IWX Report Selection";
        PrintDispatcher: Codeunit "DOPSWHS Print Dispatcher";
        SourceRecord: RecordRef;
    begin
        if PostedReceiptNo = '' then
            Error('The posted warehouse receipt could not be found for printing.');
        ReportSelection.SetCurrentKey(Usage, Sequence);
        ReportSelection.SetRange(Usage, ReportSelection.Usage::Receipt);
        ReportSelection.SetFilter("Report ID", '<>0');
        if not ReportSelection.FindFirst() then
            Error('No report is configured for Receipt printing.');
        PostedReceipt.Get(PostedReceiptNo);
        PostedReceipt.SetRecFilter();
        SourceRecord.GetTable(PostedReceipt);
        PrintDispatcher.PrintReport(PostedReceiptNo, ReportSelection."Report ID", PrinterId, 1, ReportSelection.Usage, SourceRecord);
    end;

    local procedure EnsureReceiptReportConfigured()
    var
        ReportSelection: Record "DOPSWHS IWX Report Selection";
    begin
        ReportSelection.SetCurrentKey(Usage, Sequence);
        ReportSelection.SetRange(Usage, ReportSelection.Usage::Receipt);
        ReportSelection.SetFilter("Report ID", '<>0');
        if not ReportSelection.FindFirst() then
            Error('No report is configured for Receipt printing.');
    end;

    /// <summary>Geriye dönük imza: atamayı yapan kimlik bilinmiyor.</summary>
    procedure AssignUser(var WhseReceiptHeader: Record "Warehouse Receipt Header"; AssignedUserId: Code[50])
    begin
        AssignUser(WhseReceiptHeader, AssignedUserId, '');
    end;

    /// <summary>
    /// Belgeyi bir operatöre atar. PerformedByUserId = atamayı YAPAN kimlik
    /// (masadan başkası atayabilir); boşsa oturumun BC hesabına düşülür.
    /// Atanan kullanıcı log mesajına yazılır ki devir zinciri okunabilsin.
    /// </summary>
    procedure AssignUser(var WhseReceiptHeader: Record "Warehouse Receipt Header"; AssignedUserId: Code[50]; PerformedByUserId: Code[50])
    begin
        Log('Receipt.AssignUser', StrSubstNo(AssignLogTxt, WhseReceiptHeader."No.", OperatorOrNone(AssignedUserId)), PerformedByUserId);
        WhseReceiptHeader.Validate("Assigned User ID", AssignedUserId);
        WhseReceiptHeader.Modify(true);
    end;

    procedure StartLP(var WhseReceiptHeader: Record "Warehouse Receipt Header"; TemplateCode: Code[20]): Code[20]
    var
        LP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
        EffectiveTemplateCode: Code[20];
        ReceiptBinCode: Code[20];
    begin
        // LP açan operatör: belgeye atanmış kullanıcı (uç nokta ayrı kimlik taşımıyor).
        Log('Receipt.StartLP', WhseReceiptHeader."No.", WhseReceiptHeader."Assigned User ID");
        EffectiveTemplateCode := TemplateCode;
        if EffectiveTemplateCode = '' then
            EffectiveTemplateCode := 'PALLET-EUR';

        ReceiptBinCode := GetSingleReceiptBin(WhseReceiptHeader."No.");
        LPMgt.Build(EffectiveTemplateCode, WhseReceiptHeader."Location Code", ReceiptBinCode, LP);
        exit(LP."No.");
    end;

    procedure StopLP(var WhseReceiptHeader: Record "Warehouse Receipt Header"; LpNo: Code[20]; PrintLabel: Boolean)
    begin
        StopLP(WhseReceiptHeader, LpNo, PrintLabel, '');
    end;

    procedure StopLP(var WhseReceiptHeader: Record "Warehouse Receipt Header"; LpNo: Code[20]; PrintLabel: Boolean; PrinterId: Code[50])
    var
        LP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
        Telemetry: Codeunit "DOPSWHS Telemetry";
    begin
        Log('Receipt.StopLP', WhseReceiptHeader."No.", WhseReceiptHeader."Assigned User ID");
        LP.Get(LpNo);
        // Closing the LP is the warehouse transaction; the combined MTE/LP label
        // is best-effort output and must not reopen the LP when a printer is
        // unavailable. No mobile/API contract changes are required.
        LPMgt.Stop(LP, false, PrinterId);
        if PrintLabel then begin
            ClearLastError();
            if not TryPrintCombinedMteLabel(LP, PrinterId) then
                Telemetry.LogWarning(
                    'Print.ReceiptLpLabelsFailed',
                    CopyStr(
                        StrSubstNo(
                            'Receipt LP %1 completed, but its combined MTE/LP label could not be printed: %2',
                            LP."No.", GetLastErrorText()),
                        1, 250),
                    WhseReceiptHeader."Assigned User ID");
        end;
    end;

    /// <summary>Geriye dönük imza: operatör kimliği belgenin atamasından okunur.</summary>
    procedure ConfirmLine(var WhseReceiptLine: Record "Warehouse Receipt Line"; QtyToReceive: Decimal; LotNo: Code[50]; SerialNo: Code[50]; ExpiryDate: Date; LicensePlateNo: Code[20]; BinCode: Code[20])
    begin
        ConfirmLine(WhseReceiptLine, QtyToReceive, LotNo, SerialNo, ExpiryDate, LicensePlateNo, BinCode, '', '');
    end;

    /// <summary>
    /// Satır onayı (okutma). OperatorUserId = okutmayı yapan WMS operatörü;
    /// boşsa belgeye atanmış kullanıcıya düşülür.
    /// </summary>
    procedure ConfirmLine(var WhseReceiptLine: Record "Warehouse Receipt Line"; QtyToReceive: Decimal; LotNo: Code[50]; SerialNo: Code[50]; ExpiryDate: Date; LicensePlateNo: Code[20]; BinCode: Code[20]; OperatorUserId: Code[50])
    begin
        ConfirmLine(WhseReceiptLine, QtyToReceive, LotNo, SerialNo, ExpiryDate, LicensePlateNo, BinCode, '', OperatorUserId);
    end;

    /// <summary>
    /// Mal kabul satırını iç lot/seri ve isteğe bağlı tedarikçi lotuyla birlikte onaylar.
    /// Girilmişse tedarikçi lotu Lot No. Information kartına yazılır.
    /// </summary>
    procedure ConfirmLine(var WhseReceiptLine: Record "Warehouse Receipt Line"; QtyToReceive: Decimal; LotNo: Code[50]; SerialNo: Code[50]; ExpiryDate: Date; LicensePlateNo: Code[20]; BinCode: Code[20]; SupplierLotNo: Code[50]; OperatorUserId: Code[50])
    var
        LP: Record "DOPSWHS LP Header";
        WhseReceiptHeader: Record "Warehouse Receipt Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
        LotSerialGen: Codeunit "DOPSWHS Lot Serial Generator";
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
        ExistingLotNo: Code[50];
        ExistingSerialNo: Code[50];
        ExistingExpiryDate: Date;
    begin
        Log('Receipt.ConfirmLine', WhseReceiptLine."No.", EffectiveOperator(OperatorUserId, ReceiptOperator(WhseReceiptLine."No.")));
        Item.Get(WhseReceiptLine."Item No.");
        // Mevcut BC takip bilgisi korunur. İç lot yalnız terminaldeki açık
        // "Lot No Ata" komutuyla üretilir; ConfirmLine boş lotu tamamlamaz.
        // Seri numarası için mevcut geriye uyumlu otomatik üretim korunur.
        if Item."Item Tracking Code" <> '' then begin
            GetItemTracking(WhseReceiptLine, ExistingLotNo, ExistingSerialNo, ExistingExpiryDate);
            if LotNo = '' then
                LotNo := ExistingLotNo;
            if SerialNo = '' then
                SerialNo := ExistingSerialNo;
            if ExpiryDate = 0D then
                ExpiryDate := ExistingExpiryDate;

            if not ItemTrackingCode.Get(Item."Item Tracking Code") then
                Error('%1 takip kodu bulunamadı.', Item."Item Tracking Code");
            if RequiresLotTracking(ItemTrackingCode) then begin
                if LotNo = '' then
                    Error(
                        'İç lot numarası zorunludur. %1 ürünü için el terminalinde Lot No Ata düğmesine basın.',
                        WhseReceiptLine."Item No.");
            end else
                LotNo := '';
            if ItemTrackingCode."Man. Expir. Date Entry Reqd." and (ExpiryDate = 0D) then
                Error(
                    'Son kullanma tarihi zorunludur. %1 ürünü için el terminalinden son kullanma tarihini girin.',
                    WhseReceiptLine."Item No.");
            if RequiresSerialTracking(ItemTrackingCode) then begin
                if SerialNo = '' then
                    SerialNo := LotSerialGen.GenerateSerialNo();
            end else
                SerialNo := '';

        end else begin
            LotNo := '';
            SerialNo := '';
        end;
        if BinCode <> '' then
            WhseReceiptLine.Validate("Bin Code", BinCode);
        WhseReceiptLine.Validate("Qty. to Receive", QtyToReceive);
        WhseReceiptLine.Modify(true);
        // Mobilden girilen lot/seri, BC'nin Item Tracking
        // Lines mekanizmasının okuduğu Reservation Entry kayıtlarına yazılmazsa post
        // sırasında sessizce kaybolur — bu yüzden burada gerçek kalıcılığı sağlıyoruz.
        if Item."Item Tracking Code" <> '' then
            PersistItemTracking(WhseReceiptLine, LotNo, SerialNo, ExpiryDate);
        if SupplierLotNo <> '' then
            PersistSupplierLot(
                WhseReceiptLine."Item No.", WhseReceiptLine."Variant Code", LotNo, SupplierLotNo);

        if LicensePlateNo <> '' then begin
            LP.Get(LicensePlateNo);
            BindLpToReceiptBin(LP, WhseReceiptLine);
            LPMgt.AddLine(LP, WhseReceiptLine."Item No.", WhseReceiptLine."Unit of Measure Code", QtyToReceive, LotNo, SerialNo, ExpiryDate);
            StampReceiptSourceOnLastLpLine(LicensePlateNo, WhseReceiptLine);

            // Stamp the Whse Receipt Header with this LP so downstream posting can carry it
            // onto Posted Whse Receipt + Item Ledger Entry. Idempotent — only first LP wins.
            if WhseReceiptHeader.Get(WhseReceiptLine."No.") then
                if WhseReceiptHeader."DOPSWHS LP No." = '' then begin
                    WhseReceiptHeader."DOPSWHS LP No." := LicensePlateNo;
                    WhseReceiptHeader.Modify(true);
                end;
        end;
    end;

    local procedure StampReceiptSourceOnLastLpLine(LpNo: Code[20]; WhseReceiptLine: Record "Warehouse Receipt Line")
    var
        LPLine: Record "DOPSWHS LP Line";
    begin
        LPLine.SetRange("LP No.", LpNo);
        if not LPLine.FindLast() then
            Error('%1 LP satırı oluşturulamadı.', LpNo);
        LPLine."Source Document Type" := LPLine."Source Document Type"::WhseReceipt;
        LPLine."Source Document No." := WhseReceiptLine."No.";
        LPLine."Source Document Line No." := WhseReceiptLine."Line No.";
        LPLine."Source Bin Code" := WhseReceiptLine."Bin Code";
        // Quantity is the original receipt-line total (for example 500), while
        // LP Line.Quantity remains this pallet's amount (for example 250).
        LPLine."Source Document Quantity" := WhseReceiptLine.Quantity;
        LPLine.Modify(true);
    end;

    local procedure GetSingleReceiptBin(ReceiptNo: Code[20]): Code[20]
    var
        WhseReceiptLine: Record "Warehouse Receipt Line";
        CandidateBin: Code[20];
    begin
        WhseReceiptLine.SetRange("No.", ReceiptNo);
        WhseReceiptLine.SetFilter("Bin Code", '<>%1', '');
        if WhseReceiptLine.FindSet() then
            repeat
                if CandidateBin = '' then
                    CandidateBin := WhseReceiptLine."Bin Code"
                else
                    if CandidateBin <> WhseReceiptLine."Bin Code" then
                        exit('');
            until WhseReceiptLine.Next() = 0;
        exit(CandidateBin);
    end;

    local procedure BindLpToReceiptBin(var LP: Record "DOPSWHS LP Header"; WhseReceiptLine: Record "Warehouse Receipt Line")
    var
        Location: Record Location;
    begin
        if LP."Location Code" <> WhseReceiptLine."Location Code" then
            Error(
                '%1 LP''si %2 lokasyonundadır; %3 lokasyonundaki mal kabul satırına eklenemez.',
                LP."No.", LP."Location Code", WhseReceiptLine."Location Code");

        if WhseReceiptLine."Bin Code" = '' then begin
            if Location.Get(WhseReceiptLine."Location Code") and Location."Bin Mandatory" then
                Error(
                    '%1 LP''sini mal kabulde kullanmak için önce depo gözünü okutun veya satırdaki Depo Gözü alanını doldurun.',
                    LP."No.");
            exit;
        end;

        if LP."Bin Code" = '' then begin
            LP.Validate("Bin Code", WhseReceiptLine."Bin Code");
            LP.Modify(true);
            exit;
        end;

        if LP."Bin Code" <> WhseReceiptLine."Bin Code" then
            Error(
                '%1 LP''si %2 gözündedir; %3 gözündeki mal kabul satırı aynı LP''ye eklenemez.',
                LP."No.", LP."Bin Code", WhseReceiptLine."Bin Code");
    end;

    [TryFunction]
    local procedure TryPrintCombinedMteLabel(var LP: Record "DOPSWHS LP Header"; PrinterId: Code[50])
    var
        Dispatcher: Codeunit "DOPSWHS Print Dispatcher";
    begin
        Dispatcher.PrintPalletItemLabels(LP, PrinterId, 1);
    end;

    /// <summary>
    /// Operatörün açık "Lot No Ata" komutuyla Item kartındaki Lot Nos.
    /// serisinden yeni bir iç lot üretir. Satırı okumak veya miktarı açmak bu
    /// metodu çağırmaz. Var olan BC item-tracking lotu varsa aynen döndürülür.
    /// Takip kaydı miktar/SKT/tedarikçi lotu birlikte onaylanana kadar yazılmaz.
    /// </summary>
    procedure AssignInboundLotNo(WhseReceiptLine: Record "Warehouse Receipt Line"): Text
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
        LotSerialGen: Codeunit "DOPSWHS Lot Serial Generator";
        LotNo: Code[50];
        SerialNo: Code[50];
        ExpiryDate: Date;
    begin
        GetItemTracking(WhseReceiptLine, LotNo, SerialNo, ExpiryDate);
        if LotNo <> '' then
            exit(LotNo);

        Item.Get(WhseReceiptLine."Item No.");
        if (Item."Item Tracking Code" = '') or
           (not ItemTrackingCode.Get(Item."Item Tracking Code")) or
           (not RequiresLotTracking(ItemTrackingCode))
        then
            Error('%1 ürünü lot takipli değildir.', WhseReceiptLine."Item No.");

        LotNo := LotSerialGen.GenerateLotNoForItem(WhseReceiptLine."Item No.");
        if LotNo = '' then
            Error(
                '%1 ürünü için Lot Nos. numara serisi tanımlı değildir. Ürün kartındaki Lot Nos. alanını kontrol edin.',
                WhseReceiptLine."Item No.");
        exit(LotNo);
    end;

    /// <summary>Tedarikçi lotu isteğe bağlıdır; girilmişse iç lotla ilişkilendirilir.</summary>
    procedure ReceiptLineRequiresSupplierLot(WhseReceiptLine: Record "Warehouse Receipt Line"): Boolean
    begin
        exit(false);
    end;

    /// <summary>Satırdaki ürünün lot takibi gerektirip gerektirmediğini döndürür.</summary>
    procedure ReceiptLineRequiresLot(WhseReceiptLine: Record "Warehouse Receipt Line"): Boolean
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        if not GetReceiptLineTrackingCode(WhseReceiptLine, Item, ItemTrackingCode) then
            exit(false);
        exit(RequiresLotTracking(ItemTrackingCode));
    end;

    /// <summary>Satırdaki ürünün seri takibi gerektirip gerektirmediğini döndürür.</summary>
    procedure ReceiptLineRequiresSerial(WhseReceiptLine: Record "Warehouse Receipt Line"): Boolean
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        if not GetReceiptLineTrackingCode(WhseReceiptLine, Item, ItemTrackingCode) then
            exit(false);
        exit(RequiresSerialTracking(ItemTrackingCode));
    end;

    /// <summary>Satırdaki takip kodunda son kullanma tarihinin kullanıldığını döndürür.</summary>
    procedure ReceiptLineUsesExpirationDates(WhseReceiptLine: Record "Warehouse Receipt Line"): Boolean
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        if not GetReceiptLineTrackingCode(WhseReceiptLine, Item, ItemTrackingCode) then
            exit(false);
        exit(ItemTrackingCode."Use Expiration Dates");
    end;

    /// <summary>Satırdaki takip kodunda SKT girişinin zorunlu olduğunu döndürür.</summary>
    procedure ReceiptLineRequiresExpirationDate(WhseReceiptLine: Record "Warehouse Receipt Line"): Boolean
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        if not GetReceiptLineTrackingCode(WhseReceiptLine, Item, ItemTrackingCode) then
            exit(false);
        exit(ItemTrackingCode."Man. Expir. Date Entry Reqd.");
    end;

    /// <summary>
    /// İç lot numarasına bağlı tedarikçi lotunu Lot No. Information
    /// Description alanından okur. BadeProduction mevcut Tedarikçi Lotu alanı
    /// olarak bu standart alanı kullanır; mobil istemci de aynı kaynağı kullanmalıdır.
    /// </summary>
    procedure GetSupplierLot(WhseReceiptLine: Record "Warehouse Receipt Line"; LotNo: Code[50]; var SupplierLotNo: Code[50])
    var
        LotNoInformation: Record "Lot No. Information";
    begin
        Clear(SupplierLotNo);
        if LotNo = '' then
            exit;
        if LotNoInformation.Get(WhseReceiptLine."Item No.", WhseReceiptLine."Variant Code", LotNo) then
            SupplierLotNo := CopyStr(LotNoInformation.Description, 1, MaxStrLen(SupplierLotNo));
    end;

    local procedure PersistSupplierLot(ItemNo: Code[20]; VariantCode: Code[10]; LotNo: Code[50]; SupplierLotNo: Code[50])
    var
        LotNoInformation: Record "Lot No. Information";
    begin
        if LotNo = '' then
            Error('Tedarikçi lotu %1 kaydedilemedi; iç lot numarası boş.', SupplierLotNo);

        if not LotNoInformation.Get(ItemNo, VariantCode, LotNo) then begin
            LotNoInformation.Init();
            LotNoInformation."Item No." := ItemNo;
            LotNoInformation."Variant Code" := VariantCode;
            LotNoInformation."Lot No." := LotNo;
            LotNoInformation.Insert(true);
        end;

        if (LotNoInformation.Description <> '') and
           (LotNoInformation.Description <> SupplierLotNo)
        then
            Error(
                '%1 iç lotu daha önce %2 tedarikçi lotuyla eşleştirilmiş. Girilen değer: %3.',
                LotNo, LotNoInformation.Description, SupplierLotNo);

        if LotNoInformation.Description <> SupplierLotNo then begin
            LotNoInformation.Validate(Description, SupplierLotNo);
            LotNoInformation.Modify(true);
        end;
    end;

    /// <summary>
    /// Warehouse Receipt Line'ın lot/seri/SKT bilgisini BC'nin Item Tracking
    /// mekanizmasına yazar. Warehouse Receipt satırında Lot No. alanı yoktur;
    /// BC'nin Item Tracking Lines ekranı kaynak Purchase Line'ın Reservation
    /// Entry kayıtlarını gösterir. Idempotent: aynı kaynak satırın önceki
    /// takip kayıtları silinip yeniden yazılır.
    /// </summary>
    local procedure PersistItemTracking(WhseReceiptLine: Record "Warehouse Receipt Line"; LotNo: Code[50]; SerialNo: Code[50]; ExpiryDate: Date)
    var
        CreateReservEntry: Codeunit "Create Reserv. Entry";
        ReservationEntry: Record "Reservation Entry";
        SourceSubtype: Integer;
    begin
        DeleteSourceReservationTracking(WhseReceiptLine);
        DeleteWarehouseItemTracking(WhseReceiptLine);

        if (LotNo = '') and (SerialNo = '') then
            exit;
        if WhseReceiptLine."Qty. to Receive" = 0 then
            exit;

        SourceSubtype := WhseReceiptLine."Source Subtype";
        ReservationEntry.Init();
        ReservationEntry."Lot No." := LotNo;
        ReservationEntry."Serial No." := SerialNo;
        CreateReservEntry.SetDates(0D, ExpiryDate);
        CreateReservEntry.SetQtyToHandleAndInvoice(WhseReceiptLine."Qty. to Receive (Base)", WhseReceiptLine."Qty. to Receive (Base)");
        CreateReservEntry.CreateReservEntryFor(
            WhseReceiptLine."Source Type",
            SourceSubtype,
            WhseReceiptLine."Source No.",
            '',
            0,
            WhseReceiptLine."Source Line No.",
            WhseReceiptLine."Qty. per Unit of Measure",
            WhseReceiptLine."Qty. to Receive",
            WhseReceiptLine."Qty. to Receive (Base)",
            ReservationEntry);
        CreateReservEntry.CreateEntry(
            WhseReceiptLine."Item No.",
            WhseReceiptLine."Variant Code",
            WhseReceiptLine."Location Code",
            WhseReceiptLine.Description,
            WhseReceiptLine."Due Date",
            0D,
            0,
            Enum::"Reservation Status"::Surplus);
    end;

    /// <summary>
    /// BC UI'dan (veya önceki bir mobil kayıttan) satıra zaten atanmış lot/seri/SKT
    /// varsa okur — mobil GET çağrısında bu bilgi boş dönmesin diye.
    /// </summary>
    procedure GetItemTracking(WhseReceiptLine: Record "Warehouse Receipt Line"; var LotNo: Code[50]; var SerialNo: Code[50]; var ExpiryDate: Date)
    var
        ReservationEntry: Record "Reservation Entry";
        WhseItemTrkgLine: Record "Whse. Item Tracking Line";
    begin
        Clear(LotNo);
        Clear(SerialNo);
        Clear(ExpiryDate);

        SetSourceReservationFilters(ReservationEntry, WhseReceiptLine);
        ReservationEntry.SetFilter("Lot No.", '<>%1', '');
        if ReservationEntry.FindFirst() then begin
            LotNo := ReservationEntry."Lot No.";
            SerialNo := ReservationEntry."Serial No.";
            ExpiryDate := ReservationEntry."Expiration Date";
            exit;
        end;

        ReservationEntry.Reset();
        SetSourceReservationFilters(ReservationEntry, WhseReceiptLine);
        ReservationEntry.SetFilter("Serial No.", '<>%1', '');
        if ReservationEntry.FindFirst() then begin
            LotNo := ReservationEntry."Lot No.";
            SerialNo := ReservationEntry."Serial No.";
            ExpiryDate := ReservationEntry."Expiration Date";
            exit;
        end;

        WhseItemTrkgLine.SetRange("Source Type", Database::"Warehouse Receipt Line");
        WhseItemTrkgLine.SetRange("Source ID", WhseReceiptLine."No.");
        WhseItemTrkgLine.SetRange("Source Ref. No.", WhseReceiptLine."Line No.");
        if not WhseItemTrkgLine.FindFirst() then
            exit;
        LotNo := WhseItemTrkgLine."Lot No.";
        SerialNo := WhseItemTrkgLine."Serial No.";
        ExpiryDate := WhseItemTrkgLine."Expiration Date";
    end;

    local procedure DeleteSourceReservationTracking(WhseReceiptLine: Record "Warehouse Receipt Line")
    var
        ReservationEntry: Record "Reservation Entry";
    begin
        SetSourceReservationFilters(ReservationEntry, WhseReceiptLine);
        ReservationEntry.SetFilter("Lot No.", '<>%1', '');
        ReservationEntry.DeleteAll(true);

        ReservationEntry.Reset();
        SetSourceReservationFilters(ReservationEntry, WhseReceiptLine);
        ReservationEntry.SetFilter("Serial No.", '<>%1', '');
        ReservationEntry.DeleteAll(true);
    end;

    local procedure SetSourceReservationFilters(var ReservationEntry: Record "Reservation Entry"; WhseReceiptLine: Record "Warehouse Receipt Line")
    begin
        ReservationEntry.SetRange("Source Type", WhseReceiptLine."Source Type");
        ReservationEntry.SetRange("Source Subtype", WhseReceiptLine."Source Subtype");
        ReservationEntry.SetRange("Source ID", WhseReceiptLine."Source No.");
        ReservationEntry.SetRange("Source Ref. No.", WhseReceiptLine."Source Line No.");
        ReservationEntry.SetRange("Item No.", WhseReceiptLine."Item No.");
    end;

    local procedure DeleteWarehouseItemTracking(WhseReceiptLine: Record "Warehouse Receipt Line")
    var
        WhseItemTrkgLine: Record "Whse. Item Tracking Line";
    begin
        WhseItemTrkgLine.SetRange("Source Type", Database::"Warehouse Receipt Line");
        WhseItemTrkgLine.SetRange("Source ID", WhseReceiptLine."No.");
        WhseItemTrkgLine.SetRange("Source Ref. No.", WhseReceiptLine."Line No.");
        WhseItemTrkgLine.DeleteAll(true);
    end;

    local procedure RequiresLotTracking(ItemTrackingCode: Record "Item Tracking Code"): Boolean
    begin
        exit(ItemTrackingCode."Lot Specific Tracking" or ItemTrackingCode."Lot Warehouse Tracking" or ItemTrackingCode."Lot Purchase Inbound Tracking");
    end;

    local procedure RequiresSerialTracking(ItemTrackingCode: Record "Item Tracking Code"): Boolean
    begin
        exit(ItemTrackingCode."SN Specific Tracking" or ItemTrackingCode."SN Warehouse Tracking" or ItemTrackingCode."SN Purchase Inbound Tracking");
    end;

    local procedure GetReceiptLineTrackingCode(WhseReceiptLine: Record "Warehouse Receipt Line"; var Item: Record Item; var ItemTrackingCode: Record "Item Tracking Code"): Boolean
    begin
        if not Item.Get(WhseReceiptLine."Item No.") then
            exit(false);
        if Item."Item Tracking Code" = '' then
            exit(false);
        exit(ItemTrackingCode.Get(Item."Item Tracking Code"));
    end;

    local procedure AssignLP(LpNo: Code[20]; ReceiptNo: Code[20])
    var
        LP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        if not LP.Get(LpNo) then
            exit;
        if LP.Status = LP.Status::Built then
            LPMgt.Assign(LP, Enum::"DOPSWHS Assigned Doc Type"::WhseReceipt, ReceiptNo);
    end;

    /// <summary>
    /// İşlemi yapan operatörü belirler: çağıran kimliğini AÇIKÇA bildirdiyse o,
    /// aksi halde belgeye atanmış kullanıcı. NEDEN: paylaşımlı BC hesabı yüzünden
    /// UserId() operatörü göstermiyor; atama tek güvenilir kaynak.
    /// </summary>
    local procedure EffectiveOperator(OperatorUserId: Code[50]; AssignedUserId: Code[50]): Code[50]
    begin
        if OperatorUserId <> '' then
            exit(OperatorUserId);
        exit(AssignedUserId);
    end;

    /// <summary>Belgeye atanmış operatör — satırdan başlığa GÜNCEL okunur.</summary>
    local procedure ReceiptOperator(ReceiptNo: Code[20]): Code[50]
    var
        WhseReceiptHeader: Record "Warehouse Receipt Header";
    begin
        if ReceiptNo = '' then
            exit('');
        if not WhseReceiptHeader.Get(ReceiptNo) then
            exit('');
        exit(WhseReceiptHeader."Assigned User ID");
    end;

    local procedure OperatorOrNone(UserIdValue: Code[50]): Text
    begin
        if UserIdValue = '' then
            exit(NoOperatorTxt);
        exit(UserIdValue);
    end;

    /// <summary>
    /// İşlemi YAPAN operatörle birlikte loglar. Operatör parametresi BİLEREK
    /// zorunlu: her çağrı yeri "kim yaptı" sorusuna cevap vermek zorunda kalsın.
    /// Bilinmiyorsa açıkça '' geçilir (telemetri 'actorSource=BC' yazar).
    /// </summary>
    local procedure Log(Category: Text; Message: Text; OperatorUserId: Code[50])
    var
        Telemetry: Codeunit "DOPSWHS Telemetry";
    begin
        Telemetry.LogInfo(Category, Message, OperatorUserId);
    end;

    var
        // Telemetri mesajları çevrilmez (Locked): log sorguları dile göre değişmemeli.
        AssignLogTxt: Label '%1 -> %2', Locked = true;
        NoOperatorTxt: Label '(none)', Locked = true;
}
