codeunit 72119 "DOPSWHS Batch Isolation Tests"
{
    Subtype = Test;

    [Test]
    procedure DeviceJournalBatchesAreIsolatedByUser()
    var
        MovementMgmt: Codeunit "DOPSWHS Movement Mgmt";
        User1Batch: Code[10];
        User2Batch: Code[10];
    begin
        User1Batch := MovementMgmt.EnsureDeviceJournalBatch('USER1');
        User2Batch := MovementMgmt.EnsureDeviceJournalBatch('USER2');

        Assert.AreNotEqual(User1Batch, User2Batch, 'Different users must receive different reclass journal batches.');
        Assert.AreEqual('DOPS-', CopyStr(User1Batch, 1, 5), 'User 1 batch must follow the DOPS- pattern.');
        Assert.AreEqual('DOPS-', CopyStr(User2Batch, 1, 5), 'User 2 batch must follow the DOPS- pattern.');
    end;

    [Test]
    procedure PostingOneUserLineDoesNotAffectOtherBatch()
    var
        ItemJournalLine: Record "Item Journal Line";
        MovementMgmt: Codeunit "DOPSWHS Movement Mgmt";
        User1Batch: Code[10];
        User2Batch: Code[10];
        User2LineCount: Integer;
    begin
        User1Batch := MovementMgmt.EnsureDeviceJournalBatch('USER1');
        User2Batch := MovementMgmt.EnsureDeviceJournalBatch('USER2');
        InsertJournalLine(User1Batch, 10000, 'ITEM-S4-U1');
        InsertJournalLine(User2Batch, 10000, 'ITEM-S4-U2');

        ItemJournalLine.SetRange("Journal Batch Name", User2Batch);
        User2LineCount := ItemJournalLine.Count();

        ItemJournalLine.SetRange("Journal Batch Name", User1Batch);
        ItemJournalLine.DeleteAll(true);

        ItemJournalLine.SetRange("Journal Batch Name", User2Batch);
        Assert.AreEqual(User2LineCount, ItemJournalLine.Count(), 'Clearing or posting one user batch must not affect another user batch.');
    end;

    local procedure InsertJournalLine(BatchName: Code[10]; LineNo: Integer; ItemNo: Code[20])
    var
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalLine: Record "Item Journal Line";
    begin
        ItemJournalTemplate.SetRange(Type, ItemJournalTemplate.Type::Transfer);
        ItemJournalTemplate.FindFirst();

        ItemJournalLine.Init();
        ItemJournalLine."Journal Template Name" := ItemJournalTemplate.Name;
        ItemJournalLine."Journal Batch Name" := BatchName;
        ItemJournalLine."Line No." := LineNo;
        ItemJournalLine."Posting Date" := WorkDate();
        ItemJournalLine."Entry Type" := ItemJournalLine."Entry Type"::Transfer;
        ItemJournalLine."Document No." := CopyStr('DOPS-' + BatchName, 1, MaxStrLen(ItemJournalLine."Document No."));
        ItemJournalLine."Item No." := ItemNo;
        ItemJournalLine.Quantity := 1;
        ItemJournalLine.Insert(true);
    end;

    var
        Assert: Codeunit Assert;
        LibraryWarehouse: Codeunit "Library - Warehouse";
        LibraryInventory: Codeunit "Library - Inventory";
}
