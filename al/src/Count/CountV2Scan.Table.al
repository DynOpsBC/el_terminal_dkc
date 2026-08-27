table 72014 "DOPSWHS Count V2 Scan"
{
    Caption = 'Count V2 Scan';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Scan ID"; Guid) { Caption = 'Scan ID'; DataClassification = SystemMetadata; }
        field(10; "Sheet No."; Code[20]) { Caption = 'Sheet No.'; DataClassification = CustomerContent; TableRelation = "DOPSWHS Count Sheet Header"; }
        field(20; "Line No."; Integer) { Caption = 'Line No.'; DataClassification = CustomerContent; }
        field(30; "Counter Slot"; Integer) { Caption = 'Counter Slot'; DataClassification = CustomerContent; }
        field(40; Quantity; Decimal) { Caption = 'Quantity'; DataClassification = CustomerContent; }
        field(50; Reversed; Boolean) { Caption = 'Reversed'; DataClassification = CustomerContent; }
        field(60; "Created DateTime"; DateTime) { Caption = 'Created DateTime'; DataClassification = SystemMetadata; }
    }

    keys
    {
        key(PK; "Scan ID") { Clustered = true; }
        key(Sheet; "Sheet No.", "Created DateTime") { }
    }
}
