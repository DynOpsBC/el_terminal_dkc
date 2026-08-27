table 72262 "DOPSWHS App User Profile"
{
    // Per-user view + filter overlay for the mobile WMS app. The user's "Config Code" points at a
    // DOPSWHS Device Configuration whose Device Menu drives the visible modules; the fields on this
    // table layer USER-level overrides (default location, "only mine" filters, etc.) on top.
    Caption = 'App User Profile';
    DataClassification = CustomerContent;
    Access = Public;

    fields
    {
        field(1; "User ID"; Code[50]) { Caption = 'User ID'; DataClassification = EndUserIdentifiableInformation; TableRelation = User."User Name"; }
        field(10; "Description"; Text[100]) { Caption = 'Description'; DataClassification = CustomerContent; }
        field(20; "Config Code"; Code[20])
        {
            Caption = 'Device Config';
            DataClassification = CustomerContent;
            TableRelation = "DOPSWHS Device Configuration";
        }
        field(30; "Default Location Code"; Code[10]) { Caption = 'Default Location'; DataClassification = CustomerContent; TableRelation = Location; }
        field(31; "Default Bin Code"; Code[20])
        {
            Caption = 'Default Bin';
            DataClassification = CustomerContent;
            TableRelation = Bin.Code where("Location Code" = field("Default Location Code"));
        }
        field(40; "Locale"; Code[10]) { Caption = 'Locale'; DataClassification = CustomerContent; }
        field(50; "Only My Picks"; Boolean) { Caption = 'Only My Picks'; DataClassification = CustomerContent; }
        field(51; "Only My Receipts"; Boolean) { Caption = 'Only My Receipts'; DataClassification = CustomerContent; }
        field(52; "Only My PutAways"; Boolean) { Caption = 'Only My Put-Aways'; DataClassification = CustomerContent; }
        field(53; "Only My Shipments"; Boolean) { Caption = 'Only My Shipments'; DataClassification = CustomerContent; }
        field(54; "Only My Movements"; Boolean) { Caption = 'Only My Movements'; DataClassification = CustomerContent; }
        field(60; "LP Status Filter"; Option)
        {
            Caption = 'LP Status Filter';
            DataClassification = CustomerContent;
            OptionMembers = All,Built,Open,Used;
            OptionCaption = 'All,Built,Open,Used';
        }
        field(61; "Quality Filter"; Option)
        {
            Caption = 'Quality Filter';
            DataClassification = CustomerContent;
            OptionMembers = All,OpenOnly,FailedOnly;
            OptionCaption = 'All,Open Only,Failed Only';
        }
        field(70; "Hide Test Tools"; Boolean) { Caption = 'Hide Test Tools'; DataClassification = CustomerContent; InitValue = true; }
        field(71; "Hide Admin Tools"; Boolean) { Caption = 'Hide Admin Tools'; DataClassification = CustomerContent; InitValue = true; }
        field(80; "Max List Rows"; Integer) { Caption = 'Max List Rows'; DataClassification = CustomerContent; InitValue = 50; MinValue = 10; MaxValue = 500; }
        field(90; "Disabled"; Boolean) { Caption = 'Disabled'; DataClassification = CustomerContent; }
        field(99; "Last Modified DateTime"; DateTime) { Caption = 'Last Modified'; DataClassification = CustomerContent; Editable = false; }
    }

    keys
    {
        key(PK; "User ID") { Clustered = true; }
        key(Config; "Config Code") { }
    }

    trigger OnInsert()
    begin
        "Last Modified DateTime" := CurrentDateTime();
    end;

    trigger OnModify()
    begin
        "Last Modified DateTime" := CurrentDateTime();
    end;
}
