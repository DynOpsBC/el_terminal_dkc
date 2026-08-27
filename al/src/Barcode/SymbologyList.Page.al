page 72068 "DOPSWHS Symbology List"
{
    PageType = List;
    SourceTable = "DOPSWHS Barcode Symbology";
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'DOPSWHS Barcode Symbologies';

    layout { area(Content) { repeater(General) {
        field("Code"; Rec."Code") { ApplicationArea = All; }
        field(Description; Rec.Description) { ApplicationArea = All; }
        field(Format; Rec.Format) { ApplicationArea = All; }
        field("Min Length"; Rec."Min Length") { ApplicationArea = All; }
        field("Max Length"; Rec."Max Length") { ApplicationArea = All; }
    } } }
}
