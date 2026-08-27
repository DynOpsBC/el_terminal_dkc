codeunit 72056 "DOPSWHS Entitlement"
{
    Access = Public;

    procedure CheckDeviceLimit()
    var
        Setup: Record "DOPSWHS Setup";
        DeviceRegistration: Record "DOPSWHS Device Registration";
        Dimensions: Dictionary of [Text, Text];
        DeviceLimit: Integer;
        ActiveDevices: Integer;
    begin
        if not Setup.Get('') then
            exit;

        DeviceRegistration.SetRange(Active, true);
        ActiveDevices := DeviceRegistration.Count();
        DeviceLimit := Setup."Device Limit";
        if DeviceLimit = 0 then
            DeviceLimit := GetTierDefaultLimit(Setup."License Tier");

        if ActiveDevices > DeviceLimit then begin
            Dimensions.Add('licenseTier', Format(Setup."License Tier"));
            Dimensions.Add('deviceLimit', Format(DeviceLimit));
            Dimensions.Add('activeDevices', Format(ActiveDevices));
            Session.LogMessage('AdvWMS.Entitlement.DeviceLimitExceeded', 'Device limit exceeded.', Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dimensions);
        end;
    end;

    local procedure GetTierDefaultLimit(LicenseTier: Option Essentials,Advanced,Enterprise): Integer
    begin
        case LicenseTier of
            LicenseTier::Essentials:
                exit(10);
            LicenseTier::Advanced:
                exit(50);
            LicenseTier::Enterprise:
                exit(250);
        end;
    end;
}
