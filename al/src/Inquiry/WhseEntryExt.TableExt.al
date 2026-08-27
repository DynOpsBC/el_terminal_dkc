tableextension 72402 "DOPSWHS Whse Entry Ext" extends "Warehouse Entry"
{
    fields
    {
        field(72402; "DOPSWHS LP No."; Code[20])
        {
            Caption = 'LP No.';
            DataClassification = CustomerContent;
            TableRelation = "DOPSWHS LP Header";
        }
    }
}
