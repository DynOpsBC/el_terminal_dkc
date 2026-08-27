page 72340 "DOPSWHS Pack Session List"
{
    // Süpervizör görünümü: tüm paketleme oturumları ve durumları.
    PageType = List;
    Caption = 'Pack Sessions';
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "DOPSWHS Pack Session";
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    CardPageId = "DOPSWHS Pack Station";

    layout
    {
        area(Content)
        {
            repeater(Sessions)
            {
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; }
                field("Tote LP No."; Rec."Tote LP No.") { ApplicationArea = All; }
                field("Box LP No."; Rec."Box LP No.") { ApplicationArea = All; }
                field("Pick No."; Rec."Pick No.") { ApplicationArea = All; }
                field("Location Code"; Rec."Location Code") { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; }
                field("Orders Total"; Rec."Orders Total") { ApplicationArea = All; }
                field("Orders Completed"; Rec."Orders Completed") { ApplicationArea = All; }
                field("Created By User"; Rec."Created By User") { ApplicationArea = All; }
                field("Created DateTime"; Rec."Created DateTime") { ApplicationArea = All; }
                field("Completed DateTime"; Rec."Completed DateTime") { ApplicationArea = All; }
            }
        }
    }
}
