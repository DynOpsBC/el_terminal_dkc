tableextension 72422 "DOPSWHS Whse Rcpt Hdr Ext" extends "Warehouse Receipt Header"
{
    fields
    {
        field(72422; "DOPSWHS LP No."; Code[20])
        {
            Caption = 'LP No.';
            DataClassification = CustomerContent;
            TableRelation = "DOPSWHS LP Header"."No.";
        }
    }
}
