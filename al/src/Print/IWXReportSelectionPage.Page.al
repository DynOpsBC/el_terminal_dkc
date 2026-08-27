page 72076 "DOPSWHS IWX Report Selection"
{
    Caption = 'IWX Report Selection';
    PageType = List;
    SourceTable = "DOPSWHS IWX Report Selection";
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Code"; Rec."Code") { ApplicationArea = All; }
                field(Usage; Rec.Usage) { ApplicationArea = All; }
                field(Sequence; Rec.Sequence) { ApplicationArea = All; }
                field("Report ID"; Rec."Report ID") { ApplicationArea = All; }
                field("Use For Email"; Rec."Use For Email") { ApplicationArea = All; }
            }
        }
    }
}
