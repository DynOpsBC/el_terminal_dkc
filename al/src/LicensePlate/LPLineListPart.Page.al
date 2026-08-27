page 72483 "DOPSWHS LP Line ListPart"
{
    Caption = 'LP Lines';
    PageType = ListPart;
    SourceTable = "DOPSWHS LP Line";
    ApplicationArea = All;
    AutoSplitKey = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Line No."; Rec."Line No.") { ApplicationArea = All; }
                field("Item No."; Rec."Item No.") { ApplicationArea = All; }
                field("Variant Code"; Rec."Variant Code") { ApplicationArea = All; }
                field("Unit of Measure"; Rec."Unit of Measure") { ApplicationArea = All; }
                field(Quantity; Rec.Quantity) { ApplicationArea = All; }
                field("Lot No."; Rec."Lot No.") { ApplicationArea = All; }
                field("Serial No."; Rec."Serial No.") { ApplicationArea = All; }
                field("Package No."; Rec."Package No.") { ApplicationArea = All; }
                field("Child LP No."; Rec."Child LP No.") { ApplicationArea = All; }
                field("Expiration Date"; Rec."Expiration Date") { ApplicationArea = All; }
            }
        }
    }
}
