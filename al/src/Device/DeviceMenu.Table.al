table 72002 "DOPSWHS Device Menu"
{
    Caption = 'DOPSWHS Device Menu';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Config Code"; Code[20]) { Caption = 'Config Code'; TableRelation = "DOPSWHS Device Configuration"; }
        field(2; "Application Module"; Enum "DOPSWHS Application Module") { Caption = 'Application Module'; }
        field(3; "Menu Item"; Code[30]) { Caption = 'Menu Item'; }
        field(4; "Sort Order"; Integer) { Caption = 'Sort Order'; }
        field(5; Visible; Boolean) { Caption = 'Visible'; InitValue = true; }
    }

    keys
    {
        key(PK; "Config Code", "Menu Item") { Clustered = true; }
        key(Sort; "Config Code", "Sort Order") { }
    }
}
