tableextension 72425 "DOPSWHS Sales Shpt Line Ext" extends "Sales Shipment Line"
{
    fields
    {
        field(72426; "DOPSWHS LP No."; Code[20])
        {
            Caption = 'LP No.';
            DataClassification = CustomerContent;
            TableRelation = "DOPSWHS LP Header"."No.";
        }
        field(72427; "DOPSWHS SSCC"; Code[18])
        {
            Caption = 'SSCC';
            DataClassification = CustomerContent;
        }
    }
}
