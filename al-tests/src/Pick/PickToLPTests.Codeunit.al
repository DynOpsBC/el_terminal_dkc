codeunit 72121 "DOPSWHS Pick To LP Tests"
{
    Subtype = Test;

    [Test]
    procedure StartAccumulateAndStopShippingLp()
    var
        Pick: Record "Warehouse Activity Header";
        PickLine: Record "Warehouse Activity Line";
        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
        Assert: Codeunit Assert;
        LpNo: Code[20];
        Sscc: Code[18];
    begin
        CreatePick(Pick, 'PICK-T5-LP');
        LpNo := PickMgmt.StartShippingLP(Pick, 'PALLET-EUR');
        CreateLine(PickLine, Pick."No.", 10000, LpNo);
        CreateLine(PickLine, Pick."No.", 20000, LpNo);
        Sscc := PickMgmt.StopShippingLP(Pick, LpNo, false);
        Assert.AreNotEqual('', Sscc, 'Stop LP must generate SSCC.');
        Assert.AreEqual(LpNo, PickLine."LP No.", 'Posted activity line source must carry LP No.');
    end;

    local procedure CreatePick(var Pick: Record "Warehouse Activity Header"; No: Code[20])
    begin
        if Pick.Get(Pick.Type::Pick, No) then Pick.Delete(true);
        Pick.Init(); Pick.Type := Pick.Type::Pick; Pick."No." := No; Pick."Location Code" := 'BLUE'; Pick.Insert(true);
    end;

    local procedure CreateLine(var Line: Record "Warehouse Activity Line"; PickNo: Code[20]; LineNo: Integer; LpNo: Code[20])
    begin
        Line.Init(); Line."Activity Type" := Line."Activity Type"::Pick; Line."No." := PickNo; Line."Line No." := LineNo; Line."LP No." := LpNo; Line.Insert(true);
    end;
}
