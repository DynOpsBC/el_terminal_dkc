codeunit 72105 "DOPSWHS Device Auth Tests"
{
    Subtype = Test;

    [Test]
    procedure FirstRegistrationCreatesRecord()
    var
        Registration: Record "DOPSWHS Device Registration";
    begin
        ResetDevices();
        RegisterDevice('DEV-1', 'FP-1', '1.0.0', Registration);
        Registration.Get('DEV-1');
        Registration.TestField(Fingerprint, 'FP-1');
        Registration.TestField(Active, true);
    end;

    [Test]
    procedure RepeatRegistrationUpdatesFingerprint()
    var
        Registration: Record "DOPSWHS Device Registration";
    begin
        ResetDevices();
        RegisterDevice('DEV-1', 'FP-1', '1.0.0', Registration);
        RegisterDevice('DEV-1', 'FP-2', '1.0.1', Registration);
        Registration.Get('DEV-1');
        Registration.TestField(Fingerprint, 'FP-2');
        Registration.TestField("App Version", '1.0.1');
    end;

    [Test]
    procedure MissingConfigGracefullyDefaults()
    var
        Registration: Record "DOPSWHS Device Registration";
        Config: Record "DOPSWHS Device Configuration";
        DeviceAuth: Codeunit "DOPSWHS Device Auth";
    begin
        ResetDevices();
        Config.DeleteAll();
        DeviceAuth.Register('DEV-2', 'FP-1', '1.0.0', Registration);
        Registration.Get('DEV-2');
        Registration.TestField("Config Code", '');
    end;

    [Test]
    procedure LastSeenUpdated()
    var
        Registration: Record "DOPSWHS Device Registration";
        Assert: Codeunit "Library Assert";
    begin
        ResetDevices();
        RegisterDevice('DEV-3', 'FP-1', '1.0.0', Registration);
        Registration.Get('DEV-3');
        Assert.IsTrue(Registration."Last Seen DateTime" <> 0DT, 'Last seen timestamp should be set.');
    end;

    local procedure RegisterDevice(DeviceId: Code[80]; Fingerprint: Text[250]; AppVersion: Text[30]; var Registration: Record "DOPSWHS Device Registration")
    var
        DeviceAuth: Codeunit "DOPSWHS Device Auth";
        SetupWizard: Codeunit "DOPSWHS Setup Wizard";
    begin
        SetupWizard.SeedSprint1Defaults();
        DeviceAuth.Register(DeviceId, Fingerprint, AppVersion, Registration);
    end;

    local procedure ResetDevices()
    var
        Registration: Record "DOPSWHS Device Registration";
    begin
        Registration.DeleteAll();
    end;
}
