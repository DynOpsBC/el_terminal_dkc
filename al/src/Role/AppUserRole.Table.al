table 72268 "DOPSWHS App User Role"
{
    // Assigns one or more roles to a user. A user can carry multiple roles (PICKER + QUALITY);
    // when they hit the same entity, filters from each role are OR-joined broader visibility.
    Caption = 'App User Role';
    DataClassification = EndUserIdentifiableInformation;
    Access = Public;

    fields
    {
        field(1;  "User ID"; Code[50])
        {
            Caption = 'User ID';
            DataClassification = EndUserIdentifiableInformation;
            TableRelation = User."User Name";
            NotBlank = true;
        }
        field(2;  "Role Code"; Code[20])
        {
            Caption = 'Role Code';
            TableRelation = "DOPSWHS App Role".Code;
            NotBlank = true;
        }
        field(10; "Priority"; Integer)        { Caption = 'Priority'; InitValue = 100; }
        field(20; "Disabled"; Boolean)        { Caption = 'Disabled'; }
        field(30; "Assigned DateTime"; DateTime) { Caption = 'Assigned'; Editable = false; }
        field(31; "Assigned By"; Code[50])     { Caption = 'Assigned By'; Editable = false; }
    }

    keys
    {
        key(PK; "User ID", "Role Code") { Clustered = true; }
        key(Role; "Role Code") { }
    }

    trigger OnInsert()
    begin
        if "Assigned DateTime" = 0DT then
            "Assigned DateTime" := CurrentDateTime();
        if "Assigned By" = '' then
            "Assigned By" := CopyStr(UserId(), 1, 50);
    end;
}
