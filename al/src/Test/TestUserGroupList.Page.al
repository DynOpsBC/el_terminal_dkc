page 72246 "DOPSWHS Test User Group List"
{
    Caption = 'Test User Groups';
    PageType = List;
    SourceTable = "DOPSWHS Test User Group";
    ApplicationArea = All;
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(Groups)
            {
                field("Code"; Rec."Code") { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field(Category; Rec.Category) { ApplicationArea = All; }
                field("Member Count"; Rec."Member Count") { ApplicationArea = All; }
                field(Active; Rec.Active) { ApplicationArea = All; }
                field(Notes; Rec.Notes) { ApplicationArea = All; }
            }
        }
    }
}
