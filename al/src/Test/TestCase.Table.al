table 72028 "DOPSWHS Test Case"
{
    Caption = 'Test Case Catalog';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Code"; Code[20]) { Caption = 'Code'; NotBlank = true; }
        field(10; Section; Code[10]) { Caption = 'Section'; }
        field(20; Title; Text[150]) { Caption = 'Title'; }
        field(30; Description; Text[1024]) { Caption = 'Description'; }
        field(40; Surface; Option)
        {
            Caption = 'Surface';
            OptionMembers = "BC Web","Mobile WMS","Web SPA","REST API",Multi;
            OptionCaption = 'BC Web,Mobile WMS,Web SPA,REST API,Multi';
        }
        field(50; "Automation Type"; Option)
        {
            Caption = 'Automation Type';
            OptionMembers = Auto,Surrogate,Manual;
            OptionCaption = 'Auto,Surrogate,Manual';
        }
        field(60; "Automation Codeunit ID"; Integer)
        {
            Caption = 'Automation Codeunit ID';
            TableRelation = AllObjWithCaption."Object ID" where("Object Type" = const(Codeunit));
        }
        field(70; "Automation Procedure"; Text[80]) { Caption = 'Automation Procedure'; }
        field(80; "Estimated Seconds"; Integer) { Caption = 'Estimated Seconds'; InitValue = 5; }
        field(90; Active; Boolean) { Caption = 'Active'; InitValue = true; }
        field(100; "Critical"; Boolean) { Caption = 'Critical'; }
        field(110; "Sort Order"; Integer) { Caption = 'Sort Order'; }
    }

    keys
    {
        key(PK; "Code") { Clustered = true; }
        key(Section; Section, "Sort Order") { }
        key(Active; Active) { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Code", Title, Section) { }
        fieldgroup(Brick; "Code", Title, Section, "Automation Type") { }
    }
}
