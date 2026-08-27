table 72016 "DOPSWHS Count Sheet Header"
{
    Caption = 'Count Sheet';
    DataClassification = CustomerContent;
    LookupPageId = "DOPSWHS Count Sheet List";
    DrillDownPageId = "DOPSWHS Count Sheet List";

    fields
    {
        field(1; "No."; Code[20]) { Caption = 'No.'; DataClassification = CustomerContent; }
        field(10; "Location Code"; Code[10]) { Caption = 'Location Code'; DataClassification = CustomerContent; TableRelation = Location; }
        field(20; Mode; Enum "DOPSWHS Count Mode") { Caption = 'Mode'; DataClassification = CustomerContent; }
        field(30; Status; Option)
        {
            Caption = 'Status';
            DataClassification = CustomerContent;
            OptionMembers = Open,InProgress,Posted;
            OptionCaption = 'Open,In Progress,Posted';
        }
        field(40; "Created DateTime"; DateTime) { Caption = 'Created DateTime'; DataClassification = CustomerContent; Editable = false; }
        field(50; "Posted DateTime"; DateTime) { Caption = 'Posted DateTime'; DataClassification = CustomerContent; Editable = false; }
        field(60; "Source Phys. Inv. Journal Batch"; Code[10])
        {
            Caption = 'Source Phys. Inv. Journal Batch';
            DataClassification = CustomerContent;
            TableRelation = "Item Journal Batch".Name where("Journal Template Name" = const('PHYS. INV.'));
        }
        field(70; "V2 Scan Mode"; Boolean)
        {
            Caption = 'V2 Scan Mode';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }

    keys
    {
        key(PK; "No.") { Clustered = true; }
        key(LocationStatus; "Location Code", Status) { }
        key(Created; "Created DateTime") { }
    }

    trigger OnInsert()
    var
        Setup: Record "DOPSWHS Setup";
        NoSeries: Codeunit "No. Series";
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
    begin
        if "No." = '' then begin
            if Setup.Get('') then
                if Setup."Count Sheet No. Series" <> '' then
                    "No." := NoSeries.GetNextNo(Setup."Count Sheet No. Series");
            if "No." = '' then
                "No." := CopyStr('CNT-' + Format(CurrentDateTime(), 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>'), 1, MaxStrLen("No."));
        end;
        if "Created DateTime" = 0DT then
            "Created DateTime" := CurrentDateTime();
        if "Source Phys. Inv. Journal Batch" = '' then
            "Source Phys. Inv. Journal Batch" := CountMgmt.EnsurePhysInvBatch("No.");
    end;

    trigger OnModify()
    begin
        // A posted count is an immutable inventory document.  Keep the guard in
        // the table as well as the pages/API so alternate clients cannot bypass it.
        if xRec.Status = xRec.Status::Posted then
            Error(PostedSheetImmutableErr, "No.");
    end;

    trigger OnDelete()
    begin
        if Status = Status::Posted then
            Error(PostedSheetImmutableErr, "No.");
    end;

    trigger OnRename()
    begin
        if Status = Status::Posted then
            Error(PostedSheetImmutableErr, "No.");
    end;

    var
        PostedSheetImmutableErr: Label 'Posted count sheet %1 cannot be changed or deleted.';
}
