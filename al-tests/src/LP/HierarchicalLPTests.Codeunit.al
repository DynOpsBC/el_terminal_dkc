codeunit 72143 "DOPSWHS Hierarchy LP Tests"
{
    Subtype = Test;

    [Test]
    procedure FeatureIsDisabledByDefault()
    var
        Helper: Codeunit "DOPSWHS Test Helper";
        HierarchyMgt: Codeunit "DOPSWHS Hierarchical LP Mgt";
        Assert: Codeunit "Library Assert";
    begin
        Helper.ResetSetup();
        Helper.EnsureSetup();

        asserterror HierarchyMgt.SeedDkcTemplates();
        Assert.ExpectedError('not enabled');
    end;

    [Test]
    procedure ProductBoxPalletUsesHeaderParentLinks()
    var
        ProductLP: Record "DOPSWHS LP Header";
        BoxLP: Record "DOPSWHS LP Header";
        PalletLP: Record "DOPSWHS LP Header";
        HierarchyMgt: Codeunit "DOPSWHS Hierarchical LP Mgt";
        Rollup: Codeunit "DOPSWHS Bin Content Subscriber";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildProductLP(ProductLP);
        BuildContainerLP(BoxLP, 'DKC-BOX');
        BuildContainerLP(PalletLP, 'DKC-PALLET');

        HierarchyMgt.AttachChild(BoxLP, ProductLP."No.");
        HierarchyMgt.AttachChild(PalletLP, BoxLP."No.");

        ProductLP.Get(ProductLP."No.");
        BoxLP.Get(BoxLP."No.");
        Assert.AreEqual(BoxLP."No.", ProductLP."Parent LP No.", 'Product LP must point to its box through the header.');
        Assert.AreEqual(PalletLP."No.", BoxLP."Parent LP No.", 'Box LP must point to its pallet through the header.');
        Assert.AreEqual(1, Rollup.CalculateNestedLPQuantity('DKCTEST', 'HIER', 'DKC-TEST'), 'Canonical header links must roll product quantity up once.');
    end;

    [Test]
    procedure PalletRejectsDirectProductLP()
    var
        ProductLP: Record "DOPSWHS LP Header";
        PalletLP: Record "DOPSWHS LP Header";
        HierarchyMgt: Codeunit "DOPSWHS Hierarchical LP Mgt";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildProductLP(ProductLP);
        BuildContainerLP(PalletLP, 'DKC-PALLET');

        asserterror HierarchyMgt.AttachChild(PalletLP, ProductLP."No.");
        Assert.ExpectedError('can contain only boxes');
    end;

    local procedure Seed()
    var
        Helper: Codeunit "DOPSWHS Test Helper";
        Setup: Record "DOPSWHS Setup";
        HierarchyMgt: Codeunit "DOPSWHS Hierarchical LP Mgt";
        Location: Record Location;
        Bin: Record Bin;
        Item: Record Item;
    begin
        Helper.ResetSetup();
        SeedNoSeries('HIER-LP', 'HLP0000001', 'HLP9999999');
        SeedNoSeries('HIER-SSCC', '4000000001', '4999999999');
        Setup := Helper.EnsureSetup();
        Setup."LP No. Series" := 'HIER-LP';
        Setup."SSCC No. Series" := 'HIER-SSCC';
        Setup."GS1 Company Prefix" := '1234567';
        Setup."Max LP Nesting Depth" := 3;
        Setup.Validate("Hierarchical LP Enabled", true);
        Setup.Modify(true);
        HierarchyMgt.SeedDkcTemplates();

        if not Location.Get('DKCTEST') then begin
            Location.Init();
            Location.Code := 'DKCTEST';
            Location.Insert(true);
        end;
        if not Bin.Get('DKCTEST', 'HIER') then begin
            Bin.Init();
            Bin."Location Code" := 'DKCTEST';
            Bin.Code := 'HIER';
            Bin.Insert(true);
        end;
        if not Item.Get('DKC-TEST') then begin
            Item.Init();
            Item."No." := 'DKC-TEST';
            Item.Description := 'DKC hierarchy test item';
            Item."Base Unit of Measure" := 'PCS';
            Item."Net Weight" := 1;
            Item.Insert(true);
        end;
    end;

    local procedure BuildProductLP(var LP: Record "DOPSWHS LP Header")
    var
        LPLine: Record "DOPSWHS LP Line";
        LPMgt: Codeunit "DOPSWHS LP Management";
        HierarchyMgt: Codeunit "DOPSWHS Hierarchical LP Mgt";
    begin
        LPMgt.Build('DKC-ITEM', 'DKCTEST', 'HIER', LP);
        LPLine.Init();
        LPLine."LP No." := LP."No.";
        LPLine.Validate("Item No.", 'DKC-TEST');
        LPLine."Unit of Measure" := 'PCS';
        LPLine.Validate(Quantity, 1);
        LPLine."Lot No." := 'LOT-001';
        LPLine.Insert(true);
        HierarchyMgt.CompleteNode(LP);
    end;

    local procedure BuildContainerLP(var LP: Record "DOPSWHS LP Header"; TemplateCode: Code[20])
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
        HierarchyMgt: Codeunit "DOPSWHS Hierarchical LP Mgt";
    begin
        LPMgt.Build(TemplateCode, 'DKCTEST', 'HIER', LP);
        HierarchyMgt.CompleteNode(LP);
    end;

    local procedure SeedNoSeries(Code: Code[20]; StartNo: Code[20]; EndNo: Code[20])
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        if not NoSeries.Get(Code) then begin
            NoSeries.Init();
            NoSeries.Code := Code;
            NoSeries.Insert(true);
        end;
        if not NoSeriesLine.Get(Code, 10000) then begin
            NoSeriesLine.Init();
            NoSeriesLine."Series Code" := Code;
            NoSeriesLine."Line No." := 10000;
            NoSeriesLine."Starting No." := StartNo;
            NoSeriesLine."Ending No." := EndNo;
            NoSeriesLine.Insert(true);
        end;
    end;
}
