codeunit 72115 "DOPSWHS SSCC Generator Tests"
{
    Subtype = Test;

    [Test]
    procedure GenerateOneHundredDistinctSSCCs()
    var
        Generator: Codeunit "DOPSWHS SSCC Generator";
        Seen: Dictionary of [Code[18], Boolean];
        SSCC: Code[18];
        I: Integer;
        Assert: Codeunit "Library Assert";
    begin
        Seed('1234567');
        for I := 1 to 100 do begin
            SSCC := Generator.Generate();
            Assert.IsFalse(Seen.ContainsKey(SSCC), 'SSCC should be distinct.');
            Seen.Add(SSCC, true);
        end;
        Assert.AreEqual(100, Seen.Count(), 'Expected 100 generated SSCC values.');
    end;

    [Test]
    procedure CalculateCheckDigitForKnownInput()
    var
        Generator: Codeunit "DOPSWHS SSCC Generator";
        Assert: Codeunit "Library Assert";
    begin
        Assert.AreEqual('5', Format(Generator.CalculateCheckDigit('12345678901234567')), 'Unexpected mod-10 check digit.');
    end;

    [Test]
    procedure EmptyCompanyPrefixUsesExtensionPrefix()
    var
        Generator: Codeunit "DOPSWHS SSCC Generator";
        SSCC: Code[18];
        Assert: Codeunit "Library Assert";
    begin
        Seed('');
        SSCC := Generator.Generate();
        Assert.AreEqual('09999999', CopyStr(SSCC, 1, 8), 'Empty GS1 prefix should use extension filler prefix.');
    end;

    local procedure Seed(GS1Prefix: Code[12])
    var
        Helper: Codeunit "DOPSWHS Test Helper";
        Setup: Record "DOPSWHS Setup";
    begin
        Helper.ResetSetup();
        SeedNoSeries('SSCC', '4000000001', '4000000999');
        Setup := Helper.EnsureSetup();
        Setup."LP No. Series" := 'LP';
        Setup."SSCC No. Series" := 'SSCC';
        Setup."GS1 Company Prefix" := GS1Prefix;
        Setup.Modify(true);
    end;

    local procedure SeedNoSeries(Code: Code[20]; StartNo: Code[20]; EndNo: Code[20])
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        if not NoSeries.Get(Code) then begin NoSeries.Init(); NoSeries.Code := Code; NoSeries.Insert(true); end;
        if NoSeriesLine.Get(Code, 10000) then
            NoSeriesLine.Delete(true);
        NoSeriesLine.Init();
        NoSeriesLine."Series Code" := Code;
        NoSeriesLine."Line No." := 10000;
        NoSeriesLine."Starting No." := StartNo;
        NoSeriesLine."Ending No." := EndNo;
        NoSeriesLine.Insert(true);
    end;
}
