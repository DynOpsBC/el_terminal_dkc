codeunit 72101 "DOPSWHS Barcode Parser Tests"
{
    Subtype = Test;

    [Test] procedure Ean13HappyPath() begin SeedRules(); AssertKind('5901234123457', 'Item'); end;
    [Test] procedure Ean13WrongLength() begin SeedRules(); AssertUnknown('590123412345'); end;
    [Test] procedure Gs1Full() begin SeedRules(); AssertKind('(01)08401234567890(10)LOT123(17)260101(21)SN42', 'Item'); end;
    [Test] procedure Gs1GtinOnly() begin SeedRules(); AssertKind('(01)08401234567890', 'Item'); end;
    [Test] procedure Gs1GtinLot() begin SeedRules(); AssertKind('(01)08401234567890(10)LOT123', 'Item'); end;
    [Test] procedure Sscc18Valid() begin SeedRules(); AssertKind('(00)123456789012345678', 'LP'); end;
    [Test] procedure BinPrefixValid() begin SeedRules(); AssertKind('B-A01-01', 'Bin'); end;
    [Test] procedure LpTemplateValid() begin SeedRules(); AssertKind('TPL-CARTON-S', 'LpTemplate'); end;
    [Test] procedure EmptyInput() begin SeedRules(); AssertUnknown(''); end;
    [Test] procedure GarbageInput() begin SeedRules(); AssertUnknown('not-a-barcode'); end;
    [Test] procedure RegexSpecialCharsDoNotBreakGs1() begin SeedRules(); AssertKind('(01)08401234567890(10)LOT-1(21)SN-42', 'Item'); end;
    [Test] procedure RuleOrderFirstMatchWins() begin SeedRules(); InsertRule('FIRST-EAN', 'EAN13', '^\d{13}$', 'Bin', 1, true); AssertKind('5901234123457', 'Bin'); end;
    [Test] procedure InactiveRuleSkipped() begin SeedRules(); InsertRule('FIRST-EAN', 'EAN13', '^\d{13}$', 'Bin', 1, false); AssertKind('5901234123457', 'Item'); end;
    [Test] procedure SsccRejectsShortValue() begin SeedRules(); AssertUnknown('(00)123'); end;
    [Test] procedure LpTemplateRejectsEmptyCode() begin SeedRules(); AssertUnknown('TPL-'); end;

    local procedure AssertKind(Raw: Text; ExpectedKind: Text)
    var
        Parser: Codeunit "DOPSWHS Barcode Parser";
        Result: JsonObject;
        Token: JsonToken;
        Assert: Codeunit "Library Assert";
        Parsed: Boolean;
    begin
        Parsed := Parser.ParseBarcode(Raw, Result);
        Assert.IsTrue(Parsed, 'Expected parser to match input.');
        Result.Get('kind', Token);
        Assert.AreEqual(ExpectedKind, Token.AsValue().AsText(), 'Unexpected barcode kind.');
    end;

    local procedure AssertUnknown(Raw: Text)
    var
        Parser: Codeunit "DOPSWHS Barcode Parser";
        Result: JsonObject;
        Assert: Codeunit "Library Assert";
        Parsed: Boolean;
    begin
        Parsed := Parser.ParseBarcode(Raw, Result);
        Assert.IsFalse(Parsed, 'Expected parser to reject input.');
    end;

    local procedure SeedRules()
    var
        Rule: Record "DOPSWHS Barcode Rule";
        SetupWizard: Codeunit "DOPSWHS Setup Wizard";
    begin
        Rule.DeleteAll();
        SetupWizard.SeedSprint1Defaults();
    end;

    local procedure InsertRule(Code: Code[30]; Symbology: Code[20]; Regex: Text[250]; MapsToName: Text; SortOrder: Integer; Active: Boolean)
    var
        Rule: Record "DOPSWHS Barcode Rule";
    begin
        Rule.Init();
        Rule."Code" := Code;
        Rule.Description := Code;
        Rule.Symbology := Symbology;
        Rule.Regex := Regex;
        case MapsToName of
            'Bin':
                Rule."Maps To" := Rule."Maps To"::Bin;
            else
                Rule."Maps To" := Rule."Maps To"::Item;
        end;
        Rule."Order" := SortOrder;
        Rule.Active := Active;
        Rule.Insert(true);
    end;
}
