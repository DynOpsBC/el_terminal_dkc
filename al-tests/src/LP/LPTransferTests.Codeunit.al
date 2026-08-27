codeunit 72114 "DOPSWHS LP Transfer Tests"
{
    Subtype = Test;

    [Test]
    procedure FullTransferMovesAllLinesToTarget()
    var
        SourceLP: Record "DOPSWHS LP Header";
        TargetLP: Record "DOPSWHS LP Header";
        Line: Record "DOPSWHS LP Line";
        Lines: List of [Integer];
        QtyByLine: Dictionary of [Integer, Decimal];
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildLPWithLine(SourceLP, 10, Line);
        BuildEmptyBuiltLP(TargetLP);
        Lines.Add(Line."Line No.");
        LPMgt.Transfer(SourceLP, TargetLP, Lines, QtyByLine);
        Assert.AreEqual(0, CountLines(SourceLP."No."), 'Source should have no remaining lines.');
        Assert.AreEqual(10, GetLPQty(TargetLP."No."), 'Target should receive all quantity.');
    end;

    [Test]
    procedure PartialLineTransferMovesSubsetOfQuantity()
    var
        SourceLP: Record "DOPSWHS LP Header";
        TargetLP: Record "DOPSWHS LP Header";
        Line: Record "DOPSWHS LP Line";
        Lines: List of [Integer];
        QtyByLine: Dictionary of [Integer, Decimal];
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildLPWithLine(SourceLP, 10, Line);
        BuildEmptyBuiltLP(TargetLP);
        Lines.Add(Line."Line No.");
        QtyByLine.Add(Line."Line No.", 4);
        LPMgt.Transfer(SourceLP, TargetLP, Lines, QtyByLine);
        Assert.AreEqual(6, GetLPQty(SourceLP."No."), 'Source should keep remaining quantity.');
        Assert.AreEqual(4, GetLPQty(TargetLP."No."), 'Target should receive selected quantity.');
    end;

    [Test]
    procedure TransferCanCreateNewTargetLP()
    var
        SourceLP: Record "DOPSWHS LP Header";
        TargetLP: Record "DOPSWHS LP Header";
        Line: Record "DOPSWHS LP Line";
        Lines: List of [Integer];
        QtyByLine: Dictionary of [Integer, Decimal];
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildLPWithLine(SourceLP, 5, Line);
        LPMgt.Build('CARTON-S', SourceLP."Location Code", SourceLP."Bin Code", TargetLP);
        LPMgt.Stop(TargetLP, false);
        Lines.Add(Line."Line No.");
        LPMgt.Transfer(SourceLP, TargetLP, Lines, QtyByLine);
        Assert.AreNotEqual('', TargetLP."No.", 'Target LP should be created.');
        Assert.AreEqual(5, GetLPQty(TargetLP."No."), 'New target LP should receive transferred quantity.');
    end;

    [Test]
    procedure TransferAcceptsOpenEmptyTargetLP()
    var
        SourceLP: Record "DOPSWHS LP Header";
        TargetLP: Record "DOPSWHS LP Header";
        Line: Record "DOPSWHS LP Line";
        Lines: List of [Integer];
        QtyByLine: Dictionary of [Integer, Decimal];
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildLPWithLine(SourceLP, 5, Line);
        LPMgt.Build('CARTON-S', SourceLP."Location Code", SourceLP."Bin Code", TargetLP);
        Lines.Add(Line."Line No.");

        LPMgt.Transfer(SourceLP, TargetLP, Lines, QtyByLine);

        Assert.AreEqual(TargetLP.Status::Open, TargetLP.Status, 'The operator may transfer into a newly created open target LP.');
        Assert.AreEqual(5, GetLPQty(TargetLP."No."), 'The open target LP should receive the source contents.');
    end;

    [Test]
    procedure TransferAcceptsOpenSourceLP()
    var
        SourceLP: Record "DOPSWHS LP Header";
        TargetLP: Record "DOPSWHS LP Header";
        SourceLine: Record "DOPSWHS LP Line";
        Lines: List of [Integer];
        QtyByLine: Dictionary of [Integer, Decimal];
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        LPMgt.Build('CARTON-S', 'BLUE', 'PICK', SourceLP);
        LPMgt.AddLine(SourceLP, 'ITEMY', 'PCS', 5, '', '', 0D);
        SourceLine.SetRange("LP No.", SourceLP."No.");
        SourceLine.FindFirst();
        BuildEmptyBuiltLP(TargetLP);
        Lines.Add(SourceLine."Line No.");

        LPMgt.Transfer(SourceLP, TargetLP, Lines, QtyByLine);

        Assert.AreEqual(SourceLP.Status::Open, SourceLP.Status, 'An open source LP should remain open after its contents are transferred.');
        Assert.AreEqual(0, CountLines(SourceLP."No."), 'The open source LP should be empty after a full transfer.');
        Assert.AreEqual(5, GetLPQty(TargetLP."No."), 'The target LP should receive the open source LP contents.');
    end;

    [Test]
    procedure EmptyBuiltLpMoveUpdatesHeaderBin()
    var
        LP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildEmptyBuiltLP(LP);

        LPMgt.MoveToBin(LP, 'STAGE', 'USER1');

        LP.Get(LP."No.");
        Assert.AreEqual('STAGE', LP."Bin Code", 'An empty LP move must update its bin inside the server action.');
    end;

    [Test]
    procedure LpMoveRequiresAuthenticatedOperator()
    var
        LP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildEmptyBuiltLP(LP);

        asserterror LPMgt.MoveToBin(LP, 'STAGE', '');

        Assert.ExpectedError('Operator user ID is required');
        LP.Get(LP."No.");
        Assert.AreEqual('PICK', LP."Bin Code", 'A rejected move must leave the LP bin unchanged.');
    end;

    [Test]
    procedure AssignedLpCannotBeMovedAdHoc()
    var
        LP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildEmptyBuiltLP(LP);
        LPMgt.Assign(LP, Enum::"DOPSWHS Assigned Doc Type"::WhsePick, 'PICK-1');

        asserterror LPMgt.MoveToBin(LP, 'STAGE', 'USER1');

        Assert.ExpectedError('cannot be moved while its status is Assigned');
        LP.Get(LP."No.");
        Assert.AreEqual('PICK', LP."Bin Code", 'A rejected assigned-LP move must leave the bin unchanged.');
    end;

    local procedure BuildLPWithLine(var LP: Record "DOPSWHS LP Header"; Qty: Decimal; var LPLine: Record "DOPSWHS LP Line")
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        LPMgt.Build('CARTON-S', 'BLUE', 'PICK', LP);
        LPMgt.AddLine(LP, 'ITEMY', 'PCS', Qty, '', '', 0D);
        LPLine.SetRange("LP No.", LP."No."); LPLine.FindFirst();
        LPMgt.Stop(LP, false);
    end;

    local procedure BuildEmptyBuiltLP(var LP: Record "DOPSWHS LP Header")
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        LPMgt.Build('CARTON-S', 'BLUE', 'PICK', LP);
        LPMgt.Stop(LP, false);
    end;

    local procedure GetLPQty(LPNo: Code[20]): Decimal
    var
        LPLine: Record "DOPSWHS LP Line";
    begin
        LPLine.SetRange("LP No.", LPNo);
        if LPLine.FindFirst() then
            exit(LPLine.Quantity);
        exit(0);
    end;

    local procedure CountLines(LPNo: Code[20]): Integer
    var
        LPLine: Record "DOPSWHS LP Line";
    begin
        LPLine.SetRange("LP No.", LPNo);
        exit(LPLine.Count());
    end;

    local procedure Seed()
    var
        Helper: Codeunit "DOPSWHS Test Helper";
        SetupWizard: Codeunit "DOPSWHS Setup Wizard";
        Setup: Record "DOPSWHS Setup";
    begin
        Helper.ResetSetup();
        SeedNoSeries('LP', 'LP04001'); SeedNoSeries('SSCC', '6000000001');
        Setup := Helper.EnsureSetup();
        Setup."LP No. Series" := 'LP'; Setup."SSCC No. Series" := 'SSCC'; Setup.Modify(true);
        SeedItem('ITEMY', 'PCS');
        SeedLocationBin('BLUE', 'PICK');
        SeedLocationBin('BLUE', 'STAGE');
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
