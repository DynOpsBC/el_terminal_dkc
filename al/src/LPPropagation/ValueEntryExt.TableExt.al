tableextension 72427 "DOPSWHS Value Entry Ext" extends "Value Entry"
{
    fields
    {
        field(72429; "DOPSWHS LP No."; Code[20])
        {
            Caption = 'LP No.';
            DataClassification = CustomerContent;
            TableRelation = "DOPSWHS LP Header"."No.";
        }
    }
}
