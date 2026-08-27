codeunit 72103 "DOPSWHS Count Create Tests"
{
    Subtype = Test;

    [Test]
    procedure CreateSheetCreatesHeaderBatchAndCounters()
    var
        CountHeader: Record "DOPSWHS Count Sheet Header";
        Counter: Record "DOPSWHS Count Counter";
        ItemJournalBatch: Record "Item Journal Batch";
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
        Counters: array[3] of Code[50];
        SheetNo: Code[20];
    begin
        EnsureLocation('BLUE');
        Counters[1] := 'COUNTER1';
        Counters[2] := 'COUNTER2';

        SheetNo := CountMgmt.CreateSheet('BLUE', Enum::"DOPSWHS Count Mode"::Blind, Counters);

        Assert.AreNotEqual('', SheetNo, 'CreateSheet must assign a sheet number.');
        CountHeader.Get(SheetNo);
        Assert.IsTrue(ItemJournalBatch.Get('PHYS. INV.', CountHeader."Source Phys. Inv. Journal Batch"), 'Physical inventory journal batch must exist.');
        Counter.SetRange("Sheet No.", SheetNo);
        Assert.AreEqual(2, Counter.Count(), 'Two non-empty counter slots must be assigned.');
    end;

    local procedure EnsureLocation(LocationCode: Code[10])
    var
        Location: Record Location;
    begin
        if not Location.Get(LocationCode) then begin
            Location.Init();
            Location.Code := LocationCode;
            Location.Name := LocationCode;
            Location.Insert(true);
        end;
    end;

    var
        Assert: Codeunit Assert;
}
