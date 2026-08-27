page 72225 "DOPSWHS Device API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'device';
    EntitySetName = 'devices';
    SourceTable = "DOPSWHS Device Registration";
    DelayedInsert = true;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(id; Rec."Device ID") { Caption = 'id'; }
                field(fingerprint; Rec.Fingerprint) { Caption = 'fingerprint'; }
                field(appVersion; Rec."App Version") { Caption = 'appVersion'; }
                field(lastSeenDateTime; Rec."Last Seen DateTime") { Caption = 'lastSeenDateTime'; }
                field(active; Rec.Active) { Caption = 'active'; }
                field(assignedUser; Rec."Assigned User") { Caption = 'assignedUser'; }
                field(configCode; Rec."Config Code") { Caption = 'configCode'; }
            }
        }
    }

    [ServiceEnabled]
    procedure Register(deviceId: Text; fingerprint: Text; appVersion: Text): Text
    var
        DeviceAuth: Codeunit "DOPSWHS Device Auth";
        Registration: Record "DOPSWHS Device Registration";
    begin
        DeviceAuth.Register(CopyStr(deviceId, 1, MaxStrLen(Registration."Device ID")), CopyStr(fingerprint, 1, MaxStrLen(Registration.Fingerprint)), CopyStr(appVersion, 1, MaxStrLen(Registration."App Version")), Registration);
        exit(Registration."Config Code");
    end;
}
