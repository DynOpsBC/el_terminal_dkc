codeunit 72290 "DOPSWHS Purch Source Mgmt"
{
    // Purchase Order doğrudan mal kabul (Warehouse Receipt zorunlu değil).
    // Yönetilmeyen lokasyonlarda (Require Receive = false) operatör mobil ekrandan
    // qtyToReceive set edip Post-Receive tetikleyebilir.
    Access = Public;

    procedure SetLineQtyToReceive(OrderNo: Code[20]; LineNo: Integer; QtyToReceive: Decimal; BinCode: Code[20])
    var
        PH: Record "Purchase Header";
        PL: Record "Purchase Line";
    begin
        if not PH.Get(PH."Document Type"::Order, OrderNo) then
            Error('Purchase order %1 not found.', OrderNo);
        EnsureDirectReceiveAllowed(PH);

        if not PL.Get(PL."Document Type"::Order, OrderNo, LineNo) then
            Error('Purchase line %1 / %2 not found.', OrderNo, LineNo);
        if BinCode <> '' then
            PL.Validate("Bin Code", BinCode);
        PL.Validate("Qty. to Receive", QtyToReceive);
        PL.Modify(true);

        Session.LogMessage('AdvWMS.PurchSource.SetQty',
            StrSubstNo('PO %1 line %2 qtyToReceive=%3', OrderNo, LineNo, QtyToReceive),
            Verbosity::Normal, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, EmptyDims());
    end;

    procedure ReceiveOrder(OrderNo: Code[20]; AlsoInvoice: Boolean): Code[20]
    var
        PH: Record "Purchase Header";
        PurchPost: Codeunit "Purch.-Post";
    begin
        PH.LockTable();
        if not PH.Get(PH."Document Type"::Order, OrderNo) then
            Error('Purchase order %1 not found.', OrderNo);
        EnsureDirectReceiveAllowed(PH);
        if PH.Status <> PH.Status::Released then
            PH.Validate(Status, PH.Status::Released);

        PH.Receive := true;
        PH.Invoice := AlsoInvoice;
        PH.Modify(true);

        Session.LogMessage('AdvWMS.PurchSource.PostStart',
            StrSubstNo('PO %1 Receive=%2 Invoice=%3', OrderNo, PH.Receive, PH.Invoice),
            Verbosity::Normal, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, EmptyDims());

        PurchPost.Run(PH);

        Session.LogMessage('AdvWMS.PurchSource.PostDone',
            StrSubstNo('PO %1 posted (Receive%2, Invoice=%3)', OrderNo, ' = true', AlsoInvoice),
            Verbosity::Normal, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, EmptyDims());

        exit(OrderNo);
    end;

    local procedure EnsureDirectReceiveAllowed(PurchaseHeader: Record "Purchase Header")
    var
        Location: Record Location;
    begin
        if PurchaseHeader."Location Code" = '' then
            exit;
        if not Location.Get(PurchaseHeader."Location Code") then
            Error('Location %1 does not exist.', PurchaseHeader."Location Code");
        if Location."Require Receive" then
            Error('Purchase order %1 uses location %2, which requires a Warehouse Receipt. Use the warehouse receiving flow instead.',
                PurchaseHeader."No.", PurchaseHeader."Location Code");
    end;

    local procedure EmptyDims(): Dictionary of [Text, Text]
    var
        D: Dictionary of [Text, Text];
    begin
        exit(D);
    end;
}
