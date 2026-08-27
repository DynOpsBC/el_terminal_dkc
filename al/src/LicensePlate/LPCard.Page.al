page 72069 "DOPSWHS LP Card"
{
    Caption = 'License Plate';
    PageType = Card;
    SourceTable = "DOPSWHS LP Header";
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(General)
            {
                field("No."; Rec."No.") { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; }
                field("Location Code"; Rec."Location Code") { ApplicationArea = All; }
                field("Bin Code"; Rec."Bin Code") { ApplicationArea = All; }
                field("Parent LP No."; Rec."Parent LP No.") { ApplicationArea = All; }
                field("LP Template Code"; Rec."LP Template Code") { ApplicationArea = All; }
                field("Unit Type"; Rec."Unit Type") { ApplicationArea = All; }
                field(SSCC; Rec.SSCC) { ApplicationArea = All; }
            }
            part(Lines; "DOPSWHS LP Line ListPart")
            {
                ApplicationArea = All;
                SubPageLink = "LP No." = field("No.");
            }
            group(Tracking)
            {
                field("Assigned Document Type"; Rec."Assigned Document Type") { ApplicationArea = All; }
                field("Assigned Document No."; Rec."Assigned Document No.") { ApplicationArea = All; }
                field("Built By User"; Rec."Built By User") { ApplicationArea = All; }
                field("Built DateTime"; Rec."Built DateTime") { ApplicationArea = All; }
                field("Last Modified DateTime"; Rec."Last Modified DateTime") { ApplicationArea = All; }
                field("Hierarchy Label Print Count"; Rec."Hierarchy Label Print Count") { ApplicationArea = All; }
                field("Hierarchy Label Printed At"; Rec."Hierarchy Label Printed At") { ApplicationArea = All; }
                field("Hierarchy Reprint Reason"; Rec."Hierarchy Reprint Reason") { ApplicationArea = All; }
            }
            group(Dimensions)
            {
                field("Weight kg"; Rec."Weight kg") { ApplicationArea = All; }
                field("Length cm"; Rec."Length cm") { ApplicationArea = All; }
                field("Width cm"; Rec."Width cm") { ApplicationArea = All; }
                field("Height cm"; Rec."Height cm") { ApplicationArea = All; }
            }
            group(Notes)
            {
                field(NotesText; Rec.Notes) { ApplicationArea = All; MultiLine = true; Caption = 'Notes'; }
            }
        }
        area(FactBoxes)
        {
            part(NestTree; "DOPSWHS LP Factbox Bin")
            {
                ApplicationArea = All;
                SubPageLink = "Location Code" = field("Location Code"),
                              "Bin Code" = field("Bin Code");
            }
            part(MovementLedger; "DOPSWHS LP Movement Ledger")
            {
                ApplicationArea = All;
                SubPageLink = "LP No." = field("No.");
            }
        }
    }
}
