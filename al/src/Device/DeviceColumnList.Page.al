page 72065 "DOPSWHS Device Column List"
{
    PageType = List;
    SourceTable = "DOPSWHS Device Column";
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'DOPSWHS Device Columns';

    layout { area(Content) { repeater(General) {
        field("Config Code"; Rec."Config Code") { ApplicationArea = All; }
        field("List Name"; Rec."List Name") { ApplicationArea = All; }
        field("Column Name"; Rec."Column Name") { ApplicationArea = All; }
        field(Width; Rec.Width) { ApplicationArea = All; }
        field("Sort Order"; Rec."Sort Order") { ApplicationArea = All; }
    } } }
}
