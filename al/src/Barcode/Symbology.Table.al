table 72006 "DOPSWHS Barcode Symbology"
{
    Caption = 'DOPSWHS Barcode Symbology';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Code"; Code[20]) { Caption = 'Code'; DataClassification = SystemMetadata; }
        field(2; Description; Text[100]) { Caption = 'Description'; }
        field(3; Format; Enum "DOPSWHS Symbology") { Caption = 'Format'; }
        field(4; "Min Length"; Integer) { Caption = 'Min Length'; MinValue = 0; }
        field(5; "Max Length"; Integer) { Caption = 'Max Length'; MinValue = 0; }
    }

    keys { key(PK; "Code") { Clustered = true; } }
}
