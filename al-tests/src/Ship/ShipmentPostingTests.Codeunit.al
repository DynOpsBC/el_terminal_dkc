codeunit 72137 "DOPSWHS Shipment Posting Tests"
{
    Subtype = Test;

    [Test]
    procedure HappyPathPostsReleasedWarehouseShipment()
    var
        WhseShipmentHeader: Record "Warehouse Shipment Header";
        PostedWhseShipmentHeader: Record "Posted Whse. Shipment Header";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ShipmentMgmt: Codeunit "DOPSWHS Shipment Mgmt";
        Assert: Codeunit Assert;
    begin
        CreateReleasedShipment(WhseShipmentHeader, 'SHP-T6-POST', '');
        ShipmentMgmt.PostShipment(WhseShipmentHeader, false, false);
        PostedWhseShipmentHeader.SetRange("Whse. Shipment No.", WhseShipmentHeader."No.");
        Assert.IsFalse(PostedWhseShipmentHeader.IsEmpty(), 'Posted warehouse shipment must exist.');
        ItemLedgerEntry.SetRange("Document No.", WhseShipmentHeader."No.");
        Assert.IsFalse(ItemLedgerEntry.IsEmpty(), 'Shipment posting must create item ledger entries.');
    end;

    local procedure CreateReleasedShipment(var Header: Record "Warehouse Shipment Header"; No: Code[20]; LpNo: Code[20])
    var
        Line: Record "Warehouse Shipment Line";
    begin
        if Header.Get(No) then
            Header.Delete(true);
        Header.Init();
        Header."No." := No;
        Header."Location Code" := 'BLUE';
        Header.Status := Header.Status::Released;
        Header.Insert(true);

        Line.Init();
        Line."No." := No;
        Line."Line No." := 10000;
        Line."Item No." := 'ITEM-T6';
        Line.Quantity := 1;
        Line."Qty. Outstanding" := 1;
        Line."Qty. to Ship" := 1;
        Line."Unit of Measure Code" := 'PCS';
        Line."LP No." := LpNo;
        Line.Insert(true);
    end;
}
