table 72030 "DOPSWHS Test User Group"
{
    Caption = 'Test User Group';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Code"; Code[20]) { Caption = 'Code'; NotBlank = true; }
        field(10; Description; Text[100]) { Caption = 'Description'; }
        field(20; Category; Option)
        {
            Caption = 'Category';
            OptionMembers = Dev,QA,Business,Power,External;
            OptionCaption = 'Dev,QA,Business,Power,External';
        }
        field(30; Active; Boolean) { Caption = 'Active'; InitValue = true; }
        field(40; "Member Count"; Integer)
        {
            Caption = 'Member Count';
            FieldClass = FlowField;
            CalcFormula = count("DOPSWHS Test User Group Member" where("Group Code" = field("Code")));
            Editable = false;
        }
        field(50; Notes; Text[250]) { Caption = 'Notes'; }
    }

    keys
    {
        key(PK; "Code") { Clustered = true; }
        key(Category; Category) { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Code", Description, Category) { }
    }
}
