table 72001 "DOPSWHS Device Configuration"
{
    Caption = 'DOPSWHS Device Configuration';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Code"; Code[20]) { Caption = 'Code'; DataClassification = SystemMetadata; }
        field(2; Description; Text[100]) { Caption = 'Description'; }
        field(3; "Location Code"; Code[10]) { Caption = 'Location Code'; TableRelation = Location; }
        field(4; "Login Mode"; Enum "DOPSWHS Login Mode") { Caption = 'Login Mode'; }
        field(5; "Assign Document On Open"; Boolean) { Caption = 'Assign Document On Open'; }
        field(6; "Ignore Bins"; Boolean) { Caption = 'Ignore Bins'; }
        field(7; "LP Usage Default Action"; Enum "DOPSWHS Partial Use Action") { Caption = 'LP Usage Default Action'; }
        field(8; "Max List Rows"; Integer) { Caption = 'Max List Rows'; MinValue = 1; InitValue = 100; }
        field(9; "Scan Beep"; Boolean) { Caption = 'Scan Beep'; InitValue = true; }
        field(10; "Auto Post"; Boolean) { Caption = 'Auto Post'; }
        field(11; "Print Channel"; Enum "DOPSWHS Print Channel") { Caption = 'Print Channel'; }
    }

    keys { key(PK; "Code") { Clustered = true; } }
}
