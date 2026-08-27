tableextension 72426 "DOPSWHS Item Ledger Entry Ext" extends "Item Ledger Entry"
{
    fields
    {
        field(72428; "DOPSWHS LP No."; Code[20])
        {
            Caption = 'LP No.';
            DataClassification = CustomerContent;
            TableRelation = "DOPSWHS LP Header"."No.";
        }
    }
}
