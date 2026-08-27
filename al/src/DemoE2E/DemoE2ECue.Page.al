page 72282 "DOPSWHS Demo E2E Cue"
{
    PageType = CardPart;
    SourceTable = "DOPSWHS Demo E2E Cue";
    Caption = 'E2E Stats';
    RefreshOnActivate = true;

    layout
    {
        area(Content)
        {
            cuegroup(Counts)
            {
                Caption = 'Demo E2E Status';

                field("Total"; Rec.Total) { ApplicationArea = All; Caption = 'Total'; }
                field("Passed"; Rec.Passed) { ApplicationArea = All; Caption = 'Passed'; Style = Favorable; }
                field("Failed"; Rec.Failed) { ApplicationArea = All; Caption = 'Failed'; Style = Unfavorable; }
                field("Running"; Rec.Running) { ApplicationArea = All; Caption = 'Running'; Style = Attention; }
                field("Not Run"; Rec."Not Run") { ApplicationArea = All; Caption = 'Not Run'; Style = Subordinate; }
            }
        }
    }

    trigger OnOpenPage()
    begin
        if not Rec.Get('') then begin
            Rec.Init();
            Rec."Primary Key" := '';
            Rec.Insert();
        end;
    end;
}
