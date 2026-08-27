codeunit 72106 "DOPSWHS E2E Outbound Tests"
{
    Subtype = Test;

    [Test]
    procedure SalesPickLpShipmentPostsWithLedgerChain()
    var
        WhseShipmentHeader: Record "Warehouse Shipment Header";
        LP: Record "DOPSWHS LP Header";
        PostedWhseShipmentLine: Record "Posted Whse. Shipment Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ShipmentMgmt: Codeunit "DOPSWHS Shipment Mgmt";
        Assert: Codeunit Assert;
    begin
        CreateLP(LP, 'LP-T6-E2E');
        CreateShipment(WhseShipmentHeader, 'SHP-T6-E2E', LP."No.");
        ShipmentMgmt.PostShipment(WhseShipmentHeader, true, false);

        LP.Get(LP."No.");
        PostedWhseShipmentLine.SetRange("Whse. Shipment No.", WhseShipmentHeader."No.");
        PostedWhseShipmentLine.SetRange("LP No.", LP."No.");
        Assert.IsTrue(PostedWhseShipmentLine.FindFirst(), 'Posted line must retain shipping LP.');
        Assert.AreEqual(LP.SSCC, PostedWhseShipmentLine.SSCC, 'Posted line SSCC must match LP header.');
        ItemLedgerEntry.SetRange("Document No.", WhseShipmentHeader."No.");
        Assert.IsFalse(ItemLedgerEntry.IsEmpty(), 'Outbound posting must create item ledger chain.');
    end;

    local procedure CreateLP(var LP: Record "DOPSWHS LP Header"; LpNo: Code[20])
    begin
        if LP.Get(LpNo) then
            LP.Delete(true);
        LP.Init();
        LP."No." := LpNo;
        LP."Location Code" := 'BLUE';
        LP.Status := LP.Status::Built;
        LP.Insert(true);
    end;

    local procedure CreateShipment(var Header: Record "Warehouse Shipment Header"; No: Code[20]; LpNo: Code[20])
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
        Line."Source No." := 'SO-T6-E2E';
        Line."Item No." := 'ITEM-T6';
        Line.Quantity := 1;
        Line."Qty. Outstanding" := 1;
        Line."Qty. to Ship" := 1;
        Line."Unit of Measure Code" := 'PCS';
        Line."LP No." := LpNo;
        Line.Insert(true);
    end;
}
