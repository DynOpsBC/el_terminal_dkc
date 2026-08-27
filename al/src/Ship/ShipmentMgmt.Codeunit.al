codeunit 72047 "DOPSWHS Shipment Mgmt"
{
    Access = Public;
    Permissions =
        tabledata "Warehouse Entry" = r,
        tabledata "Reservation Entry" = r,
        tabledata "Whse. Item Tracking Line" = r;

    procedure ConfirmShipmentLine(var WhseShipmentLine: Record "Warehouse Shipment Line"; QtyToShip: Decimal; LotNo: Code[50]; LicensePlateNo: Code[20]; SSCC: Code[18])
    var
        WhseShipmentHeader: Record "Warehouse Shipment Header";
    begin
        WhseShipmentLine.Validate("Qty. to Ship", QtyToShip);
        EnsureShipmentLot(WhseShipmentLine, LotNo);
        WhseShipmentLine."DOPSWHS Lot No." := LotNo;
        WhseShipmentLine."LP No." := LicensePlateNo;
        WhseShipmentLine.SSCC := SSCC;
        WhseShipmentLine.Modify(true);

        // Stamp the Whse Shipment Header with this LP (first line wins) so the header-level
        // OData query can surface the carton without drilling lines.
        if LicensePlateNo <> '' then
            if WhseShipmentHeader.Get(WhseShipmentLine."No.") then
                if WhseShipmentHeader."DOPSWHS LP No." = '' then begin
                    WhseShipmentHeader."DOPSWHS LP No." := LicensePlateNo;
                    WhseShipmentHeader.Modify(true);
                end;
    end;

    /// <summary>
    /// Returns the effective outbound lot for a warehouse shipment line. The
    /// mobile override wins; otherwise a single lot assigned on the source
    /// Sales Order Item Tracking Lines is surfaced automatically. Multiple
    /// distinct lots are deliberately left blank so the operator must choose.
    /// </summary>
    procedure GetShipmentLineLot(WhseShipmentLine: Record "Warehouse Shipment Line"; var LotNo: Code[50])
    var
        ReservationEntry: Record "Reservation Entry";
        WhseItemTrackingLine: Record "Whse. Item Tracking Line";
    begin
        Clear(LotNo);
        if WhseShipmentLine."DOPSWHS Lot No." <> '' then begin
            LotNo := WhseShipmentLine."DOPSWHS Lot No.";
            exit;
        end;

        SetSourceReservationFilters(ReservationEntry, WhseShipmentLine);
        ReservationEntry.SetFilter("Lot No.", '<>%1', '');
        if UniqueReservationLot(ReservationEntry, LotNo) then
            exit;
        Clear(LotNo);

        WhseItemTrackingLine.SetRange("Source Type", Database::"Warehouse Shipment Line");
        WhseItemTrackingLine.SetRange("Source ID", WhseShipmentLine."No.");
        WhseItemTrackingLine.SetRange("Source Ref. No.", WhseShipmentLine."Line No.");
        WhseItemTrackingLine.SetFilter("Lot No.", '<>%1', '');
        UniqueWarehouseTrackingLot(WhseItemTrackingLine, LotNo);
    end;

    procedure CreatePick(var WhseShipmentHeader: Record "Warehouse Shipment Header"): Code[20]
    begin
        exit(CreatePickForUser(WhseShipmentHeader, CopyStr(UserId(), 1, MaxStrLen(WhseShipmentHeader."Assigned User ID"))));
    end;

    procedure CreatePickFor(var WhseShipmentHeader: Record "Warehouse Shipment Header"; RequestingUserId: Code[50]): Code[20]
    begin
        if RequestingUserId = '' then
            Error('WMS kullanıcı kimliği boş olamaz. Terminal oturumunu yenileyin.');
        if WhseShipmentHeader."Assigned User ID" <> RequestingUserId then
            Error('Sevkiyat belgesi %1 bu kullanıcıya atanmış değil.', WhseShipmentHeader."No.");
        exit(CreatePickForUser(WhseShipmentHeader, RequestingUserId));
    end;

    local procedure CreatePickForUser(var WhseShipmentHeader: Record "Warehouse Shipment Header"; AssignToUserId: Code[50]): Code[20]
    var
        WhseShipmentLine: Record "Warehouse Shipment Line";
        WhseActivityLine: Record "Warehouse Activity Line";
        WhseShipmentRelease: Codeunit "Whse.-Shipment Release";
        CreatePickReport: Report "Whse.-Shipment - Create Pick";
        PickNo: Code[20];
        ReportUserId: Code[50];
    begin
        // Aynı sevkiyat için açık pick varsa ikinci bir pick üretme; mevcut kaydı döndür.
        PickNo := FindOpenPick(WhseShipmentHeader."No.");
        if PickNo <> '' then begin
            EnsurePickAssignedTo(PickNo, AssignToUserId);
            StampShipmentLotsOnPick(WhseShipmentHeader."No.", PickNo);
            exit(PickNo);
        end;

        if WhseShipmentHeader.Status <> WhseShipmentHeader.Status::Released then begin
            WhseShipmentRelease.Release(WhseShipmentHeader);
            WhseShipmentHeader.Get(WhseShipmentHeader."No.");
        end;

        WhseShipmentLine.SetRange("No.", WhseShipmentHeader."No.");
        if not WhseShipmentLine.FindFirst() then
            Error(NoShipmentLinesErr, WhseShipmentHeader."No.");

        // Microsoft raporu gerçek BC/Warehouse Employee hesabıyla çalışsın;
        // oluşturulan başlığın operasyonel sahibi aşağıda yerel WMS kullanıcısı
        // olarak atomik biçimde damgalanır.
        ReportUserId := CopyStr(UserId(), 1, MaxStrLen(ReportUserId));
        CreatePickReport.SetWhseShipmentLine(WhseShipmentLine, WhseShipmentHeader);
        CreatePickReport.SetHideValidationDialog(true);
        CreatePickReport.Initialize(ReportUserId, Enum::"Whse. Activity Sorting Method"::"Shelf or Bin", false, false, false);
        CreatePickReport.UseRequestPage(false);
        CreatePickReport.RunModal();

        WhseActivityLine.SetRange("Activity Type", WhseActivityLine."Activity Type"::Pick);
        WhseActivityLine.SetRange("Whse. Document Type", WhseActivityLine."Whse. Document Type"::Shipment);
        WhseActivityLine.SetRange("Whse. Document No.", WhseShipmentHeader."No.");
        if not WhseActivityLine.FindLast() then
            Error(PickNotCreatedErr, WhseShipmentHeader."No.");
        PickNo := WhseActivityLine."No.";

        EnsurePickAssignedTo(PickNo, AssignToUserId);

        StampShipmentLotsOnPick(WhseShipmentHeader."No.", PickNo);
        exit(PickNo);
    end;

    local procedure EnsurePickAssignedTo(PickNo: Code[20]; AssignToUserId: Code[50])
    var
        PickHeader: Record "Warehouse Activity Header";
        ServiceUserId: Code[50];
    begin
        if AssignToUserId = '' then
            exit;
        PickHeader.Get(PickHeader.Type::Pick, PickNo);
        ServiceUserId := CopyStr(UserId(), 1, MaxStrLen(ServiceUserId));
        if (PickHeader."Assigned User ID" <> '') and
           (PickHeader."Assigned User ID" <> AssignToUserId) and
           (PickHeader."Assigned User ID" <> ServiceUserId)
        then
            Error('Ambar toplama %1, %2 kullanıcısına atanmış.', PickNo, PickHeader."Assigned User ID");
        if PickHeader."Assigned User ID" <> AssignToUserId then begin
            PickHeader."Assigned User ID" := CopyStr(AssignToUserId, 1, MaxStrLen(PickHeader."Assigned User ID"));
            PickHeader.Modify(true);
        end;
    end;

    local procedure FindOpenPick(ShipmentNo: Code[20]): Code[20]
    var
        WhseActivityLine: Record "Warehouse Activity Line";
    begin
        WhseActivityLine.SetRange("Activity Type", WhseActivityLine."Activity Type"::Pick);
        WhseActivityLine.SetRange("Whse. Document Type", WhseActivityLine."Whse. Document Type"::Shipment);
        WhseActivityLine.SetRange("Whse. Document No.", ShipmentNo);
        if WhseActivityLine.FindFirst() then
            exit(WhseActivityLine."No.");
        exit('');
    end;

    local procedure StampShipmentLotsOnPick(ShipmentNo: Code[20]; PickNo: Code[20])
    var
        WhseShipmentLine: Record "Warehouse Shipment Line";
        WhseActivityLine: Record "Warehouse Activity Line";
        LotNo: Code[50];
    begin
        WhseActivityLine.SetRange("Activity Type", WhseActivityLine."Activity Type"::Pick);
        WhseActivityLine.SetRange("No.", PickNo);
        WhseActivityLine.SetRange("Whse. Document Type", WhseActivityLine."Whse. Document Type"::Shipment);
        WhseActivityLine.SetRange("Whse. Document No.", ShipmentNo);
        if WhseActivityLine.FindSet(true) then
            repeat
                if WhseShipmentLine.Get(ShipmentNo, WhseActivityLine."Whse. Document Line No.") then begin
                    GetShipmentLineLot(WhseShipmentLine, LotNo);
                    if LotNo <> '' then begin
                        WhseActivityLine.Validate("Lot No.", LotNo);
                        WhseActivityLine.Modify(true);
                    end;
                end;
            until WhseActivityLine.Next() = 0;
    end;

    procedure PostShipment(var WhseShipmentHeader: Record "Warehouse Shipment Header"; PrintPackingSlip: Boolean; Invoice: Boolean)
    begin
        PostShipment(WhseShipmentHeader, PrintPackingSlip, Invoice, '');
    end;

    procedure PostShipment(var WhseShipmentHeader: Record "Warehouse Shipment Header"; PrintPackingSlip: Boolean; Invoice: Boolean; PrinterId: Code[50])
    var
        WhseShipmentLine: Record "Warehouse Shipment Line";
        PostedWhseShipmentLine: Record "Posted Whse. Shipment Line";
        PostedWhseShipmentHeader: Record "Posted Whse. Shipment Header";
        WhsePostShipment: Codeunit "Whse.-Post Shipment";
        WhseShipmentRelease: Codeunit "Whse.-Shipment Release";
        PrintDispatcher: Codeunit "DOPSWHS Print Dispatcher";
        Telemetry: Codeunit "DOPSWHS Telemetry";
        LineLp: Dictionary of [Integer, Code[20]];
        LineSscc: Dictionary of [Integer, Code[18]];
        LpNo: Code[20];
        Sscc: Code[18];
        LineCount: Integer;
        LpCount: Integer;
        PostedNo: Code[20];
    begin
        EnsureRequiredShipmentLots(WhseShipmentHeader."No.");
        if PrintPackingSlip then begin
            EnsureShipmentReportConfigured();
            PrintDispatcher.EnsureDocumentPrinter(PrinterId, Enum::"DOPSWHS IWX Report Usage"::PostedShipment);
        end;
        // Mobile-friendly: auto-release if the shipment is still Open (e.g. a Qty. to Ship edit
        // reopened it), so the operator doesn't have to re-release in BC before posting.
        if WhseShipmentHeader.Status <> WhseShipmentHeader.Status::Released then begin
            WhseShipmentRelease.Release(WhseShipmentHeader);
            WhseShipmentHeader.Get(WhseShipmentHeader."No.");
        end;
        WhseShipmentHeader.TestField(Status, WhseShipmentHeader.Status::Released);

        WhseShipmentLine.SetRange("No.", WhseShipmentHeader."No.");
        if WhseShipmentLine.FindSet(true) then
            repeat
                LineCount += 1;
                if WhseShipmentLine."LP No." <> '' then begin
                    LpNo := WhseShipmentLine."LP No.";
                    EnsureLpSscc(LpNo, Sscc);
                    WhseShipmentLine.SSCC := Sscc;
                    WhseShipmentLine.Modify(true);
                    LineLp.Set(WhseShipmentLine."Line No.", LpNo);
                    LineSscc.Set(WhseShipmentLine."Line No.", Sscc);
                end;
            until WhseShipmentLine.Next() = 0;

        EnsureAssignedShipmentLpsHaveSscc(WhseShipmentHeader."No.", LpCount);

        if WhseShipmentLine.FindFirst() then
            WhsePostShipment.Run(WhseShipmentLine);

        PostedWhseShipmentHeader.SetRange("Whse. Shipment No.", WhseShipmentHeader."No.");
        if PostedWhseShipmentHeader.FindLast() then
            PostedNo := PostedWhseShipmentHeader."No.";

        PostedWhseShipmentLine.SetRange("Whse. Shipment No.", WhseShipmentHeader."No.");
        if PostedWhseShipmentLine.FindSet(true) then
            repeat
                if LineLp.Get(PostedWhseShipmentLine."Whse Shipment Line No.", LpNo) then begin
                    LineSscc.Get(PostedWhseShipmentLine."Whse Shipment Line No.", Sscc);
                    PostedWhseShipmentLine."LP No." := LpNo;
                    PostedWhseShipmentLine.SSCC := Sscc;
                    PostedWhseShipmentLine.Modify(true);
                    MarkLpUsed(LpNo);
                end;
            until PostedWhseShipmentLine.Next() = 0;

        StampHeaders(WhseShipmentHeader."No.", PostedNo);

        if PrintPackingSlip then begin
            ClearLastError();
            if not QueuePostedShipmentPrint(PostedNo, PrinterId) then
                Telemetry.LogWarning(
                    'Print.ShipmentFailed',
                    CopyStr(StrSubstNo('Shipment %1 posted, but its print job could not be queued: %2', PostedNo, GetLastErrorText()), 1, 250),
                    WhseShipmentHeader."Assigned User ID");
        end;

        LogShipmentPosted(WhseShipmentHeader."No.", LineCount, LpCount + LineLp.Count());
    end;

    /// <summary>
    /// Sevkiyat satırındaki ürünün lot takipli olup olmadığını döndürür.
    /// Mobil uygulama alan etiketini ve Onayla butonunu bu bilgiyle yönetir;
    /// asıl zorunluluk Confirm/Post içinde sunucu tarafında da uygulanır.
    /// </summary>
    procedure ShipmentLineRequiresLot(WhseShipmentLine: Record "Warehouse Shipment Line"): Boolean
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        if not Item.Get(WhseShipmentLine."Item No.") then
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

    local procedure SetSourceReservationFilters(var ReservationEntry: Record "Reservation Entry"; WhseShipmentLine: Record "Warehouse Shipment Line")
    begin
        ReservationEntry.SetRange("Source Type", WhseShipmentLine."Source Type");
        ReservationEntry.SetRange("Source Subtype", WhseShipmentLine."Source Subtype");
        ReservationEntry.SetRange("Source ID", WhseShipmentLine."Source No.");
        ReservationEntry.SetRange("Source Ref. No.", WhseShipmentLine."Source Line No.");
        ReservationEntry.SetRange("Item No.", WhseShipmentLine."Item No.");
        ReservationEntry.SetRange("Variant Code", WhseShipmentLine."Variant Code");
    end;

    local procedure UniqueReservationLot(var ReservationEntry: Record "Reservation Entry"; var LotNo: Code[50]): Boolean
    begin
        Clear(LotNo);
        if ReservationEntry.FindSet() then
            repeat
                if LotNo = '' then
                    LotNo := ReservationEntry."Lot No."
                else
                    if LotNo <> ReservationEntry."Lot No." then begin
                        Clear(LotNo);
                        exit(false);
                    end;
            until ReservationEntry.Next() = 0;
        exit(LotNo <> '');
    end;

    local procedure UniqueWarehouseTrackingLot(var WhseItemTrackingLine: Record "Whse. Item Tracking Line"; var LotNo: Code[50]): Boolean
    begin
        Clear(LotNo);
        if WhseItemTrackingLine.FindSet() then
            repeat
                if LotNo = '' then
                    LotNo := WhseItemTrackingLine."Lot No."
                else
                    if LotNo <> WhseItemTrackingLine."Lot No." then begin
                        Clear(LotNo);
                        exit(false);
                    end;
            until WhseItemTrackingLine.Next() = 0;
        exit(LotNo <> '');
    end;

    local procedure EnsureRequiredShipmentLots(ShipmentNo: Code[20])
    var
        WhseShipmentLine: Record "Warehouse Shipment Line";
        LotNo: Code[50];
    begin
        WhseShipmentLine.SetRange("No.", ShipmentNo);
        WhseShipmentLine.SetFilter("Qty. to Ship", '>0');
        if WhseShipmentLine.FindSet() then
            repeat
                GetShipmentLineLot(WhseShipmentLine, LotNo);
                EnsureShipmentLot(WhseShipmentLine, LotNo);
            until WhseShipmentLine.Next() = 0;
    end;

    local procedure EnsureShipmentLot(WhseShipmentLine: Record "Warehouse Shipment Line"; LotNo: Code[50])
    var
        WarehouseEntry: Record "Warehouse Entry";
        AvailableQtyBase: Decimal;
    begin
        if (WhseShipmentLine."Qty. to Ship" <= 0) or (not ShipmentLineRequiresLot(WhseShipmentLine)) then
            exit;

        if LotNo = '' then
            Error(
                '%1 ürününün %2 sevkiyat satırında lot numarası zorunludur. Stoktaki lotlardan birini seçin.',
                WhseShipmentLine."Item No.", WhseShipmentLine."Line No.");

        WarehouseEntry.SetCurrentKey(
            "Item No.", "Bin Code", "Location Code", "Variant Code",
            "Unit of Measure Code", "Lot No.");
        WarehouseEntry.SetRange("Item No.", WhseShipmentLine."Item No.");
        WarehouseEntry.SetRange("Variant Code", WhseShipmentLine."Variant Code");
        WarehouseEntry.SetRange("Location Code", WhseShipmentLine."Location Code");
        WarehouseEntry.SetRange("Lot No.", LotNo);
        WarehouseEntry.CalcSums("Qty. (Base)");
        AvailableQtyBase := WarehouseEntry."Qty. (Base)";

        if AvailableQtyBase < WhseShipmentLine."Qty. to Ship (Base)" then
            Error(
                '%1 lotunda %2 lokasyonunda yeterli stok yok. Mevcut (temel): %3, sevk edilecek (temel): %4.',
                LotNo,
                WhseShipmentLine."Location Code",
                AvailableQtyBase,
                WhseShipmentLine."Qty. to Ship (Base)");
    end;

    local procedure StampHeaders(WhseShipmentNo: Code[20]; PostedShipmentNo: Code[20])
    var
        LpPropagation: Codeunit "DOPSWHS LP Propagation";
    begin
        LpPropagation.StampShipmentHeader(WhseShipmentNo);
        LpPropagation.StampPostedShipmentHeader(WhseShipmentNo, PostedShipmentNo);
    end;

    procedure PostSalesOrderShipAndInvoice(var SalesHeader: Record "Sales Header")
    var
        SalesPost: Codeunit "Sales-Post";
        CustomDimensions: Dictionary of [Text, Text];
    begin
        SalesHeader.TestField("Document Type", SalesHeader."Document Type"::Order);
        OnBeforeShipSales(SalesHeader."No.");
        SalesHeader.Ship := true;
        SalesHeader.Invoice := true;
        SalesPost.Run(SalesHeader);
        OnAfterInvoiceSales(SalesHeader."No.");
        CustomDimensions.Add('docNo', SalesHeader."No.");
        Session.LogMessage('AdvWMS.Sales.ShipAndInvoice', StrSubstNo('Sales order %1 shipped and invoiced from mobile.', SalesHeader."No."), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;

    procedure PostTransferShip(var TransferHeader: Record "Transfer Header")
    var
        TransferPostShipment: Codeunit "TransferOrder-Post Shipment";
        CustomDimensions: Dictionary of [Text, Text];
    begin
        TransferPostShipment.Run(TransferHeader);
        CustomDimensions.Add('docNo', TransferHeader."No.");
        Session.LogMessage('AdvWMS.Transfer.Shipped', StrSubstNo('Transfer order %1 shipped from mobile.', TransferHeader."No."), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;

    local procedure EnsureLpSscc(LpNo: Code[20]; var Sscc: Code[18])
    var
        LP: Record "DOPSWHS LP Header";
        Generator: Codeunit "DOPSWHS SSCC Generator";
    begin
        LP.Get(LpNo);
        if LP.SSCC = '' then begin
            LP.SSCC := Generator.Generate();
            LP.Modify(true);
        end;
        Sscc := LP.SSCC;
    end;

    local procedure EnsureAssignedShipmentLpsHaveSscc(ShipmentNo: Code[20]; var LpCount: Integer)
    var
        LP: Record "DOPSWHS LP Header";
        Sscc: Code[18];
    begin
        LP.SetRange("Assigned Document Type", LP."Assigned Document Type"::WhseShipment);
        LP.SetRange("Assigned Document No.", ShipmentNo);
        if LP.FindSet(true) then
            repeat
                LpCount += 1;
                EnsureLpSscc(LP."No.", Sscc);
            until LP.Next() = 0;
    end;

    local procedure MarkLpUsed(LpNo: Code[20])
    var
        LP: Record "DOPSWHS LP Header";
    begin
        if not LP.Get(LpNo) then
            exit;
        LP.Status := LP.Status::Used;
        LP.Modify(true);
    end;

    [TryFunction]
    local procedure QueuePostedShipmentPrint(PostedShipmentNo: Code[20]; PrinterId: Code[50])
    var
        PostedShipment: Record "Posted Whse. Shipment Header";
        ReportSelection: Record "DOPSWHS IWX Report Selection";
        PrintDispatcher: Codeunit "DOPSWHS Print Dispatcher";
        SourceRecord: RecordRef;
    begin
        if PostedShipmentNo = '' then
            Error('The posted warehouse shipment could not be found for printing.');
        ReportSelection.SetCurrentKey(Usage, Sequence);
        ReportSelection.SetRange(Usage, ReportSelection.Usage::PostedShipment);
        ReportSelection.SetFilter("Report ID", '<>0');
        if not ReportSelection.FindFirst() then
            Error('No report is configured for Posted Shipment printing.');
        PostedShipment.Get(PostedShipmentNo);
        PostedShipment.SetRecFilter();
        SourceRecord.GetTable(PostedShipment);
        PrintDispatcher.PrintReport(PostedShipmentNo, ReportSelection."Report ID", PrinterId, 1, ReportSelection.Usage, SourceRecord);
    end;

    local procedure EnsureShipmentReportConfigured()
    var
        ReportSelection: Record "DOPSWHS IWX Report Selection";
    begin
        ReportSelection.SetCurrentKey(Usage, Sequence);
        ReportSelection.SetRange(Usage, ReportSelection.Usage::PostedShipment);
        ReportSelection.SetFilter("Report ID", '<>0');
        if not ReportSelection.FindFirst() then
            Error('No report is configured for Posted Shipment printing.');
    end;

    local procedure LogShipmentPosted(DocNo: Code[20]; LineCount: Integer; LpCount: Integer)
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CustomDimensions.Add('docNo', DocNo);
        CustomDimensions.Add('lineCount', Format(LineCount));
        CustomDimensions.Add('lpCount', Format(LpCount));
        Session.LogMessage('AdvWMS.Shipment.Posted', StrSubstNo('Warehouse shipment %1 posted from mobile.', DocNo), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;

    var
        NoShipmentLinesErr: Label 'Warehouse shipment %1 has no lines.', Comment = '%1 = Warehouse Shipment No.';
        PickNotCreatedErr: Label 'No warehouse pick was created for shipment %1. Check bin content and available quantity.', Comment = '%1 = Warehouse Shipment No.';

    [BusinessEvent(false)]
    local procedure OnBeforeShipSales(SalesOrderNo: Code[20])
    begin
    end;

    [BusinessEvent(false)]
    local procedure OnAfterInvoiceSales(SalesOrderNo: Code[20])
    begin
    end;
}
