table 72031 "DOPSWHS Test User Group Member"
{
    Caption = 'Test User Group Member';
    DataClassification = EndUserIdentifiableInformation;

    fields
    {
        field(1; "Group Code"; Code[20])
        {
            Caption = 'Group Code';
            TableRelation = "DOPSWHS Test User Group";
            NotBlank = true;
        }
        field(2; "User ID"; Code[50])
        {
            Caption = 'User ID';
            DataClassification = EndUserIdentifiableInformation;
            NotBlank = true;
        }
        field(10; Role; Option)
        {
            Caption = 'Role';
            OptionMembers = Member,Lead;
            OptionCaption = 'Member,Lead';
        }
        field(20; "Added DateTime"; DateTime)
        {
            Caption = 'Added DateTime';
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Group Code", "User ID") { Clustered = true; }
    }

    trigger OnInsert()
    begin
        if "Added DateTime" = 0DT then
            "Added DateTime" := CurrentDateTime();
    end;
}
