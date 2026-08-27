tableextension 72420 "DOPSWHS Whse Shpt Hdr Ext" extends "Warehouse Shipment Header"
{
    fields
    {
        field(72420; "DOPSWHS LP No."; Code[20])
        {
            Caption = 'LP No.';
            DataClassification = CustomerContent;
            TableRelation = "DOPSWHS LP Header"."No.";
        }
    }
}
