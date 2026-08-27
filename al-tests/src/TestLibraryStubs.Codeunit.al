codeunit 72490 Assert
{
    procedure AreEqual(Expected: Variant; Actual: Variant; Message: Text)
    begin
        if Format(Expected, 0, 9) <> Format(Actual, 0, 9) then
            Error('%1 Expected: %2; Actual: %3.', Message, Expected, Actual);
    end;

    procedure AreNotEqual(Expected: Variant; Actual: Variant; Message: Text)
    begin
        if Format(Expected, 0, 9) = Format(Actual, 0, 9) then
            Error('%1 Both values are %2.', Message, Actual);
    end;

    procedure IsTrue(Condition: Boolean; Message: Text)
    begin
        if not Condition then
            Error('%1', Message);
    end;

    procedure IsFalse(Condition: Boolean; Message: Text)
    begin
        if Condition then
            Error('%1', Message);
    end;

    procedure ExpectedError(Message: Text)
    var
        ActualError: Text;
    begin
        ActualError := GetLastErrorText();
        if StrPos(LowerCase(ActualError), LowerCase(Message)) = 0 then
            Error('Expected error containing "%1", but received "%2".', Message, ActualError);
    end;
}

codeunit 72491 "Library Assert"
{
    procedure AreEqual(Expected: Variant; Actual: Variant; Message: Text)
    begin
        if Format(Expected, 0, 9) <> Format(Actual, 0, 9) then
            Error('%1 Expected: %2; Actual: %3.', Message, Expected, Actual);
    end;

    procedure AreNotEqual(Expected: Variant; Actual: Variant; Message: Text)
    begin
        if Format(Expected, 0, 9) = Format(Actual, 0, 9) then
            Error('%1 Both values are %2.', Message, Actual);
    end;

    procedure IsTrue(Condition: Boolean; Message: Text)
    begin
        if not Condition then
            Error('%1', Message);
    end;

    procedure IsFalse(Condition: Boolean; Message: Text)
    begin
        if Condition then
            Error('%1', Message);
    end;

    procedure ExpectedError(Message: Text)
    var
        ActualError: Text;
    begin
        ActualError := GetLastErrorText();
        if StrPos(LowerCase(ActualError), LowerCase(Message)) = 0 then
            Error('Expected error containing "%1", but received "%2".', Message, ActualError);
    end;
}

codeunit 72492 "Library - Warehouse"
{
}

codeunit 72493 "Library - Inventory"
{
}
