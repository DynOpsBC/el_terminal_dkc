table 72259 "DOPSWHS Config Check"
{
    Caption = 'Configuration Check';
    DataClassification = CustomerContent;
    Access = Public;

    fields
    {
        field(1; "Code"; Code[20]) { Caption = 'Code'; DataClassification = CustomerContent; }
        field(2; "Sort Order"; Integer) { Caption = 'Sort Order'; DataClassification = CustomerContent; }
        field(10; "Title"; Text[100]) { Caption = 'Check'; DataClassification = CustomerContent; }
        field(20; "Status"; Option)
        {
            Caption = 'Status';
            DataClassification = CustomerContent;
            OptionMembers = NotChecked,OK,Warning,Missing;
            OptionCaption = 'Not Checked,OK,Warning,Missing';
        }
        field(30; "Detail"; Text[250]) { Caption = 'Detail'; DataClassification = CustomerContent; }
        field(40; "Auto Fixable"; Boolean) { Caption = 'Auto-Fixable'; DataClassification = CustomerContent; }
        field(50; "Required"; Boolean) { Caption = 'Required'; DataClassification = CustomerContent; }
    }

    keys
    {
        key(PK; "Code") { Clustered = true; }
        key(Sort; "Sort Order") { }
    }
}
