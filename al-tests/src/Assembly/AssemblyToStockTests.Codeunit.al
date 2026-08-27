codeunit 72100 "DOPSWHS Assembly Stock Tests"
{
    Subtype = Test;

    [Test]
    procedure ReleasedAssembleToStockPostsAssembly()
    var
        AssemblyHeader: Record "Assembly Header";
        ItemLedgerEntry: Record "Item Ledger Entry";
        AssemblyMgmt: Codeunit "DOPSWHS Assembly Mgmt";
    begin
        AssemblyHeader.Init();
        AssemblyHeader."Document Type" := AssemblyHeader."Document Type"::Order;
        AssemblyHeader."No." := 'ASM-S7-001';
        AssemblyHeader.Status := AssemblyHeader.Status::Released;
        AssemblyHeader."Item No." := 'ITEM-S7-ASM';
        AssemblyHeader.Quantity := 1;
        AssemblyHeader."Location Code" := 'BLUE';
        AssemblyHeader.Insert(true);

        AssemblyMgmt.PostAssembly(AssemblyHeader);

        ItemLedgerEntry.SetRange("Document No.", 'ASM-S7-001');
        Assert.IsFalse(ItemLedgerEntry.IsEmpty(), 'Assemble-to-stock posting must create item ledger entries.');
    end;

    var
        Assert: Codeunit Assert;
}
