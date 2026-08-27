codeunit 72125 "DOPSWHS Prod Consumption Tests"
{
    Subtype = Test;

    [Test]
    procedure ReleasedProdOrderComponentScanCreatesConsumptionEntry()
    var
        Component: Record "Prod. Order Component";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ProdMgmt: Codeunit "DOPSWHS Prod Mgmt";
    begin
        CreateComponent(Component, 'PROD-S7-CONS', 10000, 'ITEM-S7-COMP', 5);

        ProdMgmt.Consume(Component, 'ITEM-S7-COMP', 5, '', '', '', 'PROD');

        ItemLedgerEntry.SetRange("Order No.", 'PROD-S7-CONS');
        ItemLedgerEntry.SetRange("Entry Type", ItemLedgerEntry."Entry Type"::Consumption);
        Assert.IsFalse(ItemLedgerEntry.IsEmpty(), 'Consumption posting must create an item ledger consumption entry.');
    end;

    local procedure CreateComponent(var Component: Record "Prod. Order Component"; ProdOrderNo: Code[20]; LineNo: Integer; ItemNo: Code[20]; Qty: Decimal)
    begin
        Component.Init();
        Component.Status := Component.Status::Released;
        Component."Prod. Order No." := ProdOrderNo;
        Component."Prod. Order Line No." := 10000;
        Component."Line No." := LineNo;
        Component."Item No." := ItemNo;
        Component.Description := 'Sprint 7 component';
        Component."Unit of Measure Code" := 'PCS';
        Component.Quantity := Qty;
        Component."Remaining Quantity" := Qty;
        Component."Location Code" := 'BLUE';
        Component."Bin Code" := 'PROD';
        Component.Insert(true);
    end;

    var
        Assert: Codeunit Assert;
}
