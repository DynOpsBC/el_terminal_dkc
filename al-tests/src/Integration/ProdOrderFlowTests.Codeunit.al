codeunit 72109 "DOPSWHS Prod Flow Tests"
{
    Subtype = Test;

    [Test]
    procedure ReleasedProdOrderConsumesComponentsReportsOutputAndCreatesOutputLp()
    var
        Component: Record "Prod. Order Component";
        RoutingLine: Record "Prod. Order Routing Line";
        LP: Record "DOPSWHS LP Header";
        ProdMgmt: Codeunit "DOPSWHS Prod Mgmt";
        NewLpNo: Code[20];
    begin
        CreateComponent(Component, 'PROD-S7-FLOW', 10000, 'ITEM-S7-COMP', 4);
        CreateRoutingLine(RoutingLine, 'PROD-S7-FLOW', 10000);
        CreateProdOrderLine(RoutingLine, 'ITEM-S7-FG');

        ProdMgmt.Consume(Component, 'ITEM-S7-COMP', 4, '', '', '', 'PROD');
        NewLpNo := ProdMgmt.ReportOutput(RoutingLine, 1, 0, 15, 'PALLET-EUR', 'OUTPUT');

        LP.Get(NewLpNo);
        Assert.AreEqual(LP.Status::Built, LP.Status, 'End-to-end production output must create a built output LP.');
    end;

    local procedure CreateComponent(var Component: Record "Prod. Order Component"; ProdOrderNo: Code[20]; LineNo: Integer; ItemNo: Code[20]; Qty: Decimal)
    begin
        Component.Init();
        Component.Status := Component.Status::Released;
        Component."Prod. Order No." := ProdOrderNo;
        Component."Prod. Order Line No." := 10000;
        Component."Line No." := LineNo;
        Component."Item No." := ItemNo;
        Component.Quantity := Qty;
        Component."Remaining Quantity" := Qty;
        Component."Location Code" := 'BLUE';
        Component."Bin Code" := 'PROD';
        Component.Insert(true);
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
