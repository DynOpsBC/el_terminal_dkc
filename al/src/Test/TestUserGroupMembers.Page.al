page 72247 "DOPSWHS Test User Grp Members"
{
    Caption = 'Test User Group Members';
    PageType = ListPart;
    SourceTable = "DOPSWHS Test User Group Member";
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Members)
            {
                field("User ID"; Rec."User ID") { ApplicationArea = All; }
                field(Role; Rec.Role) { ApplicationArea = All; }
                field("Added DateTime"; Rec."Added DateTime") { ApplicationArea = All; Editable = false; }
            }
        }
    }
}
