codeunit 72038 "DOPSWHS Device Auth"
{
    Access = Public;

    procedure Register(DeviceId: Code[80]; Fingerprint: Text[250]; AppVersion: Text[30]; var Registration: Record "DOPSWHS Device Registration")
    var
        DeviceConfig: Record "DOPSWHS Device Configuration";
    begin
        if not Registration.Get(DeviceId) then begin
            Registration.Init();
            Registration."Device ID" := DeviceId;
            Registration.Active := true;
            if DeviceConfig.Get('DEFAULT') then
                Registration."Config Code" := DeviceConfig."Code";
            Registration.Insert(true);
        end;

        Registration.Fingerprint := Fingerprint;
        Registration."App Version" := AppVersion;
        Registration."Last Seen DateTime" := CurrentDateTime();
        if Registration."Config Code" = '' then
            if DeviceConfig.Get('DEFAULT') then
                Registration."Config Code" := DeviceConfig."Code";
        Registration.Modify(true);
    end;
}
