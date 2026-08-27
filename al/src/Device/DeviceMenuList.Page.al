page 72064 "DOPSWHS Device Menu List"
{
    PageType = List;
    SourceTable = "DOPSWHS Device Menu";
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'DOPSWHS Device Menu';

    layout { area(Content) { repeater(General) {
        field("Config Code"; Rec."Config Code") { ApplicationArea = All; }
        field("Application Module"; Rec."Application Module") { ApplicationArea = All; }
        field("Menu Item"; Rec."Menu Item") { ApplicationArea = All; }
        field("Sort Order"; Rec."Sort Order") { ApplicationArea = All; }
        field(Visible; Rec.Visible) { ApplicationArea = All; }
    } } }
}
