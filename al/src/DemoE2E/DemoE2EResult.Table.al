table 72279 "DOPSWHS Demo E2E Result"
{
    // One row per WMS-function × transaction (10 transactions × 10 functions = 100 rows).
    // Each row records what `DOPSWHS Demo E2E Suite` did — the production codeunit path it
    // exercised, the document/LP it produced, status, duration, and any captured error.
    // The mobile app would invoke the SAME codeunit methods via API page bound actions, so a
    // green row here is the AL-equivalent of a green mobile end-to-end run.
    Caption = 'Demo E2E Result';
    DataClassification = CustomerContent;
    Access = Public;
    LookupPageId = "DOPSWHS Demo E2E Results";
    DrillDownPageId = "DOPSWHS Demo E2E Results";

    fields
    {
        field(1; "Function Code"; Code[20]) { Caption = 'Function'; NotBlank = true; }
        field(2; "Transaction No."; Integer)  { Caption = 'Tx #'; }
        field(10; "Title"; Text[100])         { Caption = 'Title'; }
        field(20; "Status"; Enum "DOPSWHS Demo E2E Status") { Caption = 'Status'; }
        field(30; "Started DateTime"; DateTime) { Caption = 'Started'; Editable = false; }
        field(31; "Completed DateTime"; DateTime) { Caption = 'Completed'; Editable = false; }
        field(40; "Duration Ms"; Integer)     { Caption = 'Duration (ms)'; Editable = false; }
        field(50; "Source Document No."; Code[20]) { Caption = 'Source Doc'; }
        field(51; "LP No."; Code[20])         { Caption = 'LP No.'; TableRelation = "DOPSWHS LP Header"; }
        field(52; "Item No."; Code[20])       { Caption = 'Item No.'; TableRelation = Item; }
        field(53; "Location Code"; Code[10])  { Caption = 'Location Code'; TableRelation = Location; }
        field(54; "Quantity"; Decimal)        { Caption = 'Quantity'; DecimalPlaces = 0:5; }
        field(60; "Result Detail"; Text[2048]) { Caption = 'Detail'; }
        field(70; "Error Message"; Text[2048]) { Caption = 'Error Message'; }
        field(80; "Surrogate"; Boolean)       { Caption = 'AL Surrogate'; ToolTip = 'Set when the row was produced by AL (functionally equivalent to a mobile call) rather than via an actual HTTP/OData round-trip from the device.'; }
        field(90; "Last Run DateTime"; DateTime) { Caption = 'Last Run'; Editable = false; }
        field(91; "Run No."; Code[20])        { Caption = 'Run No.'; }
    }

    keys
    {
        key(PK; "Function Code", "Transaction No.") { Clustered = true; }
        key(Status; Status) { }
        key(Run; "Run No.") { }
    }

    procedure InitRow(NewFunction: Code[20]; NewTx: Integer; NewTitle: Text[100])
    begin
        if Get(NewFunction, NewTx) then
            exit;
        Init();
        "Function Code" := NewFunction;
        "Transaction No." := NewTx;
        Title := NewTitle;
        Status := Status::"Not Run";
        Insert();
    end;
}
