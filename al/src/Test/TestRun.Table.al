table 72032 "DOPSWHS Test Run"
{
    Caption = 'Test Run';
    DataClassification = CustomerContent;
    LookupPageId = "DOPSWHS Test Run List";
    DrillDownPageId = "DOPSWHS Test Run List";

    fields
    {
        field(1; "Run No."; Code[20])
        {
            Caption = 'Run No.';
            DataClassification = SystemMetadata;
        }
        field(10; "Environment Code"; Code[20])
        {
            Caption = 'Environment Code';
            TableRelation = "DOPSWHS Test Environment";
        }
        field(20; "User Group Code"; Code[20])
        {
            Caption = 'User Group Code';
            TableRelation = "DOPSWHS Test User Group";
        }
        field(30; "Triggered By"; Code[50])
        {
            Caption = 'Triggered By';
            DataClassification = EndUserIdentifiableInformation;
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
        field(60; Status; Option)
        {
            Caption = 'Status';
            OptionMembers = Open,Running,Completed,PartialPass,Failed,Aborted;
            OptionCaption = 'Open,Running,Completed,Partial Pass,Failed,Aborted';
            Editable = false;
        }
        field(70; "Total Cases"; Integer)
        {
            Caption = 'Total Cases';
            FieldClass = FlowField;
            CalcFormula = count("DOPSWHS Test Run Result" where("Run No." = field("Run No.")));
            Editable = false;
        }
        field(80; Passed; Integer)
        {
            Caption = 'Passed';
            FieldClass = FlowField;
            CalcFormula = count("DOPSWHS Test Run Result" where("Run No." = field("Run No."), Status = const(Passed)));
            Editable = false;
        }
        field(90; Failed; Integer)
        {
            Caption = 'Failed';
            FieldClass = FlowField;
            CalcFormula = count("DOPSWHS Test Run Result" where("Run No." = field("Run No."), Status = const(Failed)));
            Editable = false;
        }
        field(100; Skipped; Integer)
        {
            Caption = 'Skipped';
            FieldClass = FlowField;
            CalcFormula = count("DOPSWHS Test Run Result" where("Run No." = field("Run No."), Status = const(Skipped)));
            Editable = false;
        }
        field(110; "Pending Manual"; Integer)
        {
            Caption = 'Pending Manual';
            FieldClass = FlowField;
            CalcFormula = count("DOPSWHS Test Run Result" where("Run No." = field("Run No."), Status = const(PendingManual)));
            Editable = false;
        }
        field(120; "Duration (sec)"; Decimal)
        {
            Caption = 'Duration (sec)';
            DecimalPlaces = 0 : 2;
            Editable = false;
        }
        field(130; Notes; Text[250]) { Caption = 'Notes'; }
        field(140; "Pass Rate %"; Decimal)
        {
            Caption = 'Pass Rate %';
            DecimalPlaces = 0 : 1;
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Run No.") { Clustered = true; }
        key(Started; "Started DateTime") { }
        key(EnvGroup; "Environment Code", "User Group Code") { }
        key(StatusKey; Status) { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Run No.", "Environment Code", "User Group Code", Status) { }
        fieldgroup(Brick; "Run No.", "Environment Code", Status, "Started DateTime") { }
    }

    trigger OnInsert()
    begin
        if "Run No." = '' then
            "Run No." := GenerateRunNo();
        if "Triggered By" = '' then
            "Triggered By" := CopyStr(UserId(), 1, MaxStrLen("Triggered By"));
        if "Started DateTime" = 0DT then
            "Started DateTime" := CurrentDateTime();
        if Status = Status::Open then
            Status := Status::Open;
    end;

    local procedure GenerateRunNo(): Code[20]
    var
        Existing: Record "DOPSWHS Test Run";
        Counter: Integer;
        Candidate: Code[20];
    begin
        Existing.Reset();
        Counter := Existing.Count() + 1;
        Candidate := StrSubstNo('TR-%1', Format(Counter, 6, '<Integer,6><Filler Character,0>'));
        while Existing.Get(Candidate) do begin
            Counter += 1;
            Candidate := StrSubstNo('TR-%1', Format(Counter, 6, '<Integer,6><Filler Character,0>'));
        end;
        exit(Candidate);
    end;
}
