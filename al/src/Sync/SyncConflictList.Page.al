page 72080 "DOPSWHS Sync Conflict List"
{
    PageType = List;
    SourceTable = "DOPSWHS Sync Conflict Buffer";
    Caption = 'Sync Conflicts';
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; }
                field("Device ID"; Rec."Device ID") { ApplicationArea = All; }
                field("Op Type"; Rec."Op Type") { ApplicationArea = All; }
                field("Doc No."; Rec."Doc No.") { ApplicationArea = All; }
                field(ETag; Rec.ETag) { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; }
                field("Created DateTime"; Rec."Created DateTime") { ApplicationArea = All; }
            }
        }
    }
}
