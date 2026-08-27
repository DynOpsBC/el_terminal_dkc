codeunit 72112 "DOPSWHS LP Nesting Tests"
{
    Subtype = Test;

    [Test]
    procedure NestHappyPath()
    var
        ParentLP: Record "DOPSWHS LP Header";
        ChildLP: Record "DOPSWHS LP Header";
        Nest: Codeunit "DOPSWHS LP Nest Manager";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildBuiltLP(ParentLP, 'BLUE');
        BuildBuiltLP(ChildLP, 'BLUE');
        Nest.Nest(ChildLP, ParentLP);
        ChildLP.Get(ChildLP."No.");
        Assert.AreEqual(ParentLP."No.", ChildLP."Parent LP No.", 'Child should point at parent LP.');
    end;

    [Test]
    procedure NestBeyondDepthThreeFails()
    var
        LP1: Record "DOPSWHS LP Header";
        LP2: Record "DOPSWHS LP Header";
        LP3: Record "DOPSWHS LP Header";
        LP4: Record "DOPSWHS LP Header";
        Nest: Codeunit "DOPSWHS LP Nest Manager";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildBuiltLP(LP1, 'BLUE'); BuildBuiltLP(LP2, 'BLUE'); BuildBuiltLP(LP3, 'BLUE'); BuildBuiltLP(LP4, 'BLUE');
        Nest.Nest(LP3, LP2);
        Nest.Nest(LP2, LP1);
        asserterror Nest.Nest(LP4, LP3);
        Assert.ExpectedError('depth cannot exceed');
    end;

    [Test]
    procedure NestDifferentLocationFails()
    var
        ParentLP: Record "DOPSWHS LP Header";
        ChildLP: Record "DOPSWHS LP Header";
        Nest: Codeunit "DOPSWHS LP Nest Manager";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        SeedLocationBin('RED', 'PICK');
        BuildBuiltLP(ParentLP, 'BLUE');
        BuildBuiltLP(ChildLP, 'RED');
        asserterror Nest.Nest(ChildLP, ParentLP);
        Assert.ExpectedError('same location');
    end;

    [Test]
    procedure NestOpenChildFails()
    var
        ParentLP: Record "DOPSWHS LP Header";
        ChildLP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
        Nest: Codeunit "DOPSWHS LP Nest Manager";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildBuiltLP(ParentLP, 'BLUE');
        LPMgt.Build('CARTON-S', 'BLUE', 'PICK', ChildLP);
        asserterror Nest.Nest(ChildLP, ParentLP);
        Assert.ExpectedError('Open or assigned');
    end;

    [Test]
    procedure CyclicReferenceFails()
    var
        GrandParentLP: Record "DOPSWHS LP Header";
        ParentLP: Record "DOPSWHS LP Header";
        ChildLP: Record "DOPSWHS LP Header";
        Nest: Codeunit "DOPSWHS LP Nest Manager";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildBuiltLP(GrandParentLP, 'BLUE'); BuildBuiltLP(ParentLP, 'BLUE'); BuildBuiltLP(ChildLP, 'BLUE');
        Nest.Nest(ParentLP, GrandParentLP);
        Nest.Nest(ChildLP, ParentLP);
        asserterror Nest.Nest(GrandParentLP, ChildLP);
        Assert.ExpectedError('cycle');
    end;

    local procedure BuildBuiltLP(var LP: Record "DOPSWHS LP Header"; LocationCode: Code[10])
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        LPMgt.Build('CARTON-S', LocationCode, 'PICK', LP);
        LPMgt.Stop(LP, false);
    end;

    local procedure Seed()
    var
        Helper: Codeunit "DOPSWHS Test Helper";
        SetupWizard: Codeunit "DOPSWHS Setup Wizard";
        Setup: Record "DOPSWHS Setup";
    begin
        Helper.ResetSetup();
        SeedNoSeries('LP', 'LP02001'); SeedNoSeries('SSCC', '3000000001');
        Setup := Helper.EnsureSetup();
        Setup."LP No. Series" := 'LP'; Setup."SSCC No. Series" := 'SSCC'; Setup."Max LP Nesting Depth" := 3; Setup.Modify(true);
        SeedLocationBin('BLUE', 'PICK');
        SetupWizard.SeedDefaultLPTemplates();
    end;

    local procedure SeedNoSeries(Code: Code[20]; StartNo: Code[20])
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        if not NoSeries.Get(Code) then begin NoSeries.Init(); NoSeries.Code := Code; NoSeries.Insert(true); end;
        if not NoSeriesLine.Get(Code, 10000) then begin NoSeriesLine.Init(); NoSeriesLine."Series Code" := Code; NoSeriesLine."Line No." := 10000; NoSeriesLine."Starting No." := StartNo; NoSeriesLine."Ending No." := IncStr(StartNo); NoSeriesLine.Insert(true); end;
    end;

    local procedure SeedLocationBin(LocationCode: Code[10]; BinCode: Code[20])
    var
        Location: Record Location;
        Bin: Record Bin;
    begin
        if not Location.Get(LocationCode) then begin Location.Init(); Location.Code := LocationCode; Location.Insert(true); end;
        if not Bin.Get(LocationCode, BinCode) then begin Bin.Init(); Bin."Location Code" := LocationCode; Bin.Code := BinCode; Bin.Insert(true); end;
    end;
}
