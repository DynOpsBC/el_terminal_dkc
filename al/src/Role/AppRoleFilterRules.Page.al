page 72276 "DOPSWHS App Role Filter Rules"
{
    PageType = ListPart;
    SourceTable = "DOPSWHS App Role Filter Rule";
    Caption = 'Filter Rules';
    ApplicationArea = All;
    AutoSplitKey = true;
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Entity"; Rec.Entity) { ApplicationArea = All; }
                field("Field No."; Rec."Field No.") { ApplicationArea = All; }
                field("Field Name Hint"; Rec."Field Name Hint") { ApplicationArea = All; }
                field("Filter Expression"; Rec."Filter Expression") { ApplicationArea = All; }
                field("Combine Mode"; Rec."Combine Mode") { ApplicationArea = All; }
                field("Apply To Lines"; Rec."Apply To Lines") { ApplicationArea = All; }
                field("Disabled"; Rec.Disabled) { ApplicationArea = All; }
                field("Description"; Rec.Description) { ApplicationArea = All; }
            }
        }
    }
}
