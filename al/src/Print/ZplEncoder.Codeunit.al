codeunit 72376 "DOPSWHS ZPL Encoder"
{
    Access = Internal;

    /// <summary>
    /// Encodes untrusted Business Central text for a ZPL ^FH_ / ^FD field.
    /// Command introducers and the chosen hex indicator can no longer terminate
    /// a field or inject a second printer command.
    /// </summary>
    procedure EncodeFieldData(Value: Text): Text
    var
        ControlCharacter: Char;
        ControlNumber: Integer;
    begin
        for ControlNumber := 1 to 31 do begin
            ControlCharacter := ControlNumber;
            Value := Value.Replace(Format(ControlCharacter), ' ');
        end;
        ControlCharacter := 127;
        Value := Value.Replace(Format(ControlCharacter), ' ');
        Value := Value.Replace('_', '_5F');
        Value := Value.Replace('^', '_5E');
        Value := Value.Replace('~', '_7E');
        Value := Value.Replace('>', '_3E');
        exit(Value);
    end;
}
