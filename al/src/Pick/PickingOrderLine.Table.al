table 72353 "DOPSWHS Picking Order Line"
{
    Caption = 'Picking Order Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Header Entry No."; Integer) { Caption = 'Header Entry No.'; TableRelation = "DOPSWHS Picking Order Header"; DataClassification = CustomerContent; }
        field(2; "Line No."; Integer) { Caption = 'Line No.'; DataClassification = CustomerContent; }
        field(10; "Sales Order No."; Code[20])
        {
            Caption = 'Sales Order No.';
            TableRelation = "Sales Header"."No." where("Document Type" = const(Order));
            DataClassification = CustomerContent;
        }
        field(20; "Sell-to Customer No."; Code[20]) { Caption = 'Sell-to Customer No.'; Editable = false; DataClassification = CustomerContent; }
        field(21; "Sell-to Customer Name"; Text[100]) { Caption = 'Sell-to Customer Name'; Editable = false; DataClassification = CustomerContent; }
        field(30; "Location Code"; Code[10]) { Caption = 'Location Code'; Editable = false; DataClassification = CustomerContent; }
        field(40; "Shipment Date"; Date) { Caption = 'Shipment Date'; Editable = false; DataClassification = CustomerContent; }
        field(50; "Item Line Count"; Integer) { Caption = 'Item Line Count'; Editable = false; DataClassification = CustomerContent; }
        field(60; "Total Quantity"; Decimal) { Caption = 'Total Quantity'; Editable = false; DecimalPlaces = 0 : 5; DataClassification = CustomerContent; }
    }

    keys
    {
        key(PK; "Header Entry No.", "Line No.") { Clustered = true; }
        key(OrderKey; "Sales Order No.") { }
    }
}
