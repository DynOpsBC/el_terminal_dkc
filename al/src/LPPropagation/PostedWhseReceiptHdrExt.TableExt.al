tableextension 72423 "DOPSWHS Posted Whse Rcpt Hdr" extends "Posted Whse. Receipt Header"
{
    fields
    {
        field(72423; "DOPSWHS LP No."; Code[20])
        {
            Caption = 'LP No.';
            DataClassification = CustomerContent;
            TableRelation = "DOPSWHS LP Header"."No.";
        }
    }
}
