page 72062 "DOPSWHS Device Config Card"
{
    PageType = Card;
    SourceTable = "DOPSWHS Device Configuration";
    ApplicationArea = All;
    Caption = 'DOPSWHS Device Configuration';

    layout
    {
        area(Content)
        {
            group(General)
            {
                field("Code"; Rec."Code") { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field("Location Code"; Rec."Location Code") { ApplicationArea = All; }
                field("Login Mode"; Rec."Login Mode") { ApplicationArea = All; }
            }
            group(Behavior)
            {
                field("Assign Document On Open"; Rec."Assign Document On Open") { ApplicationArea = All; }
                field("Ignore Bins"; Rec."Ignore Bins") { ApplicationArea = All; }
                field("LP Usage Default Action"; Rec."LP Usage Default Action") { ApplicationArea = All; }
                field("Max List Rows"; Rec."Max List Rows") { ApplicationArea = All; }
                field("Scan Beep"; Rec."Scan Beep") { ApplicationArea = All; }
                field("Auto Post"; Rec."Auto Post") { ApplicationArea = All; }
                field("Print Channel"; Rec."Print Channel") { ApplicationArea = All; }
            }
            part(Menu; "DOPSWHS Device Menu List")
            {
                ApplicationArea = All;
                SubPageLink = "Config Code" = field("Code");
            }
            part(Columns; "DOPSWHS Device Column List")
            {
                ApplicationArea = All;
                SubPageLink = "Config Code" = field("Code");
            }
        }
    }
}
