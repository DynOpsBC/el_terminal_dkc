table 72269 "DOPSWHS App Role Filter Rule"
{
    // A single SetFilter() rule a role wants applied on a target entity.
    // Filter Expression is BC filter syntax (e.g. '=%USER%|=''') with %USER%, %LOC%, %TODAY%
    // tokens substituted at runtime by "DOPSWHS App Role Filter Mgmt".
    Caption = 'App Role Filter Rule';
    DataClassification = CustomerContent;
    Access = Public;

    fields
    {
        field(1;  "Role Code"; Code[20])
        {
            Caption = 'Role Code';
            TableRelation = "DOPSWHS App Role".Code;
            NotBlank = true;
        }
        field(2;  "Entity"; Enum "DOPSWHS App Filter Entity")
        {
            Caption = 'Entity';
            NotBlank = true;
        }
        field(3;  "Line No."; Integer)
        {
            Caption = 'Line No.';
            AutoIncrement = true;
        }
        field(10; "Field No."; Integer)
        {
            Caption = 'Field No.';
            BlankZero = true;
        }
        field(11; "Field Name Hint"; Text[80])
        {
            Caption = 'Field Name (hint)';
            ToolTip = 'Read-only hint of the field name — only Field No. is used at runtime.';
        }
        field(20; "Filter Expression"; Text[250])
        {
            Caption = 'Filter Expression';
            ToolTip = 'BC filter syntax. Tokens: %USER%, %LOC%, %TODAY%, %NOW%.';
        }
        field(30; "Combine Mode"; Enum "DOPSWHS App Filter Combine")
        {
            Caption = 'Combine Mode';
            InitValue = "Append";
        }
        field(40; "Description"; Text[100])  { Caption = 'Description'; }
        field(50; "Disabled"; Boolean)       { Caption = 'Disabled'; }
        field(60; "Apply To Lines"; Boolean) { Caption = 'Cascade to lines'; }
    }

    keys
    {
        key(PK; "Role Code", "Entity", "Line No.") { Clustered = true; }
        key(Entity; "Entity", "Role Code") { }
    }
}
