codeunit 72134 "DOPSWHS Setup Tests"
{
    Subtype = Test;

    [Test]
    procedure CannotInsertSecondSetupRow()
    var
        Setup: Record "DOPSWHS Setup";
        TestHelper: Codeunit "DOPSWHS Test Helper";
    begin
        TestHelper.ResetSetup();
        Setup.Init();
        Setup.Insert(true);

        asserterror Setup.Insert(true);
    end;

    [Test]
    procedure WizardCreatesNoSeries()
    var
        Setup: Record "DOPSWHS Setup";
        TestHelper: Codeunit "DOPSWHS Test Helper";
    begin
        Setup := TestHelper.EnsureSetup();
        Setup.TestField("Primary Key", '');
    end;
}

