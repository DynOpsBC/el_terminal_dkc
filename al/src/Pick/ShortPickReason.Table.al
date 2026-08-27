table 72015 "DOPSWHS Short Pick Reason"
{
    Caption = 'DOPSWHS Short Pick Reason';
    DataClassification = CustomerContent;
    LookupPageId = "DOPSWHS Short Pick Reason List";
    DrillDownPageId = "DOPSWHS Short Pick Reason List";

    fields
    {
        field(1; "Code"; Code[20]) { Caption = 'Code'; DataClassification = CustomerContent; }
        field(2; Description; Text[100]) { Caption = 'Description'; DataClassification = CustomerContent; }
        field(10; Default; Boolean) { Caption = 'Default'; DataClassification = CustomerContent; }
        field(20; "Allows Backorder"; Boolean) { Caption = 'Allows Backorder'; DataClassification = CustomerContent; }
    }

    keys
    {
        key(PK; "Code") { Clustered = true; }
        key(Default; Default) { }
    }
}
