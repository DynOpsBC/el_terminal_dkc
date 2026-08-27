tableextension 72421 "DOPSWHS Posted Whse Shpt Hdr" extends "Posted Whse. Shipment Header"
{
    fields
    {
        field(72421; "DOPSWHS LP No."; Code[20])
        {
            Caption = 'LP No.';
            DataClassification = CustomerContent;
            TableRelation = "DOPSWHS LP Header"."No.";
        }
    }
}
