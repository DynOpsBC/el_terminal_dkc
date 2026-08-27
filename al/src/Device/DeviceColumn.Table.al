table 72003 "DOPSWHS Device Column"
{
    Caption = 'DOPSWHS Device Column';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Config Code"; Code[20]) { Caption = 'Config Code'; TableRelation = "DOPSWHS Device Configuration"; }
        field(2; "List Name"; Code[50]) { Caption = 'List Name'; }
        field(3; "Column Name"; Code[50]) { Caption = 'Column Name'; }
        field(4; Width; Integer) { Caption = 'Width'; MinValue = 0; }
        field(5; "Sort Order"; Integer) { Caption = 'Sort Order'; }
    }

    keys
    {
        key(PK; "Config Code", "List Name", "Column Name") { Clustered = true; }
        key(Sort; "Config Code", "List Name", "Sort Order") { }
    }
}
