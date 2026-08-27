codeunit 72036 "DOPSWHS Barcode Parser"
{
    Access = Public;

    procedure ParseBarcode(Raw: Text; var Result: JsonObject): Boolean
    var
        Rule: Record "DOPSWHS Barcode Rule";
    begin
        Clear(Result);
        if Raw = '' then
            exit(false);

        Rule.SetRange(Active, true);
        Rule.SetCurrentKey(Active, "Order");
        if Rule.FindSet() then
            repeat
                if TryApplyRule(Raw, Rule, Result) then
                    exit(true);
            until Rule.Next() = 0;

        Result.Add('kind', 'Unknown');
        Result.Add('fields', BuildFields());
        exit(false);
    end;

    local procedure TryApplyRule(Raw: Text; Rule: Record "DOPSWHS Barcode Rule"; var Result: JsonObject): Boolean
    var
        Fields: JsonObject;
        GS1Parser: Codeunit "DOPSWHS GS1 AI Parser";
        Value: Text;
    begin
        if Rule.Regex = '^\d{13}$' then
            if IsAllDigits(Raw) and (StrLen(Raw) = 13) then begin
                Fields.Add('itemReference', Raw);
                Result.Add('kind', Format(Rule."Maps To"));
                Result.Add('fields', Fields);
                exit(true);
            end else
                exit(false);

        Clear(Fields);
        case Rule."Code" of
            'EAN13-ITEM':
                if IsAllDigits(Raw) and (StrLen(Raw) = 13) then
                    Fields.Add('itemReference', Raw)
                else
                    exit(false);
            'GS1-128-FULL':
                if not GS1Parser.Parse(Raw, Fields) then
                    exit(false);
            'SSCC-18':
                begin
                    if not ((CopyStr(Raw, 1, 4) = '(00)') and IsAllDigits(CopyStr(Raw, 5)) and (StrLen(CopyStr(Raw, 5)) = 18)) then
                        exit(false);
                    Fields.Add('sscc', CopyStr(Raw, 5));
                end;
            'BIN-PREFIX':
                begin
                    if CopyStr(Raw, 1, 2) <> 'B-' then
                        exit(false);
                    Value := CopyStr(Raw, 3);
                    if Value = '' then
                        exit(false);
                    Fields.Add('bin', Value);
                end;
            'LP-TEMPLATE':
                begin
                    if CopyStr(Raw, 1, 4) <> 'TPL-' then
                        exit(false);
                    Value := CopyStr(Raw, 5);
                    if Value = '' then
                        exit(false);
                    Fields.Add('tpl', Value);
                end;
            else
                exit(false);
        end;

        Result.Add('kind', Format(Rule."Maps To"));
        Result.Add('fields', Fields);
        exit(true);
    end;

    local procedure BuildFields(): JsonObject
    var
        Fields: JsonObject;
    begin
        exit(Fields);
    end;

    local procedure IsAllDigits(Value: Text): Boolean
    var
        Index: Integer;
        Character: Text[1];
    begin
        if Value = '' then
            exit(false);

        for Index := 1 to StrLen(Value) do begin
            Character := CopyStr(Value, Index, 1);
            if StrPos('0123456789', Character) = 0 then
                exit(false);
        end;
        exit(true);
    end;
}
