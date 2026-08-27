codeunit 72142 "DOPSWHS Count V2 Tests"
{
    Subtype = Test;

    [Test]
    procedure PrepareV2MarksEmptySheetAndIsIdempotent()
    var
        CountHeader: Record "DOPSWHS Count Sheet Header";
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
        Counters: array[3] of Code[50];
        SheetNo: Code[20];
    begin
        SheetNo := CountMgmt.CreateSheet('', Enum::"DOPSWHS Count Mode"::Visible, Counters);

        CountMgmt.PrepareV2(SheetNo);
        CountMgmt.PrepareV2(SheetNo);

        CountHeader.Get(SheetNo);
        Assert.IsTrue(CountHeader."V2 Scan Mode", 'An empty sheet must be reserved for V2 scans.');
    end;

    [Test]
    procedure StartRecountClearsEveryCapturedCountField()
    var
        CountHeader: Record "DOPSWHS Count Sheet Header";
        CountLine: Record "DOPSWHS Count Sheet Line";
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
        Counters: array[3] of Code[50];
        SheetNo: Code[20];
    begin
        SheetNo := CountMgmt.CreateSheet('', Enum::"DOPSWHS Count Mode"::Visible, Counters);
        CountLine.Init();
        CountLine."Sheet No." := SheetNo;
        CountLine."Line No." := 10000;
        CountLine."Counted Qty 1" := 11;
        CountLine."Counted Qty 2" := 12;
        CountLine."Counted Qty 3" := 13;
        CountLine."Counted 1" := true;
        CountLine."Counted 2" := true;
        CountLine."Counted 3" := true;
        CountLine.Variance := 2;
        CountLine."Recount Required" := true;
        CountLine.Insert(true);

        CountMgmt.StartRecount(SheetNo);

        CountLine.Get(SheetNo, 10000);
        Assert.AreEqual(0, CountLine."Counted Qty 1", 'First count quantity must be reset.');
        Assert.AreEqual(0, CountLine."Counted Qty 2", 'Second count quantity must be reset.');
        Assert.AreEqual(0, CountLine."Counted Qty 3", 'Third count quantity must be reset.');
        Assert.IsFalse(CountLine."Counted 1", 'First count flag must be reset.');
        Assert.IsFalse(CountLine."Counted 2", 'Second count flag must be reset.');
        Assert.IsFalse(CountLine."Counted 3", 'Third count flag must be reset.');
        Assert.AreEqual(0, CountLine.Variance, 'Variance must be reset.');
        Assert.IsFalse(CountLine."Recount Required", 'Recount marker must be reset.');
        CountHeader.Get(SheetNo);
        Assert.AreEqual(CountHeader.Status::InProgress, CountHeader.Status, 'Sheet must return to in-progress.');
    end;

    [Test]
    procedure PostedSheetHeaderLinesAndCountersAreImmutable()
    var
        CountHeader: Record "DOPSWHS Count Sheet Header";
        CountLine: Record "DOPSWHS Count Sheet Line";
        Counter: Record "DOPSWHS Count Counter";
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
        Counters: array[3] of Code[50];
        SheetNo: Code[20];
    begin
        SheetNo := CountMgmt.CreateSheet('', Enum::"DOPSWHS Count Mode"::Visible, Counters);
        CountLine.Init();
        CountLine."Sheet No." := SheetNo;
        CountLine."Line No." := 10000;
        CountLine.Insert(true);
        Counter.Init();
        Counter."Sheet No." := SheetNo;
        Counter."Counter Slot" := 1;
        Counter.Insert(true);
        CountHeader.Get(SheetNo);
        CountHeader.Status := CountHeader.Status::Posted;
        CountHeader.Modify(true);

        CountHeader."Location Code" := 'ILLEGAL';
        asserterror CountHeader.Modify(true);
        CountLine.Get(SheetNo, 10000);
        CountLine."Counted Qty 1" := 99;
        asserterror CountLine.Modify(true);
        Counter.Get(SheetNo, 1);
        Counter."Assigned DateTime" := CurrentDateTime();
        asserterror Counter.Modify(true);
    end;

    var
        Assert: Codeunit Assert;
}
