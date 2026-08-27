codeunit 72037 "DOPSWHS GS1 AI Parser"
{
    Access = Public;

    procedure Parse(Raw: Text; var Fields: JsonObject): Boolean
    var
        Position: Integer;
        AI: Text[2];
        Value: Text;
    begin
        Position := 1;
        while Position <= StrLen(Raw) do begin
            AI := CopyStr(ReadAi(Raw, Position), 1, 2);
            if AI = '' then
                exit(false);

            Position += 4;
            case AI of
                '01':
                    begin
                        Value := CopyStr(Raw, Position, 14);
                        if StrLen(Value) <> 14 then
                            exit(false);
                        Fields.Add('gtin', Value);
                        Position += 14;
                    end;
                '17':
                    begin
                        Value := CopyStr(Raw, Position, 6);
                        if StrLen(Value) <> 6 then
                            exit(false);
                        Fields.Add('exp', Value);
                        Position += 6;
                    end;
                '00':
                    begin
                        Value := CopyStr(Raw, Position, 18);
                        if StrLen(Value) <> 18 then
                            exit(false);
                        Fields.Add('sscc', Value);
                        Position += 18;
                    end;
                '10':
                    begin
                        Value := ReadVariableValue(Raw, Position);
                        Fields.Add('lot', Value);
                        Position += StrLen(Value);
                    end;
                '21':
                    begin
                        Value := ReadVariableValue(Raw, Position);
                        Fields.Add('sn', Value);
                        Position += StrLen(Value);
                    end;
                else
                    exit(false);
            end;
        end;

        exit(true);
    end;

    local procedure ReadAi(Raw: Text; Position: Integer): Text
    begin
        if CopyStr(Raw, Position, 1) <> '(' then
            exit('');
        if CopyStr(Raw, Position + 3, 1) <> ')' then
            exit('');
        exit(CopyStr(Raw, Position + 1, 2));
    end;

    local procedure ReadVariableValue(Raw: Text; Position: Integer): Text
    var
        NextAi: Integer;
        Cursor: Integer;
    begin
        Cursor := Position;
        while Cursor <= StrLen(Raw) do begin
            if CopyStr(Raw, Cursor, 1) = '(' then begin
                NextAi := Cursor;
                if IsKnownAi(Raw, NextAi) then
                    exit(CopyStr(Raw, Position, Cursor - Position));
            end;
            Cursor += 1;
        end;

        exit(CopyStr(Raw, Position));
    end;

    local procedure IsKnownAi(Raw: Text; Position: Integer): Boolean
    var
        AI: Text;
    begin
        AI := ReadAi(Raw, Position);
        exit((AI = '01') or (AI = '10') or (AI = '17') or (AI = '21') or (AI = '00'));
    end;
}
