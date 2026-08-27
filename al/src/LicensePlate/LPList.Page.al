page 72070 "DOPSWHS LP List"
{
    Caption = 'License Plates';
    PageType = List;
    SourceTable = "DOPSWHS LP Header";
    SourceTableView = sorting(Status, "Location Code");
    CardPageId = "DOPSWHS LP Card";
    ApplicationArea = All;
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.") { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; }
                field("Location Code"; Rec."Location Code") { ApplicationArea = All; }
                field("Bin Code"; Rec."Bin Code") { ApplicationArea = All; }
                field("LP Template Code"; Rec."LP Template Code") { ApplicationArea = All; }
                field("Unit Type"; Rec."Unit Type") { ApplicationArea = All; }
                field("Parent LP No."; Rec."Parent LP No.") { ApplicationArea = All; }
                field(SSCC; Rec.SSCC) { ApplicationArea = All; }
                field("Assigned Document Type"; Rec."Assigned Document Type") { ApplicationArea = All; }
                field("Assigned Document No."; Rec."Assigned Document No.") { ApplicationArea = All; }
            }
        }
    }
}
