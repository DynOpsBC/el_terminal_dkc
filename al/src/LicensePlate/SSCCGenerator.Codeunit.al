codeunit 72042 "DOPSWHS SSCC Generator"
{
    Access = Public;

    procedure Generate(): Code[18]
    var
        Setup: Record "DOPSWHS Setup";
        NoSeries: Codeunit "No. Series";
        SeriesSetup: Codeunit "DOPSWHS LP Series Setup";
        Telemetry: Codeunit "DOPSWHS Telemetry";
        Prefix: Text;
        SerialRef: Text;
        Base17: Text[17];
        Candidate: Code[18];
        SeriesCode: Code[20];
        SerialLength: Integer;
        Attempt: Integer;
        LPHeader: Record "DOPSWHS LP Header";
    begin
        SeriesCode := SeriesSetup.EnsureSsccNoSeries();
        Setup.Get('');
        Prefix := Setup."GS1 Company Prefix";
        if Prefix = '' then begin
            Prefix := '9999999';
            Telemetry.LogInfo('SSCC.ExtensionPrefix', 'GS1 company prefix is empty; using extension filler prefix.');
        end;
        if DigitsOnly(Prefix) <> Prefix then
            Error('GS1 firma öneki yalnızca rakamlardan oluşmalıdır: %1.', Prefix);
        SerialLength := 16 - StrLen(Prefix);
        if SerialLength <= 0 then
            Error('GS1 firma öneki SSCC için fazla uzundur: %1.', Prefix);

        // GetNextNo sayısal değeri 10 haneli (0000000001) üretebilir; SSCC'de
        // firma önekinden sonra bu kurulumda 9 hane kalır. Eski kod birleşik
        // metni soldan 17 haneye keserek değişen son rakamı atıyor ve ardışık
        // LP'lere aynı SSCC'yi veriyordu. Seri referansını sağdan sığdır.
        // Ayrıca hatalı/eski seri kurulumlarına karşı tabloda benzersizliği
        // kilit altında doğrula.
        LPHeader.LockTable();
        for Attempt := 1 to 100 do begin
            SerialRef := DigitsOnly(NoSeries.GetNextNo(SeriesCode));
            if SerialRef = '' then
                Error('%1 SSCC numara serisi sayısal bir değer üretmedi.', SeriesCode);
            Base17 := CopyStr('0' + Prefix + FitSerialReference(SerialRef, SerialLength), 1, 17);
            Candidate := CopyStr(Base17 + Format(CalculateCheckDigit(Base17)), 1, 18);
            LPHeader.Reset();
            LPHeader.SetRange(SSCC, Candidate);
            if LPHeader.IsEmpty() then
                exit(Candidate);
        end;

        Error('%1 SSCC numara serisi 100 denemede benzersiz bir değer üretemedi. Seri satırını kontrol edin.', SeriesCode);
    end;

    procedure CalculateCheckDigit(SeventeenDigits: Text[17]): Char
    var
        I: Integer;
        Digit: Integer;
        Sum: Integer;
        Check: Integer;
    begin
        if StrLen(SeventeenDigits) <> 17 then
            Error('SSCC check digit requires 17 digits.');
        for I := 17 downto 1 do begin
            Evaluate(Digit, CopyStr(SeventeenDigits, I, 1));
            if ((17 - I + 1) mod 2) = 1 then
                Sum += Digit * 3
            else
                Sum += Digit;
        end;
        Check := (10 - (Sum mod 10)) mod 10;
        exit(CopyStr(Format(Check), 1, 1)[1]);
    end;

    local procedure PadLeft(Value: Text; Length: Integer; PadChar: Text[1]): Text
    begin
        while StrLen(Value) < Length do
            Value := PadChar + Value;
        exit(Value);
    end;

    local procedure FitSerialReference(Value: Text; Length: Integer): Text
    begin
        if StrLen(Value) > Length then
            Value := CopyStr(Value, StrLen(Value) - Length + 1, Length);
        exit(PadLeft(Value, Length, '0'));
    end;

    local procedure DigitsOnly(Value: Text): Text
    var
        I: Integer;
        Result: Text;
        Ch: Text[1];
    begin
        for I := 1 to StrLen(Value) do begin
            Ch := CopyStr(Value, I, 1);
            if Ch in ['0' .. '9'] then
                Result += Ch;
        end;
        exit(Result);
    end;
}
