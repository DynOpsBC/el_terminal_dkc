page 72277 "DOPSWHS App User Roles"
{
    PageType = ListPart;
    SourceTable = "DOPSWHS App User Role";
    Caption = 'Roles';
    ApplicationArea = All;
    AutoSplitKey = true;
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Role Code"; Rec."Role Code") { ApplicationArea = All; }
                field("Priority"; Rec.Priority) { ApplicationArea = All; }
                field("Disabled"; Rec.Disabled) { ApplicationArea = All; }
                field("Assigned DateTime"; Rec."Assigned DateTime") { ApplicationArea = All; Editable = false; }
                field("Assigned By"; Rec."Assigned By") { ApplicationArea = All; Editable = false; }
            }
        }
    }
}
