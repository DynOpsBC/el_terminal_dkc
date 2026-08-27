page 72242 "DOPSWHS Test Run List"
{
    Caption = 'Test Runs';
    PageType = List;
    SourceTable = "DOPSWHS Test Run";
    ApplicationArea = All;
    UsageCategory = Lists;
    CardPageId = "DOPSWHS Test Run Card";
    SourceTableView = sorting("Started DateTime") order(descending);

    layout
    {
        area(Content)
        {
            repeater(Runs)
            {
                field("Run No."; Rec."Run No.") { ApplicationArea = All; }
                field("Environment Code"; Rec."Environment Code") { ApplicationArea = All; }
                field("User Group Code"; Rec."User Group Code") { ApplicationArea = All; }
                field("Started DateTime"; Rec."Started DateTime") { ApplicationArea = All; }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    StyleExpr = StatusStyle;
                }
                field("Total Cases"; Rec."Total Cases") { ApplicationArea = All; }
                field(Passed; Rec.Passed) { ApplicationArea = All; }
                field(Failed; Rec.Failed) { ApplicationArea = All; }
                field("Pending Manual"; Rec."Pending Manual") { ApplicationArea = All; }
                field(Skipped; Rec.Skipped) { ApplicationArea = All; }
                field("Pass Rate %"; Rec."Pass Rate %") { ApplicationArea = All; }
                field("Duration (sec)"; Rec."Duration (sec)") { ApplicationArea = All; }
                field("Triggered By"; Rec."Triggered By") { ApplicationArea = All; }
                field(Notes; Rec.Notes) { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(NewRun)
            {
                Caption = '+ New Test Run';
                ToolTip = 'Yeni bir Test Run başlat.';
                ApplicationArea = All;
                Image = NewDocument;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                trigger OnAction()
                begin
                    NewTestRun();
                end;
            }
        }
    }

    var
        StatusStyle: Text;

    trigger OnAfterGetRecord()
    begin
        case Rec.Status of
            Rec.Status::Completed:
                StatusStyle := 'Favorable';
            Rec.Status::Failed, Rec.Status::PartialPass:
                StatusStyle := 'Unfavorable';
            Rec.Status::Running:
                StatusStyle := 'Attention';
            else
                StatusStyle := 'Standard';
        end;
    end;

    local procedure NewTestRun()
    var
        Runner: Codeunit "DOPSWHS Test Runner";
        EnvCode: Code[20];
        GroupCode: Code[20];
        RunNo: Code[20];
        NewRunMsg: Label 'Yeni Test Run %1 oluşturuldu (Env=%2, Group=%3). "Start Run" ile çalıştırın.';
    begin
        EnvCode := 'TEST';
        GroupCode := 'QA-TEAM';
        RunNo := Runner.CreateNewRun(EnvCode, GroupCode, '');
        Message(NewRunMsg, RunNo, EnvCode, GroupCode);
        CurrPage.Update(false);
    end;
}
