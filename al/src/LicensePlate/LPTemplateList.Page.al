page 72071 "DOPSWHS LP Template List"
{
    Caption = 'LP Templates';
    PageType = List;
    SourceTable = "DOPSWHS LP Template";
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Code"; Rec."Code") { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field("Default Tare Weight kg"; Rec."Default Tare Weight kg") { ApplicationArea = All; }
                field("Default Length cm"; Rec."Default Length cm") { ApplicationArea = All; }
                field("Default Width cm"; Rec."Default Width cm") { ApplicationArea = All; }
                field("Default Height cm"; Rec."Default Height cm") { ApplicationArea = All; }
                field("Max Weight kg"; Rec."Max Weight kg") { ApplicationArea = All; }
                field("Label Report ID"; Rec."Label Report ID") { ApplicationArea = All; }
                field("No. Series"; Rec."No. Series") { ApplicationArea = All; }
                field("Allow Mixed Items"; Rec."Allow Mixed Items") { ApplicationArea = All; }
                field("Allow Mixed Lots"; Rec."Allow Mixed Lots") { ApplicationArea = All; }
                field("Unit Type"; Rec."Unit Type") { ApplicationArea = All; }
            }
        }
    }
}
