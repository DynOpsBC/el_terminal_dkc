codeunit 72104 "DOPSWHS Count Variance Tests"
{
    Subtype = Test;

    [Test]
    procedure ThreeCounterMismatchRequiresRecount()
    var
        CountLine: Record "DOPSWHS Count Sheet Line";
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
        Counters: array[3] of Code[50];
        SheetNo: Code[20];
    begin
        Counters[1] := 'COUNTER1';
        Counters[2] := 'COUNTER2';
        Counters[3] := 'COUNTER3';
        SheetNo := CountMgmt.CreateSheet('', Enum::"DOPSWHS Count Mode"::Blind, Counters);
        InsertLine(SheetNo, 10000, 'ITEM-S8-VAR', 'BIN-S8');

        CountMgmt.RecordCount(SheetNo, 10000, 1, 100);
        CountMgmt.RecordCount(SheetNo, 10000, 2, 100);
        CountMgmt.RecordCount(SheetNo, 10000, 3, 95);
        CountMgmt.EvaluateVariance(SheetNo);

        CountLine.Get(SheetNo, 10000);
        Assert.IsTrue(CountLine."Recount Required", 'Any mismatch across three counters must require recount.');
    end;

    local procedure InsertLine(SheetNo: Code[20]; LineNo: Integer; ItemNo: Code[20]; BinCode: Code[20])
    var
        CountLine: Record "DOPSWHS Count Sheet Line";
    begin
        CountLine.Init();
        CountLine."Sheet No." := SheetNo;
        CountLine."Line No." := LineNo;
        CountLine."Item No." := ItemNo;
        CountLine."Bin Code" := BinCode;
        CountLine.Insert(true);
    end;

    var
        Assert: Codeunit Assert;
}
