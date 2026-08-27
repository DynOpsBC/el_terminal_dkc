page 72245 "DOPSWHS Test Environment List"
{
    Caption = 'Test Environments';
    PageType = List;
    SourceTable = "DOPSWHS Test Environment";
    ApplicationArea = All;
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(Envs)
            {
                field("Code"; Rec."Code") { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field(Category; Rec.Category) { ApplicationArea = All; }
                field("BC Tenant ID"; Rec."BC Tenant ID") { ApplicationArea = All; }
                field("BC Environment Name"; Rec."BC Environment Name") { ApplicationArea = All; }
                field("BC Company Name"; Rec."BC Company Name") { ApplicationArea = All; }
                field(Active; Rec.Active) { ApplicationArea = All; }
                field("Sort Order"; Rec."Sort Order") { ApplicationArea = All; Visible = false; }
                field(Notes; Rec.Notes) { ApplicationArea = All; }
            }
        }
    }
}
