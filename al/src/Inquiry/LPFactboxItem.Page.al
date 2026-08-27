page 72077 "DOPSWHS LP Factbox Item"
{
    PageType = ListPart;
    SourceTable = "DOPSWHS LP Line";
    ApplicationArea = All;
    Caption = 'License Plates';

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("LP No."; Rec."LP No.") { ApplicationArea = All; Caption = 'LP No.'; }
                field("Item No."; Rec."Item No.") { ApplicationArea = All; Caption = 'Item No.'; }
                field(Quantity; Rec.Quantity) { ApplicationArea = All; Caption = 'Quantity'; }
                field("Lot No."; Rec."Lot No.") { ApplicationArea = All; Caption = 'Lot No.'; }
            }
        }
    }
}
