tableextension 72404 "DOPSWHS Posted Whse Rcpt Line" extends "Posted Whse. Receipt Line"
{
    fields
    {
        field(72040; "LP No."; Code[20])
        {
            Caption = 'LP No.';
            DataClassification = CustomerContent;
            TableRelation = "DOPSWHS LP Header"."No.";
        }
    }
}
