page 72248 "DOPSWHS Test Center"
{
    Caption = 'Test Center';
    PageType = CardPart;
    SourceTable = "DOPSWHS DynOps WMS Cue";
    RefreshOnActivate = true;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            cuegroup(TestMetrics)
            {
                Caption = 'Test Center';
                field("Total Test Cases"; Rec."Total Test Cases") { ApplicationArea = All; DrillDownPageId = "DOPSWHS Test Case List"; }
                field("Recent Test Runs"; Rec."Recent Test Runs") { ApplicationArea = All; DrillDownPageId = "DOPSWHS Test Run List"; }
                field("Last Run Pass Rate"; Rec."Last Run Pass Rate") { ApplicationArea = All; DrillDownPageId = "DOPSWHS Test Run List"; }
                field("Pending Manual Total"; Rec."Pending Manual Total") { ApplicationArea = All; DrillDownPageId = "DOPSWHS Test Run List"; }
                field("Recent Failures 7d"; Rec."Recent Failures 7d") { ApplicationArea = All; DrillDownPageId = "DOPSWHS Test Run List"; }
                field("Active Environments"; Rec."Active Environments") { ApplicationArea = All; DrillDownPageId = "DOPSWHS Test Environment List"; }
                field("Active User Groups"; Rec."Active User Groups") { ApplicationArea = All; DrillDownPageId = "DOPSWHS Test User Group List"; }
            }
        }
    }

    trigger OnOpenPage()
    begin
        if not Rec.Get('') then begin
            Rec.Init();
            Rec.Insert(true);
        end;
    end;
}
