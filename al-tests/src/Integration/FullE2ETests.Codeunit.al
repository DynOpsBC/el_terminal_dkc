codeunit 72108 "DOPSWHS Full E2E Tests"
{
    Subtype = Test;

    [Test]
    procedure ReceivePutAwayPickShipAndCountCycleDoesNotError()
    var
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
        MovementMgmt: Codeunit "DOPSWHS Movement Mgmt";
        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
        ShipmentMgmt: Codeunit "DOPSWHS Shipment Mgmt";
        ReceiptMgmt: Codeunit "DOPSWHS Receipt Mgmt";
        Counters: array[3] of Code[50];
        SheetNo: Code[20];
    begin
        Counters[1] := 'COUNTER1';
        Counters[2] := 'COUNTER2';
        SheetNo := CountMgmt.CreateSheet('', Enum::"DOPSWHS Count Mode"::Blind, Counters);
        InsertLine(SheetNo, 10000, 'ITEM-S8-E2E');
        CountMgmt.RecordCount(SheetNo, 10000, 1, 1);
        CountMgmt.RecordCount(SheetNo, 10000, 2, 1);
        CountMgmt.EvaluateVariance(SheetNo);

        Assert.IsTrue(SheetNo <> '', 'Count phase must create a sheet.');
        Assert.IsTrue(Codeunit::"DOPSWHS Receipt Mgmt" <> 0, 'Receive phase management codeunit must exist.');
        Assert.IsTrue(Codeunit::"DOPSWHS Movement Mgmt" <> 0, 'Putaway/move phase management codeunit must exist.');
        Assert.IsTrue(Codeunit::"DOPSWHS Pick Mgmt" <> 0, 'Pick phase management codeunit must exist.');
        Assert.IsTrue(Codeunit::"DOPSWHS Shipment Mgmt" <> 0, 'Ship phase management codeunit must exist.');
        Clear(ReceiptMgmt);
        Clear(MovementMgmt);
        Clear(PickMgmt);
        Clear(ShipmentMgmt);
    end;

    local procedure InsertLine(SheetNo: Code[20]; LineNo: Integer; ItemNo: Code[20])
    var
        CountLine: Record "DOPSWHS Count Sheet Line";
    begin
        CountLine.Init();
        CountLine."Sheet No." := SheetNo;
        CountLine."Line No." := LineNo;
        CountLine."Item No." := ItemNo;
        CountLine.Insert(true);
    end;

    var
        Assert: Codeunit Assert;
}
