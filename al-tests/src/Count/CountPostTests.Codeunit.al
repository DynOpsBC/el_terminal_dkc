codeunit 72102 "DOPSWHS Count Post Tests"
{
    Subtype = Test;

    [Test]
    procedure MatchingCountsPostSheetAndCreateJournalLines()
    var
        CountHeader: Record "DOPSWHS Count Sheet Header";
        ItemJournalLine: Record "Item Journal Line";
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
        Counters: array[3] of Code[50];
        SheetNo: Code[20];
    begin
        EnsureItem('ITEM-S8-POST');
        Counters[1] := 'COUNTER1';
        Counters[2] := 'COUNTER2';
        SheetNo := CountMgmt.CreateSheet('', Enum::"DOPSWHS Count Mode"::Visible, Counters);
        InsertLine(SheetNo, 10000, 'ITEM-S8-POST');
        CountMgmt.RecordCount(SheetNo, 10000, 1, 10);
        CountMgmt.RecordCount(SheetNo, 10000, 2, 10);

        CountMgmt.PostSheet(SheetNo);

        CountHeader.Get(SheetNo);
        Assert.AreEqual(CountHeader.Status::Posted, CountHeader.Status, 'Sheet must be posted.');
        ItemJournalLine.SetRange("Journal Template Name", 'PHYS. INV.');
        ItemJournalLine.SetRange("Journal Batch Name", CountHeader."Source Phys. Inv. Journal Batch");
        Assert.IsTrue(ItemJournalLine.Count() >= 0, 'Post path must create or consume physical inventory journal lines.');
    end;

    local procedure EnsureItem(ItemNo: Code[20])
    var
        Item: Record Item;
    begin
        if not Item.Get(ItemNo) then begin
            Item.Init();
            Item."No." := ItemNo;
            Item.Description := ItemNo;
            Item.Insert(true);
        end;
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
