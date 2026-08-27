table 72005 "DOPSWHS Barcode Rule"
{
    Caption = 'DOPSWHS Barcode Rule';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Code"; Code[30]) { Caption = 'Code'; DataClassification = SystemMetadata; }
        field(2; Description; Text[100]) { Caption = 'Description'; }
        field(3; Symbology; Code[20]) { Caption = 'Symbology'; TableRelation = "DOPSWHS Barcode Symbology"; }
        field(4; Regex; Text[250]) { Caption = 'Regex'; }
        field(5; "Capture Map JSON"; Text[2048]) { Caption = 'Capture Map JSON'; }
        field(6; "Maps To"; Enum "DOPSWHS Barcode Map Target") { Caption = 'Maps To'; }
        field(7; "Order"; Integer) { Caption = 'Order'; }
        field(8; Active; Boolean) { Caption = 'Active'; InitValue = true; }
    }

    keys
    {
        key(PK; "Code") { Clustered = true; }
        key(OrderKey; Active, "Order") { }
    }
}
