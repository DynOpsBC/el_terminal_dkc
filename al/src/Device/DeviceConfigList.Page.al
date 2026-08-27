page 72063 "DOPSWHS Device Config List"
{
    PageType = List;
    SourceTable = "DOPSWHS Device Configuration";
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'DOPSWHS Device Configurations';
    CardPageId = "DOPSWHS Device Config Card";

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Code"; Rec."Code") { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field("Location Code"; Rec."Location Code") { ApplicationArea = All; }
                field("Login Mode"; Rec."Login Mode") { ApplicationArea = All; }
                field("Max List Rows"; Rec."Max List Rows") { ApplicationArea = All; }
                field("Scan Beep"; Rec."Scan Beep") { ApplicationArea = All; }
            }
        }
    }
}
