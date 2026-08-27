codeunit 72128 "DOPSWHS Output To LP Tests"
{
    Subtype = Test;

    [Test]
    procedure OutputWithNewTemplateCreatesBuiltLpInOutputBin()
    var
        RoutingLine: Record "Prod. Order Routing Line";
        LP: Record "DOPSWHS LP Header";
        ProdMgmt: Codeunit "DOPSWHS Prod Mgmt";
        LpNo: Code[20];
    begin
        CreateRoutingLine(RoutingLine, 'PROD-S7-LP', 10000);
        CreateProdOrderLine(RoutingLine, 'ITEM-S7-FG');

        LpNo := ProdMgmt.ReportOutput(RoutingLine, 2, 0, 10, 'PALLET-EUR', 'OUTPUT');

        LP.Get(LpNo);
        Assert.AreEqual(LP.Status::Built, LP.Status, 'Output LP must be built after reporting output.');
        Assert.AreEqual('OUTPUT', LP."Bin Code", 'Output LP must be created in the selected output bin.');
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
