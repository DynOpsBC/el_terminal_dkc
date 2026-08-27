table 72004 "DOPSWHS Device Registration"
{
    Caption = 'DOPSWHS Device Registration';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Device ID"; Code[80]) { Caption = 'Device ID'; DataClassification = EndUserPseudonymousIdentifiers; }
        field(2; Fingerprint; Text[250]) { Caption = 'Fingerprint'; DataClassification = EndUserPseudonymousIdentifiers; }
        field(3; "App Version"; Text[30]) { Caption = 'App Version'; }
        field(4; "Last Seen DateTime"; DateTime) { Caption = 'Last Seen DateTime'; }
        field(5; Active; Boolean) { Caption = 'Active'; InitValue = true; }
        field(6; "Assigned User"; Code[50]) { Caption = 'Assigned User'; TableRelation = User."User Name"; DataClassification = EndUserIdentifiableInformation; }
        field(7; "Config Code"; Code[20]) { Caption = 'Config Code'; TableRelation = "DOPSWHS Device Configuration"; }
    }

    keys { key(PK; "Device ID") { Clustered = true; } }

    trigger OnInsert()
    var
        License: Codeunit "DOPSWHS License Mgmt";
    begin
        License.GuardSeats(1);
    end;
}
