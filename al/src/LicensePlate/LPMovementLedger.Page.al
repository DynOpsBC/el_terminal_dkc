page 72072 "DOPSWHS LP Movement Ledger"
{
    Caption = 'LP Movement Ledger';
    PageType = List;
    SourceTable = "DOPSWHS LP Movement Ledger";
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
                field("LP No."; Rec."LP No.") { ApplicationArea = All; }
                field(Action; Rec.Action) { ApplicationArea = All; }
                field("From Bin"; Rec."From Bin") { ApplicationArea = All; }
                field("To Bin"; Rec."To Bin") { ApplicationArea = All; }
                field(Quantity; Rec.Quantity) { ApplicationArea = All; }
                field("Item No."; Rec."Item No.") { ApplicationArea = All; }
                field("Lot Serial"; Rec."Lot Serial") { ApplicationArea = All; }
                field("User ID"; Rec."User ID") { ApplicationArea = All; }
                field("Device ID"; Rec."Device ID") { ApplicationArea = All; }
                field(DateTime; Rec.DateTime) { ApplicationArea = All; }
                field("Related Document"; Rec."Related Document") { ApplicationArea = All; }
            }
        }
    }
}
