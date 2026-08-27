table 72033 "DOPSWHS Test Run Result"
{
    Caption = 'Test Run Result';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Run No."; Code[20])
        {
            Caption = 'Run No.';
            TableRelation = "DOPSWHS Test Run";
            NotBlank = true;
        }
        field(2; "Test Case Code"; Code[20])
        {
            Caption = 'Test Case Code';
            TableRelation = "DOPSWHS Test Case";
            NotBlank = true;
        }
        field(10; Status; Option)
        {
            Caption = 'Status';
            OptionMembers = NotRun,Running,Passed,Failed,Skipped,PendingManual,Blocked;
            OptionCaption = 'Not Run,Running,Passed,Failed,Skipped,Pending Manual,Blocked';
        }
        field(20; "Section"; Code[10])
        {
            Caption = 'Section';
            FieldClass = FlowField;
            CalcFormula = lookup("DOPSWHS Test Case".Section where("Code" = field("Test Case Code")));
            Editable = false;
        }
        field(30; Title; Text[150])
        {
            Caption = 'Title';
            FieldClass = FlowField;
            CalcFormula = lookup("DOPSWHS Test Case".Title where("Code" = field("Test Case Code")));
            Editable = false;
        }
        field(40; "Started DateTime"; DateTime)
        {
            Caption = 'Started DateTime';
            Editable = false;
        }
        field(50; "Completed DateTime"; DateTime)
        {
            Caption = 'Completed DateTime';
            Editable = false;
        }
        field(60; "Duration Ms"; Integer)
        {
            Caption = 'Duration (ms)';
            Editable = false;
        }
        field(70; "Error Message"; Text[2048])
        {
            Caption = 'Error Message';
            Editable = false;
        }
        field(80; "Stack Trace"; Blob)
        {
            Caption = 'Stack Trace';
        }
        field(90; "Manual Verified By"; Code[50])
        {
            Caption = 'Manual Verified By';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(100; "Manual Verified DateTime"; DateTime)
        {
            Caption = 'Manual Verified DateTime';
        }
        field(110; Notes; Text[2048]) { Caption = 'Notes'; }
        field(120; "Surrogate Used"; Boolean)
        {
            Caption = 'Surrogate Used';
            Editable = false;
        }
        field(130; "Automation Type"; Option)
        {
            Caption = 'Automation Type';
            OptionMembers = Auto,Surrogate,Manual;
            OptionCaption = 'Auto,Surrogate,Manual';
            FieldClass = FlowField;
            CalcFormula = lookup("DOPSWHS Test Case"."Automation Type" where("Code" = field("Test Case Code")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Run No.", "Test Case Code") { Clustered = true; }
        key(StatusKey; "Run No.", Status) { }
        key(CaseKey; "Test Case Code") { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Run No.", "Test Case Code", Status) { }
        fieldgroup(Brick; "Test Case Code", Title, Status, "Duration Ms") { }
    }
}
