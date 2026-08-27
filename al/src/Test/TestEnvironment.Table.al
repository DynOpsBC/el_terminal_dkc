table 72029 "DOPSWHS Test Environment"
{
    Caption = 'Test Environment';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Code"; Code[20]) { Caption = 'Code'; NotBlank = true; }
        field(10; Description; Text[100]) { Caption = 'Description'; }
        field(20; "BC Tenant ID"; Text[50]) { Caption = 'BC Tenant ID'; }
        field(30; "BC Environment Name"; Text[50]) { Caption = 'BC Environment Name'; }
        field(40; "BC Company Name"; Text[100]) { Caption = 'BC Company Name'; }
        field(50; Category; Option)
        {
            Caption = 'Category';
            OptionMembers = Dev,Test,UAT,PreProd,Production;
            OptionCaption = 'Dev,Test,UAT,Pre-Prod,Production';
        }
        field(60; Active; Boolean) { Caption = 'Active'; InitValue = true; }
        field(70; "Sort Order"; Integer) { Caption = 'Sort Order'; }
        field(80; Notes; Text[250]) { Caption = 'Notes'; }
    }

    keys
    {
        key(PK; "Code") { Clustered = true; }
        key(Category; Category, "Sort Order") { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Code", Description, Category) { }
    }
}
