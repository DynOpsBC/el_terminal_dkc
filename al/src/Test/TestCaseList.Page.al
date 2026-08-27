page 72240 "DOPSWHS Test Case List"
{
    Caption = 'Test Case Catalog';
    PageType = List;
    SourceTable = "DOPSWHS Test Case";
    ApplicationArea = All;
    UsageCategory = Lists;
    CardPageId = "DOPSWHS Test Case Card";

    layout
    {
        area(Content)
        {
            repeater(Cases)
            {
                field("Code"; Rec."Code") { ApplicationArea = All; }
                field(Section; Rec.Section) { ApplicationArea = All; }
                field(Title; Rec.Title) { ApplicationArea = All; }
                field(Surface; Rec.Surface) { ApplicationArea = All; }
                field("Automation Type"; Rec."Automation Type") { ApplicationArea = All; }
                field("Automation Codeunit ID"; Rec."Automation Codeunit ID") { ApplicationArea = All; Visible = false; }
                field("Automation Procedure"; Rec."Automation Procedure") { ApplicationArea = All; Visible = false; }
                field("Estimated Seconds"; Rec."Estimated Seconds") { ApplicationArea = All; }
                field("Critical"; Rec."Critical") { ApplicationArea = All; }
                field(Active; Rec.Active) { ApplicationArea = All; }
            }
        }
    }
}
