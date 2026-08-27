page 72079 "DOPSWHS Print Job Log"
{
    Caption = 'Print Job Log';
    PageType = List;
    SourceTable = "DOPSWHS Print Job Log";
    ApplicationArea = All;
    UsageCategory = History;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; }
                field("Job ID"; Rec."Job ID") { ApplicationArea = All; }
                field(EventType; Rec.EventType) { ApplicationArea = All; }
                field(Message; Rec.Message) { ApplicationArea = All; }
                field(DateTime; Rec.DateTime) { ApplicationArea = All; }
            }
        }
    }
}
