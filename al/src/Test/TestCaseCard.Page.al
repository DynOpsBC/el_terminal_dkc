page 72241 "DOPSWHS Test Case Card"
{
    Caption = 'Test Case';
    PageType = Card;
    SourceTable = "DOPSWHS Test Case";
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(General)
            {
                field("Code"; Rec."Code") { ApplicationArea = All; }
                field(Section; Rec.Section) { ApplicationArea = All; }
                field(Title; Rec.Title) { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; MultiLine = true; }
                field("Critical"; Rec."Critical") { ApplicationArea = All; }
                field(Active; Rec.Active) { ApplicationArea = All; }
                field("Sort Order"; Rec."Sort Order") { ApplicationArea = All; }
            }
            group(Automation)
            {
                Caption = 'Automation';
                field(Surface; Rec.Surface) { ApplicationArea = All; }
                field("Automation Type"; Rec."Automation Type") { ApplicationArea = All; }
                field("Automation Codeunit ID"; Rec."Automation Codeunit ID") { ApplicationArea = All; }
                field("Automation Procedure"; Rec."Automation Procedure") { ApplicationArea = All; }
                field("Estimated Seconds"; Rec."Estimated Seconds") { ApplicationArea = All; }
            }
        }
    }
}
