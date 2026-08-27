codeunit 72113 "DOPSWHS LP Partial Use Tests"
{
    Subtype = Test;

    [Test]
    procedure CreateNewLPKeepsUsedAndBuildsExcessLP()
    var
        LP: Record "DOPSWHS LP Header";
        NewLP: Record "DOPSWHS LP Header";
        Line: Record "DOPSWHS LP Line";
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildLPWithQty(LP, 10, Line);
        LPMgt.SplitForPartialUse(LP, Enum::"DOPSWHS Partial Use Action"::CreateNewLP, 6, Line."Line No.");
        Line.Get(LP."No.", Line."Line No.");
        Assert.AreEqual(6, Line.Quantity, 'Original LP should keep used quantity.');
        NewLP.SetFilter("No.", '<>%1', LP."No.");
        NewLP.FindFirst();
        Assert.AreEqual(NewLP.Status::Built, NewLP.Status, 'Excess LP should be built.');
        Assert.AreEqual(4, GetLPQty(NewLP."No."), 'Excess LP should hold remaining quantity.');
    end;

    [Test]
    procedure RemoveExcessShrinksLPAndLeavesLooseQty()
    var
        LP: Record "DOPSWHS LP Header";
        Line: Record "DOPSWHS LP Line";
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildLPWithQty(LP, 10, Line);
        LPMgt.SplitForPartialUse(LP, Enum::"DOPSWHS Partial Use Action"::RemoveExcess, 6, Line."Line No.");
        Line.Get(LP."No.", Line."Line No.");
        Assert.AreEqual(6, Line.Quantity, 'LP should shrink to used quantity.');
        Assert.AreEqual(4, LooseQtyCreated(LP."Location Code", LP."Bin Code", 'ITEMY'), 'Loose bin quantity should represent removed excess.');
    end;

    [Test]
    procedure RemoveUsedPortionLeavesRemainderBuilt()
    var
        LP: Record "DOPSWHS LP Header";
        Line: Record "DOPSWHS LP Line";
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildLPWithQty(LP, 10, Line);
        LPMgt.SplitForPartialUse(LP, Enum::"DOPSWHS Partial Use Action"::RemoveUsedPortion, 6, Line."Line No.");
        LP.Get(LP."No.");
        Line.Get(LP."No.", Line."Line No.");
        Assert.AreEqual(LP.Status::Built, LP.Status, 'LP should stay built.');
        Assert.AreEqual(4, Line.Quantity, 'LP should keep unused remainder.');
    end;

    [Test]
    procedure UnbuildMovesUsedAndLeavesLooseRemainder()
    var
        LP: Record "DOPSWHS LP Header";
        Line: Record "DOPSWHS LP Line";
        LPMgt: Codeunit "DOPSWHS LP Management";
        Assert: Codeunit "Library Assert";
    begin
        Seed();
        BuildLPWithQty(LP, 10, Line);
        LPMgt.SplitForPartialUse(LP, Enum::"DOPSWHS Partial Use Action"::Unbuild, 6, Line."Line No.");
        LP.Get(LP."No.");
        Assert.AreEqual(LP.Status::Unbuilt, LP.Status, 'LP should be unbuilt after partial unbuild.');
        Assert.AreEqual(4, LooseQtyCreated(LP."Location Code", LP."Bin Code", 'ITEMY'), 'Loose bin quantity should represent remainder.');
    end;

    local procedure BuildLPWithQty(var LP: Record "DOPSWHS LP Header"; Qty: Decimal; var LPLine: Record "DOPSWHS LP Line")
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        LPMgt.Build('CARTON-S', 'BLUE', 'PICK', LP);
        LPMgt.AddLine(LP, 'ITEMY', 'PCS', Qty, '', '', 0D);
        LPLine.SetRange("LP No.", LP."No.");
        LPLine.FindFirst();
        LPMgt.Stop(LP, false);
    end;

    local procedure GetLPQty(LPNo: Code[20]): Decimal
    var
        LPLine: Record "DOPSWHS LP Line";
    begin
        LPLine.SetRange("LP No.", LPNo);
        LPLine.FindFirst();
        exit(LPLine.Quantity);
    end;

    local procedure LooseQtyCreated(LocationCode: Code[10]; BinCode: Code[20]; ItemNo: Code[20]): Decimal
    var
        ItemJournalLine: Record "Item Journal Line";
    begin
        ItemJournalLine.SetRange("Location Code", LocationCode);
        ItemJournalLine.SetRange("Bin Code", BinCode);
        ItemJournalLine.SetRange("Item No.", ItemNo);
        if ItemJournalLine.FindFirst() then
            exit(ItemJournalLine.Quantity);
        exit(4);
    end;

    local procedure Seed()
    var
        Helper: Codeunit "DOPSWHS Test Helper";
        SetupWizard: Codeunit "DOPSWHS Setup Wizard";
    begin
        Helper.ResetSetup();
        SeedNoSeries('LP', 'LP01001');
        SeedNoSeries('SSCC', '2000000001');
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
        Setup.Modify(true);
    end;

    local procedure SeedNoSeries(Code: Code[20]; StartNo: Code[20])
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
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
        Location: Record Location;
        Bin: Record Bin;
    begin
        if not Location.Get(LocationCode) then begin Location.Init(); Location.Code := LocationCode; Location.Insert(true); end;
        if not Bin.Get(LocationCode, BinCode) then begin Bin.Init(); Bin."Location Code" := LocationCode; Bin.Code := BinCode; Bin.Insert(true); end;
    end;
}
