tableextension 72424 "DOPSWHS Purch Rcpt Line Ext" extends "Purch. Rcpt. Line"
{
    fields
    {
        field(72424; "DOPSWHS LP No."; Code[20])
        {
            Caption = 'LP No.';
            DataClassification = CustomerContent;
            TableRelation = "DOPSWHS LP Header"."No.";
        }
        field(72425; "DOPSWHS SSCC"; Code[18])
        {
            Caption = 'SSCC';
            DataClassification = CustomerContent;
        }
    }
}
