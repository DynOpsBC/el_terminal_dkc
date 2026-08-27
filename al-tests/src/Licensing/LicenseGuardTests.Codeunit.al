codeunit 72494 "DOPSWHS License Guard Tests"
{
    Subtype = Test;

    [Test]
    procedure InactiveLicense_BlocksFeatureGuard()
    var
        Setup: Record "DOPSWHS Setup";
        License: Codeunit "DOPSWHS License Mgmt";
        TestHelper: Codeunit "DOPSWHS Test Helper";
    begin
        // Inactive license → GuardFeature must raise an error so callers
        // can't silently bypass tier limits.
        TestHelper.ResetSetup();
        Setup.Get('');
        Setup."License Status" := Setup."License Status"::Invalid;
        Setup."License Status Message" := 'No key configured';
        Setup."License Last Verified At" := CurrentDateTime();
        Setup.Modify(true);

        asserterror License.GuardFeature(Enum::"DOPSWHS License Feature"::PrintBridge);
    end;

    [Test]
    procedure EssentialsTier_BlocksAdvancedFeature()
    var
        Setup: Record "DOPSWHS Setup";
        License: Codeunit "DOPSWHS License Mgmt";
        TestHelper: Codeunit "DOPSWHS Test Helper";
    begin
        // Essentials license → Print Bridge (Advanced tier) is rejected.
        TestHelper.ResetSetup();
        Setup.Get('');
        Setup."License Status" := Setup."License Status"::Active;
        Setup."License Tier" := Setup."License Tier"::Essentials;
        Setup."License Seats" := 50;
        Setup."License Last Verified At" := CurrentDateTime();
        Setup.Modify(true);

        asserterror License.GuardFeature(Enum::"DOPSWHS License Feature"::PrintBridge);
    end;

    [Test]
    procedure EnterpriseTier_AllowsProductionFeature()
    var
        Setup: Record "DOPSWHS Setup";
        License: Codeunit "DOPSWHS License Mgmt";
        TestHelper: Codeunit "DOPSWHS Test Helper";
    begin
        // Enterprise license → Production guard passes silently.
        TestHelper.ResetSetup();
        Setup.Get('');
        Setup."License Status" := Setup."License Status"::Active;
        Setup."License Tier" := Setup."License Tier"::Enterprise;
        Setup."License Seats" := 1000;
        Setup."License Last Verified At" := CurrentDateTime();
        Setup.Modify(true);

        License.GuardFeature(Enum::"DOPSWHS License Feature"::Production);
        // No assertion — if Guard raised, the test would fail with the codeunit error.
    end;

    [Test]
    procedure SeatLimitReached_BlocksDeviceInsert()
    var
        Setup: Record "DOPSWHS Setup";
        DeviceReg: Record "DOPSWHS Device Registration";
        TestHelper: Codeunit "DOPSWHS Test Helper";
        i: Integer;
    begin
        // Active Advanced license with 2 seats; inserting a 3rd device must fail.
        TestHelper.ResetSetup();
        Setup.Get('');
        Setup."License Status" := Setup."License Status"::Active;
        Setup."License Tier" := Setup."License Tier"::Advanced;
        Setup."License Seats" := 2;
        Setup."License Last Verified At" := CurrentDateTime();
        Setup.Modify(true);

        DeviceReg.DeleteAll();
        for i := 1 to 2 do begin
            DeviceReg.Init();
            DeviceReg."Device ID" := CopyStr('DEV-' + Format(i), 1, MaxStrLen(DeviceReg."Device ID"));
            DeviceReg."App Version" := '1.10.0';
            DeviceReg.Insert(true);
        end;

        // 3rd device must blow up via DeviceRegistration.OnInsert → GuardSeats.
        DeviceReg.Init();
        DeviceReg."Device ID" := 'DEV-3';
        DeviceReg."App Version" := '1.10.0';
        asserterror DeviceReg.Insert(true);
    end;

    [Test]
    procedure SeatLimitNotReached_AllowsDeviceInsert()
    var
        Setup: Record "DOPSWHS Setup";
        DeviceReg: Record "DOPSWHS Device Registration";
        TestHelper: Codeunit "DOPSWHS Test Helper";
    begin
        TestHelper.ResetSetup();
        Setup.Get('');
        Setup."License Status" := Setup."License Status"::Active;
        Setup."License Tier" := Setup."License Tier"::Advanced;
        Setup."License Seats" := 10;
        Setup."License Last Verified At" := CurrentDateTime();
        Setup.Modify(true);

        DeviceReg.DeleteAll();
        DeviceReg.Init();
        DeviceReg."Device ID" := 'DEV-OK';
        DeviceReg."App Version" := '1.10.0';
        DeviceReg.Insert(true); // must not raise
    end;

    [Test]
    procedure OfflineStatus_StillCountsAsActive()
    var
        Setup: Record "DOPSWHS Setup";
        License: Codeunit "DOPSWHS License Mgmt";
        TestHelper: Codeunit "DOPSWHS Test Helper";
    begin
        // Offline (within 7-day grace) is treated as active so customers
        // aren't locked out during a brief network outage.
        TestHelper.ResetSetup();
        Setup.Get('');
        Setup."License Status" := Setup."License Status"::Offline;
        Setup."License Tier" := Setup."License Tier"::Advanced;
        Setup."License Last Verified At" := CurrentDateTime();
        Setup.Modify(true);

        if not License.IsActive() then
            Error('IsActive() returned false for Offline status');
    end;

    [Test]
    procedure CurrentTier_DefaultsToEssentials_WhenSetupMissing()
    var
        License: Codeunit "DOPSWHS License Mgmt";
        TestHelper: Codeunit "DOPSWHS Test Helper";
        Tier: Enum "DOPSWHS License Tier";
    begin
        // Fresh tenant before any setup row → safe default.
        TestHelper.ResetSetup();
        Tier := License.CurrentTier();
        if Tier <> Tier::Essentials then
            Error('Expected default Essentials tier, got %1', Tier);
    end;
}
