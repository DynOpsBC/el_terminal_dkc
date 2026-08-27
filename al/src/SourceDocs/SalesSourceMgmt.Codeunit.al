codeunit 72291 "DOPSWHS Sales Source Mgmt"
{
    // Sales Order doğrudan sevkiyat (Warehouse Shipment zorunlu değil).
    // Yönetilmeyen lokasyonlarda operatör mobil ekrandan qtyToShip set edip
    // Post-Ship tetikleyebilir.
    Access = Public;

    procedure SetLineQtyToShip(OrderNo: Code[20]; LineNo: Integer; QtyToShip: Decimal; BinCode: Code[20])
    var
        SH: Record "Sales Header";
        SL: Record "Sales Line";
    begin
        if not SH.Get(SH."Document Type"::Order, OrderNo) then
            Error('Sales order %1 not found.', OrderNo);
        EnsureDirectShipAllowed(SH);

        if not SL.Get(SL."Document Type"::Order, OrderNo, LineNo) then
            Error('Sales line %1 / %2 not found.', OrderNo, LineNo);
        if BinCode <> '' then
            SL.Validate("Bin Code", BinCode);
        SL.Validate("Qty. to Ship", QtyToShip);
        SL.Modify(true);

        Session.LogMessage('AdvWMS.SalesSource.SetQty',
            StrSubstNo('SO %1 line %2 qtyToShip=%3', OrderNo, LineNo, QtyToShip),
            Verbosity::Normal, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, EmptyDims());
    end;

    procedure ShipOrder(OrderNo: Code[20]; AlsoInvoice: Boolean): Code[20]
    var
        SH: Record "Sales Header";
        SalesPost: Codeunit "Sales-Post";
    begin
        SH.LockTable();
        if not SH.Get(SH."Document Type"::Order, OrderNo) then
            Error('Sales order %1 not found.', OrderNo);
        EnsureDirectShipAllowed(SH);
        if SH.Status <> SH.Status::Released then
            SH.Validate(Status, SH.Status::Released);

        SH.Ship := true;
        SH.Invoice := AlsoInvoice;
        SH.Modify(true);

        Session.LogMessage('AdvWMS.SalesSource.PostStart',
            StrSubstNo('SO %1 Ship=true Invoice=%2', OrderNo, AlsoInvoice),
            Verbosity::Normal, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, EmptyDims());

        SalesPost.Run(SH);

        Session.LogMessage('AdvWMS.SalesSource.PostDone',
            StrSubstNo('SO %1 posted (Ship=true, Invoice=%2)', OrderNo, AlsoInvoice),
            Verbosity::Normal, DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher, EmptyDims());

        exit(OrderNo);
    end;

    local procedure EnsureDirectShipAllowed(SalesHeader: Record "Sales Header")
    var
        Location: Record Location;
    begin
        if SalesHeader."Location Code" = '' then
            exit;
        if not Location.Get(SalesHeader."Location Code") then
            Error('Location %1 does not exist.', SalesHeader."Location Code");
        if Location."Require Shipment" then
            Error('Sales order %1 uses location %2, which requires a Warehouse Shipment. Use the warehouse shipment flow instead.',
                SalesHeader."No.", SalesHeader."Location Code");
    end;

    local procedure EmptyDims(): Dictionary of [Text, Text]
    var
        D: Dictionary of [Text, Text];
    begin
        exit(D);
    end;
}
