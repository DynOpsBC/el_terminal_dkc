page 72078 "DOPSWHS LP Factbox Bin"
{
    PageType = ListPart;
    SourceTable = "DOPSWHS LP Header";
    ApplicationArea = All;
    Caption = 'License Plates';

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.") { ApplicationArea = All; Caption = 'LP No.'; }
                field("Bin Code"; Rec."Bin Code") { ApplicationArea = All; Caption = 'Bin Code'; }
                field("LP Template Code"; Rec."LP Template Code") { ApplicationArea = All; Caption = 'Template'; }
                field(Status; Rec.Status) { ApplicationArea = All; Caption = 'Status'; }
                field("Line Count"; Rec."Line Count") { ApplicationArea = All; Caption = 'Line Count'; }
                field("Total Quantity"; Rec."Total Quantity") { ApplicationArea = All; Caption = 'Total Quantity'; }
                field(Contents; ContentsSummary)
                {
                    ApplicationArea = All;
                    Caption = 'Contents';
                    Editable = false;
                    ToolTip = 'Shows item, quantity and lot information stored in this LP.';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetFilter(Status, '%1|%2|%3', Rec.Status::Open, Rec.Status::Built, Rec.Status::Assigned);
    end;

    trigger OnAfterGetRecord()
    var
        BinContentSubscriber: Codeunit "DOPSWHS Bin Content Subscriber";
    begin
        Rec.CalcFields("Line Count", "Total Quantity");
        ContentsSummary := BinContentSubscriber.GetLPContentSummary(Rec."No.");
    end;

    var
        ContentsSummary: Text[250];
}
