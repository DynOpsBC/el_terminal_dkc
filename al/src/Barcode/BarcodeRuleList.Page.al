page 72067 "DOPSWHS Barcode Rule List"
{
    PageType = List;
    SourceTable = "DOPSWHS Barcode Rule";
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'DOPSWHS Barcode Rules';

    layout { area(Content) { repeater(General) {
        field("Code"; Rec."Code") { ApplicationArea = All; }
        field(Description; Rec.Description) { ApplicationArea = All; }
        field(Symbology; Rec.Symbology) { ApplicationArea = All; }
        field(Regex; Rec.Regex) { ApplicationArea = All; }
        field("Capture Map JSON"; Rec."Capture Map JSON") { ApplicationArea = All; }
        field("Maps To"; Rec."Maps To") { ApplicationArea = All; }
        field("Order"; Rec."Order") { ApplicationArea = All; }
        field(Active; Rec.Active) { ApplicationArea = All; }
    } } }
}
