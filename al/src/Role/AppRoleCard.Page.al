page 72275 "DOPSWHS App Role Card"
{
    PageType = Card;
    SourceTable = "DOPSWHS App Role";
    Caption = 'WMS App Role';
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("Code"; Rec.Code) { ApplicationArea = All; }
                field("Description"; Rec.Description) { ApplicationArea = All; }
                field("Active"; Rec.Active) { ApplicationArea = All; }
                field("Sort Order"; Rec."Sort Order") { ApplicationArea = All; }
                field("Is System"; Rec."Is System") { ApplicationArea = All; }
                field("Notes"; Rec.Notes) { ApplicationArea = All; MultiLine = true; }
            }
            group(Visibility)
            {
                Caption = 'Mobile UI Visibility';
                field("Hide Test Tools"; Rec."Hide Test Tools") { ApplicationArea = All; }
                field("Hide Admin Tools"; Rec."Hide Admin Tools") { ApplicationArea = All; }
            }
            part(FilterRules; "DOPSWHS App Role Filter Rules")
            {
                Caption = 'Filter Rules';
                ApplicationArea = All;
                SubPageLink = "Role Code" = field(Code);
                UpdatePropagation = Both;
            }
        }
    }
}
