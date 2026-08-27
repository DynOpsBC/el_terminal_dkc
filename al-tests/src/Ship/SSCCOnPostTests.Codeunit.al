codeunit 72135 "DOPSWHS SSCC On Post Tests"
{
    Subtype = Test;

    [Test]
    procedure MissingSsccIsGeneratedAndCopiedToPostedLine()
    var
        WhseShipmentHeader: Record "Warehouse Shipment Header";
        LP: Record "DOPSWHS LP Header";
        PostedWhseShipmentLine: Record "Posted Whse. Shipment Line";
        ShipmentMgmt: Codeunit "DOPSWHS Shipment Mgmt";
        Assert: Codeunit Assert;
    begin
        CreateLP(LP, 'LP-T6-SSCC');
        CreateReleasedShipment(WhseShipmentHeader, 'SHP-T6-SSCC', LP."No.");
        ShipmentMgmt.PostShipment(WhseShipmentHeader, false, false);
        LP.Get(LP."No.");
        Assert.AreNotEqual('', LP.SSCC, 'Posting must generate missing SSCC.');
        PostedWhseShipmentLine.SetRange("Whse. Shipment No.", WhseShipmentHeader."No.");
        PostedWhseShipmentLine.SetRange("LP No.", LP."No.");
        Assert.IsTrue(PostedWhseShipmentLine.FindFirst(), 'Posted shipment line must carry LP No.');
        Assert.AreEqual(LP.SSCC, PostedWhseShipmentLine.SSCC, 'Posted shipment line must carry generated SSCC.');
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
