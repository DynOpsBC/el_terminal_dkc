codeunit 72111 "DOPSWHS LP Build Tests"
{
    Subtype = Test;

    [Test]
    procedure BuildCreatesOpenLPWithNoSeries()
    var
        LP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        LPMgt.Build('CARTON-S', 'BLUE', 'PICK', LP);
        Assert.AreNotEqual('', LP."No.", 'LP number should be assigned from no. series.');
        Assert.AreEqual(LP.Status::Open, LP.Status, 'New LP should be open.');
    end;

    [Test]
    procedure StopTransitionsOpenToBuilt()
    var
        LP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildOpenLP(LP);
        LPMgt.Stop(LP, false);
        Assert.AreEqual(LP.Status::Built, LP.Status, 'Stop should make LP built.');
    end;

    [Test]
    procedure ConsecutiveStopsCreateDifferentSsccValues()
    var
        FirstLP: Record "DOPSWHS LP Header";
        SecondLP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildOpenLP(FirstLP);
        BuildOpenLP(SecondLP);

        LPMgt.Stop(FirstLP, false);
        LPMgt.Stop(SecondLP, false);

        Assert.AreNotEqual('', FirstLP.SSCC, 'The first LP must receive an SSCC.');
        Assert.AreNotEqual('', SecondLP.SSCC, 'The second LP must receive an SSCC.');
        Assert.AreNotEqual(FirstLP.SSCC, SecondLP.SSCC, 'Consecutive LPs must never share an SSCC.');
    end;

    [Test]
    procedure StopCreatesMissingSsccSeriesOnDemand()
    var
        LP: Record "DOPSWHS LP Header";
        Setup: Record "DOPSWHS Setup";
        NoSeries: Record "No. Series";
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        Setup.Get('');
        Setup."SSCC No. Series" := '';
        Setup.Modify(true);
        if NoSeries.Get('AWMS-SSCC') then
            NoSeries.Delete(true);

        BuildOpenLP(LP);
        LPMgt.Stop(LP, false);

        Setup.Get('');
        Assert.AreEqual(LP.Status::Built, LP.Status, 'Stop should complete when SSCC setup was initially missing.');
        Assert.AreNotEqual('', LP.SSCC, 'Stop should generate an SSCC.');
        Assert.AreEqual('AWMS-SSCC', Setup."SSCC No. Series", 'Default SSCC series should be assigned automatically.');
    end;

    [Test]
    procedure ReopenTransitionsBuiltToOpen()
    var
        LP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildBuiltLP(LP);
        LPMgt.Reopen(LP);
        Assert.AreEqual(LP.Status::Open, LP.Status, 'Reopen should make LP open.');
    end;

    [Test]
    procedure AddLineFailsOnBuiltLP()
    var
        LP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildBuiltLP(LP);
        asserterror LPMgt.AddLine(LP, 'ITEMY', 'PCS', 1, '', '', 0D);
        Assert.ExpectedError('must be Open');
    end;

    [Test]
    procedure AssignFailsOnOpenLP()
    var
        LP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildOpenLP(LP);
        asserterror LPMgt.Assign(LP, Enum::"DOPSWHS Assigned Doc Type"::WhsePick, 'PICK-1');
        Assert.ExpectedError('must be Built');
    end;

    [Test]
    procedure StopSetsBuiltDateTime()
    var
        LP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildOpenLP(LP);
        LPMgt.Stop(LP, false);
        Assert.IsTrue(LP."Built DateTime" <> 0DT, 'Built DateTime should be populated.');
    end;

    local procedure BuildOpenLP(var LP: Record "DOPSWHS LP Header")
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        LPMgt.Build('CARTON-S', 'BLUE', 'PICK', LP);
    end;

    local procedure BuildBuiltLP(var LP: Record "DOPSWHS LP Header")
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        BuildOpenLP(LP);
        LPMgt.Stop(LP, false);
    end;

    local procedure Seed()
    var
        Helper: Codeunit "DOPSWHS Test Helper";
        SetupWizard: Codeunit "DOPSWHS Setup Wizard";
    begin
        Helper.ResetSetup();
        SeedNoSeries('LP', 'LP00001');
        SeedNoSeries('SSCC', '1000000001');
        EnsureSetup();
        SeedItem('ITEMY', 'PCS');
        SeedLocationBin('BLUE', 'PICK');
        SetupWizard.SeedDefaultLPTemplates();
    end;

    local procedure EnsureSetup()
    var
        Helper: Codeunit "DOPSWHS Test Helper";
        Setup: Record "DOPSWHS Setup";
    begin
        Setup := Helper.EnsureSetup();
        Setup."LP No. Series" := 'LP';
        Setup."SSCC No. Series" := 'SSCC';
        Setup."GS1 Company Prefix" := '1234567';
        Setup.Modify(true);
    end;

    local procedure SeedNoSeries(Code: Code[20]; StartNo: Code[20])
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        if not NoSeries.Get(Code) then begin
            NoSeries.Init();
            NoSeries.Code := Code;
            NoSeries.Description := Code;
            NoSeries.Insert(true);
        end;
        if not NoSeriesLine.Get(Code, 10000) then begin
            NoSeriesLine.Init();
            NoSeriesLine."Series Code" := Code;
            NoSeriesLine."Line No." := 10000;
            NoSeriesLine."Starting No." := StartNo;
            NoSeriesLine."Ending No." := IncStr(StartNo);
            NoSeriesLine.Insert(true);
        end;
    end;

    local procedure SeedItem(ItemNo: Code[20]; UoM: Code[10])
    var
        Item: Record Item;
    begin
        if not Item.Get(ItemNo) then begin
            Item.Init();
            Item."No." := ItemNo;
            Item.Description := ItemNo;
            Item."Base Unit of Measure" := UoM;
            Item.Insert(true);
        end;
    end;

    local procedure SeedLocationBin(LocationCode: Code[10]; BinCode: Code[20])
    var
        Location: Record Location;
        Bin: Record Bin;
    begin
        if not Location.Get(LocationCode) then begin
            Location.Init();
            Location.Code := LocationCode;
            Location.Insert(true);
        end;
        if not Bin.Get(LocationCode, BinCode) then begin
            Bin.Init();
            Bin."Location Code" := LocationCode;
            Bin.Code := BinCode;
            Bin.Insert(true);
        end;
    end;
}
