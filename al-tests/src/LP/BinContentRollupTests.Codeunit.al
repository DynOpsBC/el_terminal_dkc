codeunit 72110 "DOPSWHS Bin Rollup Tests"
{
    Subtype = Test;

    [Test]
    procedure ScenarioAOnePalletTwoCartonsEachFiftyTotalsOneHundred()
    var
        Pallet: Record "DOPSWHS LP Header";
        Carton1: Record "DOPSWHS LP Header";
        Carton2: Record "DOPSWHS LP Header";
        Rollup: Codeunit "DOPSWHS Bin Content Subscriber";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        CreateBuiltLP(Pallet, 'PALLET-EUR', 0);
        CreateBuiltLP(Carton1, 'CARTON-M', 50);
        CreateBuiltLP(Carton2, 'CARTON-M', 50);
        Nest(Carton1, Pallet);
        Nest(Carton2, Pallet);
        Assert.AreEqual(100, Rollup.CalculateNestedLPQuantity('BLUE', 'X', 'ITEMY'), 'Scenario A: carton quantities should roll up once.');
    end;

    [Test]
    procedure ScenarioBLooseThirtyPlusPalletFiftyTotalsEighty()
    var
        Pallet: Record "DOPSWHS LP Header";
        Rollup: Codeunit "DOPSWHS Bin Content Subscriber";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        CreateLooseQty(30);
        CreateBuiltLP(Pallet, 'PALLET-EUR', 50);
        Assert.AreEqual(80, 30 + Rollup.CalculateNestedLPQuantity('BLUE', 'X', 'ITEMY'), 'Scenario B: loose plus LP should total 80.');
    end;

    [Test]
    procedure ScenarioCWhseEntryAgainstLooseLeavesLPTotal()
    var
        Pallet: Record "DOPSWHS LP Header";
        Rollup: Codeunit "DOPSWHS Bin Content Subscriber";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        CreateLooseQty(30);
        CreateBuiltLP(Pallet, 'PALLET-EUR', 50);
        PostWarehouseEntryAgainstLoose(30);
        Assert.AreEqual(50, Rollup.CalculateNestedLPQuantity('BLUE', 'X', 'ITEMY'), 'Scenario C: loose posting should not reduce LP totals.');
    end;

    [Test]
    procedure ScenarioDThreeLevelPalletCartonToteTotalsNoMultiplication()
    var
        Pallet: Record "DOPSWHS LP Header";
        Carton1: Record "DOPSWHS LP Header";
        Carton2: Record "DOPSWHS LP Header";
        Tote1: Record "DOPSWHS LP Header";
        Tote2: Record "DOPSWHS LP Header";
        Tote3: Record "DOPSWHS LP Header";
        Tote4: Record "DOPSWHS LP Header";
        Rollup: Codeunit "DOPSWHS Bin Content Subscriber";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        CreateBuiltLP(Pallet, 'PALLET-EUR', 0);
        CreateBuiltLP(Carton1, 'CARTON-M', 0); CreateBuiltLP(Carton2, 'CARTON-M', 0);
        CreateBuiltLP(Tote1, 'TOTE-A', 25); CreateBuiltLP(Tote2, 'TOTE-A', 25); CreateBuiltLP(Tote3, 'TOTE-A', 25); CreateBuiltLP(Tote4, 'TOTE-A', 25);
        Nest(Carton1, Pallet); Nest(Carton2, Pallet);
        Nest(Tote1, Carton1); Nest(Tote2, Carton1); Nest(Tote3, Carton2); Nest(Tote4, Carton2);
        Assert.AreEqual(100, Rollup.CalculateNestedLPQuantity('BLUE', 'X', 'ITEMY'), 'Scenario D: leaf quantities should not multiply by container count.');
    end;

    local procedure CreateBuiltLP(var LP: Record "DOPSWHS LP Header"; TemplateCode: Code[20]; Qty: Decimal)
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        LPMgt.Build(TemplateCode, 'BLUE', 'X', LP);
        if Qty <> 0 then
            LPMgt.AddLine(LP, 'ITEMY', 'PCS', Qty, '', '', 0D);
        LPMgt.Stop(LP, false);
    end;

    local procedure Nest(var ChildLP: Record "DOPSWHS LP Header"; var ParentLP: Record "DOPSWHS LP Header")
    var
        NestManager: Codeunit "DOPSWHS LP Nest Manager";
        LPLine: Record "DOPSWHS LP Line";
    begin
        NestManager.Nest(ChildLP, ParentLP);
        LPLine.Init();
        LPLine."LP No." := ParentLP."No.";
        LPLine.Validate("Child LP No.", ChildLP."No.");
        LPLine.Insert(true);
    end;

    local procedure CreateLooseQty(Qty: Decimal)
    var
        BinContent: Record "Bin Content";
    begin
        if not BinContent.Get('BLUE', 'X', 'ITEMY', '', 'PCS') then begin
            BinContent.Init();
            BinContent."Location Code" := 'BLUE';
            BinContent."Bin Code" := 'X';
            BinContent."Item No." := 'ITEMY';
            BinContent."Unit of Measure Code" := 'PCS';
            BinContent.Insert(true);
        end;
        BinContent.Quantity := Qty;
        BinContent.Modify(true);
    end;

    local procedure PostWarehouseEntryAgainstLoose(Qty: Decimal)
    var
        WhseEntry: Record "Warehouse Entry";
    begin
        WhseEntry.Init();
        WhseEntry."Entry No." := 72097;
        WhseEntry."Location Code" := 'BLUE';
        WhseEntry."Bin Code" := 'X';
        WhseEntry."Item No." := 'ITEMY';
        WhseEntry.Quantity := -Qty;
        WhseEntry.Insert(true);
    end;

    local procedure Seed()
    var
        Helper: Codeunit "DOPSWHS Test Helper";
        SetupWizard: Codeunit "DOPSWHS Setup Wizard";
        Setup: Record "DOPSWHS Setup";
    begin
        Helper.ResetSetup();
        SeedNoSeries('LP', 'LP03001'); SeedNoSeries('SSCC', '5000000001');
        Setup := Helper.EnsureSetup();
        Setup."LP No. Series" := 'LP'; Setup."SSCC No. Series" := 'SSCC'; Setup."Max LP Nesting Depth" := 3; Setup.Modify(true);
        SeedItem('ITEMY', 'PCS');
        SeedLocationBin('BLUE', 'X');
        SetupWizard.SeedDefaultLPTemplates();
    end;

    local procedure SeedNoSeries(Code: Code[20]; StartNo: Code[20])
    var
        NoSeries: Record "No. Series"; NoSeriesLine: Record "No. Series Line";
    begin
        if not NoSeries.Get(Code) then begin NoSeries.Init(); NoSeries.Code := Code; NoSeries.Insert(true); end;
        if not NoSeriesLine.Get(Code, 10000) then begin NoSeriesLine.Init(); NoSeriesLine."Series Code" := Code; NoSeriesLine."Line No." := 10000; NoSeriesLine."Starting No." := StartNo; NoSeriesLine."Ending No." := IncStr(StartNo); NoSeriesLine.Insert(true); end;
    end;

    local procedure SeedItem(ItemNo: Code[20]; UoM: Code[10])
    var
        Item: Record Item;
    begin
        if not Item.Get(ItemNo) then begin Item.Init(); Item."No." := ItemNo; Item.Description := ItemNo; Item."Base Unit of Measure" := UoM; Item.Insert(true); end;
    end;

    local procedure SeedLocationBin(LocationCode: Code[10]; BinCode: Code[20])
    var
        Location: Record Location; Bin: Record Bin;
    begin
        if not Location.Get(LocationCode) then begin Location.Init(); Location.Code := LocationCode; Location.Insert(true); end;
        if not Bin.Get(LocationCode, BinCode) then begin Bin.Init(); Bin."Location Code" := LocationCode; Bin.Code := BinCode; Bin.Insert(true); end;
    end;
}
