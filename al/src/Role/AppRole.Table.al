table 72267 "DOPSWHS App Role"
{
    // Functional WMS role: PICKER, RECEIVER, SHIPPER, COUNTER, QUALITY, INV_ADMIN, OPERATOR.
    // Orthogonal to BC Permission Sets (which control object access). A role groups one or more
    // server-side filter rules (see "DOPSWHS App Role Filter Rule") and is assigned to users
    // via "DOPSWHS App User Role" so OData API pages apply the user's effective filters in
    // their OnOpenPage trigger.
    Caption = 'App Role';
    DataClassification = CustomerContent;
    Access = Public;
    LookupPageId = "DOPSWHS App Role List";
    DrillDownPageId = "DOPSWHS App Role List";

    fields
    {
        field(1;  "Code"; Code[20])           { Caption = 'Code'; NotBlank = true; }
        field(10; "Description"; Text[100])   { Caption = 'Description'; }
        field(20; "Sort Order"; Integer)      { Caption = 'Sort Order'; }
        field(30; "Active"; Boolean)          { Caption = 'Active'; InitValue = true; }
        field(40; "Is System"; Boolean)       { Caption = 'System Role'; Editable = false; }
        field(50; "Hide Test Tools"; Boolean) { Caption = 'Hide Test Tools'; InitValue = true; }
        field(51; "Hide Admin Tools"; Boolean){ Caption = 'Hide Admin Tools'; InitValue = true; }
        field(60; "Notes"; Text[250])         { Caption = 'Notes'; }
        field(70; "Member Count"; Integer)
        {
            Caption = 'Member Count';
            FieldClass = FlowField;
            CalcFormula = count("DOPSWHS App User Role" where("Role Code" = field(Code), Disabled = const(false)));
            Editable = false;
        }
        field(71; "Rule Count"; Integer)
        {
            Caption = 'Filter Rule Count';
            FieldClass = FlowField;
            CalcFormula = count("DOPSWHS App Role Filter Rule" where("Role Code" = field(Code), Disabled = const(false)));
            Editable = false;
        }
        field(99; "Last Modified DateTime"; DateTime) { Caption = 'Last Modified'; Editable = false; }
    }

    keys
    {
        key(PK; "Code") { Clustered = true; }
        key(Sort; "Sort Order") { }
    }

    trigger OnInsert()
    begin
        "Last Modified DateTime" := CurrentDateTime();
    end;

    trigger OnModify()
    begin
        "Last Modified DateTime" := CurrentDateTime();
    end;

    trigger OnDelete()
    begin
        if "Is System" then
            Error('System rolleri silinemez (%1).', Code);
    end;
}
