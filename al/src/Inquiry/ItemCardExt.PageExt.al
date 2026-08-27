pageextension 72300 "DOPSWHS Item Card Ext" extends "Item Card"
{
    layout
    {
        addlast(Item)
        {
            field("DOPSWHS Default LP Template"; Rec."DOPSWHS Default LP Template")
            {
                ApplicationArea = All;
            }
            field("DOPSWHS Default Print Rule"; Rec."DOPSWHS Default Print Rule")
            {
                ApplicationArea = All;
            }
        }
        addlast(FactBoxes)
        {
            part(DOPSWHSLPFactboxItem; "DOPSWHS LP Factbox Item")
            {
                ApplicationArea = All;
            }
        }
    }
}
