page 72480 "DOPSWHS Prod LP Factbox"
{
    PageType = ListPart;
    SourceTable = "DOPSWHS LP Header";
    ApplicationArea = All;
    Caption = 'Production LPs';

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.") { ApplicationArea = All; Caption = 'LP No.'; }
                field("Bin Code"; Rec."Bin Code") { ApplicationArea = All; Caption = 'Bin Code'; }
                field("LP Template Code"; Rec."LP Template Code") { ApplicationArea = All; Caption = 'Template'; }
                field(Status; Rec.Status) { ApplicationArea = All; Caption = 'Status'; }
                field("Assigned Document Type"; Rec."Assigned Document Type") { ApplicationArea = All; Caption = 'Flow'; }
            }
        }
    }
}
