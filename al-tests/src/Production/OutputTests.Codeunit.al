codeunit 72127 "DOPSWHS Prod Output Tests"
{
    Subtype = Test;

    [Test]
    procedure OperationSelectionPostsOutputScrapAndRuntime()
    var
        RoutingLine: Record "Prod. Order Routing Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ProdMgmt: Codeunit "DOPSWHS Prod Mgmt";
    begin
        CreateRoutingLine(RoutingLine, 'PROD-S7-OUT', 10000);
        CreateProdOrderLine(RoutingLine, 'ITEM-S7-FG');

        ProdMgmt.ReportOutput(RoutingLine, 3, 1, 25, '', 'OUTPUT');

        ItemLedgerEntry.SetRange("Order No.", 'PROD-S7-OUT');
        ItemLedgerEntry.SetRange("Entry Type", ItemLedgerEntry."Entry Type"::Output);
        Assert.IsFalse(ItemLedgerEntry.IsEmpty(), 'Output posting must create an item ledger output entry.');
    end;

    local procedure CreateRoutingLine(var RoutingLine: Record "Prod. Order Routing Line"; ProdOrderNo: Code[20]; RoutingRefNo: Integer)
    begin
        RoutingLine.Init();
        RoutingLine.Status := RoutingLine.Status::Released;
        RoutingLine."Prod. Order No." := ProdOrderNo;
        RoutingLine."Routing Reference No." := RoutingRefNo;
        RoutingLine."Routing No." := 'R-S7';
        RoutingLine."Operation No." := '10';
        RoutingLine."No." := 'WC-S7';
        RoutingLine.Description := 'Assembly operation';
        RoutingLine.Insert(true);
    end;

    local procedure CreateProdOrderLine(var RoutingLine: Record "Prod. Order Routing Line"; ItemNo: Code[20])
    var
        ProdOrderLine: Record "Prod. Order Line";
    begin
        ProdOrderLine.Init();
        ProdOrderLine.Status := RoutingLine.Status;
        ProdOrderLine."Prod. Order No." := RoutingLine."Prod. Order No.";
        ProdOrderLine."Line No." := RoutingLine."Routing Reference No.";
        ProdOrderLine."Item No." := ItemNo;
        ProdOrderLine."Unit of Measure Code" := 'PCS';
        ProdOrderLine."Location Code" := 'BLUE';
        ProdOrderLine."Bin Code" := 'OUTPUT';
        ProdOrderLine.Insert(true);
    end;

    var
        Assert: Codeunit Assert;
}
