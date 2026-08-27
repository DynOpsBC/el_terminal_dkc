tableextension 72400 "DOPSWHS Item Ext" extends Item
{
    fields
    {
        field(72400; "DOPSWHS Default LP Template"; Code[20])
        {
            Caption = 'Default LP Template Code';
            DataClassification = CustomerContent;
        }
        field(72401; "DOPSWHS Default Print Rule"; Code[20])
        {
            Caption = 'Default Print Rule Code';
            DataClassification = CustomerContent;
        }
    }
}
