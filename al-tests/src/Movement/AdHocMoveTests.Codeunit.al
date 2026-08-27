codeunit 72117 "DOPSWHS AdHoc Move Tests"
{
    Subtype = Test;

    [Test]
    procedure BinToBinMoveUsesDeviceBatch()
    var
        TestHelper: Codeunit "DOPSWHS Test Helper";
        Setup: Record "DOPSWHS Setup";
        ItemJournalBatch: Record "Item Journal Batch";
        MovementMgmt: Codeunit "DOPSWHS Movement Mgmt";
        BatchName: Code[10];
    begin
        Setup := TestHelper.EnsureSetup();
        Setup."Default Location Code" := 'BLUE';
        Setup.Modify(true);

        BatchName := MovementMgmt.EnsureDeviceJournalBatch('USER1');

        ItemJournalBatch.SetRange(Name, BatchName);
        Assert.IsFalse(ItemJournalBatch.IsEmpty(), 'Ad-hoc move must create or reuse the user-specific reclass journal batch.');
    end;

    [Test]
    procedure LpMoveSetsPackageNoOnJournalLine()
    var
        TestHelper: Codeunit "DOPSWHS Test Helper";
        Setup: Record "DOPSWHS Setup";
        ItemJournalLine: Record "Item Journal Line";
        MovementMgmt: Codeunit "DOPSWHS Movement Mgmt";
        BatchName: Code[10];
    begin
        Setup := TestHelper.EnsureSetup();
        Setup."Default Location Code" := 'BLUE';
        Setup.Modify(true);

        BatchName := MovementMgmt.EnsureDeviceJournalBatch('LPUSER');
        MovementMgmt.AdHocMove('RECEIVE', 'PUT-01', 'ITEM-S4-MOVE', 'LP-S4-MOVE', 1, 'LPUSER');

        ItemJournalLine.SetRange("Journal Batch Name", BatchName);
        ItemJournalLine.SetRange("Package No.", 'LP-S4-MOVE');
        Assert.IsFalse(ItemJournalLine.IsEmpty(), 'LP No. must be carried to the item reclass journal line package field.');
    end;

    var
        Assert: Codeunit Assert;
        LibraryWarehouse: Codeunit "Library - Warehouse";
        LibraryInventory: Codeunit "Library - Inventory";
}
