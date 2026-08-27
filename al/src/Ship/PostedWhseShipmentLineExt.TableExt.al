tableextension 72405 "DOPSWHS Posted Whse Shpt Line" extends "Posted Whse. Shipment Line"
{
    fields
    {
        field(72405; "LP No."; Code[20])
        {
            Caption = 'LP No.';
            DataClassification = CustomerContent;
            TableRelation = "DOPSWHS LP Header"."No.";
        }
        field(72406; "SSCC"; Code[18])
        {
            Caption = 'SSCC';
            DataClassification = CustomerContent;
        }
    }
}
