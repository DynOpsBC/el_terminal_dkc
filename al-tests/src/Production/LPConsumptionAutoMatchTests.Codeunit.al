codeunit 72126 "DOPSWHS LP Auto Match Tests"
{
    Subtype = Test;

    [Test]
    procedure ScanLpMatchingComponentConsumesFullLpQuantity()
    var
        Component: Record "Prod. Order Component";
        LP: Record "DOPSWHS LP Header";
        LPLine: Record "DOPSWHS LP Line";
        ProdMgmt: Codeunit "DOPSWHS Prod Mgmt";
    begin
        CreateComponent(Component, 'PROD-S7-AUTO', 10000, 'ITEM-S7-COMP', 8);
        CreateLp(LP, LPLine, 'LP-S7-AUTO', 'ITEM-S7-COMP', 8);

        ProdMgmt.FindComponentForLp('PROD-S7-AUTO', '', LP."No.", Component);

        Assert.AreEqual('ITEM-S7-COMP', Component."Item No.", 'LP auto-match must select the single matching component item.');
        Assert.AreEqual(8, LPLine.Quantity, 'The full LP quantity is the proposed consumption quantity.');
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
        Component.Insert(true);
    end;

    local procedure CreateLp(var LP: Record "DOPSWHS LP Header"; var LPLine: Record "DOPSWHS LP Line"; LpNo: Code[20]; ItemNo: Code[20]; Qty: Decimal)
    begin
        LP.Init();
        LP."No." := LpNo;
        LP."Location Code" := 'BLUE';
        LP."Bin Code" := 'PROD';
        LP.Status := LP.Status::Built;
        LP.Insert(true);

        LPLine.Init();
        LPLine."LP No." := LP."No.";
        LPLine."Line No." := 10000;
        LPLine."Item No." := ItemNo;
        LPLine."Unit of Measure" := 'PCS';
        LPLine.Quantity := Qty;
        LPLine.Insert(true);
    end;

    var
        Assert: Codeunit Assert;
}
