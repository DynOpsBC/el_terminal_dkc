page 72073 "DOPSWHS Short Pick Reason List"
{
    PageType = List;
    SourceTable = "DOPSWHS Short Pick Reason";
    Caption = 'Short Pick Reasons';
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Code"; Rec."Code") { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field(Default; Rec.Default) { ApplicationArea = All; }
                field("Allows Backorder"; Rec."Allows Backorder") { ApplicationArea = All; }
            }
        }
    }
}
