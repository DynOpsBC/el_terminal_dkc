page 72244 "DOPSWHS Test Run Result Lines"
{
    Caption = 'Test Run Result Lines';
    PageType = ListPart;
    SourceTable = "DOPSWHS Test Run Result";
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Test Case Code"; Rec."Test Case Code") { ApplicationArea = All; }
                field(Section; Rec.Section) { ApplicationArea = All; }
                field(Title; Rec.Title) { ApplicationArea = All; }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    StyleExpr = StatusStyle;
                }
                field("Automation Type"; Rec."Automation Type") { ApplicationArea = All; }
                field("Surrogate Used"; Rec."Surrogate Used") { ApplicationArea = All; }
                field("Duration Ms"; Rec."Duration Ms") { ApplicationArea = All; }
                field("Error Message"; Rec."Error Message") { ApplicationArea = All; }
                field("Manual Verified By"; Rec."Manual Verified By") { ApplicationArea = All; Visible = false; }
                field("Manual Verified DateTime"; Rec."Manual Verified DateTime") { ApplicationArea = All; Visible = false; }
                field(Notes; Rec.Notes) { ApplicationArea = All; }
                field("Started DateTime"; Rec."Started DateTime") { ApplicationArea = All; Visible = false; }
                field("Completed DateTime"; Rec."Completed DateTime") { ApplicationArea = All; Visible = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(MarkPassed)
            {
                Caption = 'Mark Passed';
                ToolTip = 'Manuel olarak doğrulanmış case için Passed işaretle.';
                ApplicationArea = All;
                Image = Approve;
                trigger OnAction()
                var
                    Helper: Codeunit "DOPSWHS Test Result Helper";
                    Notes: Text;
                begin
                    Helper.MarkPassedManually(Rec, '');
                    CurrPage.Update(false);
                end;
            }
            action(MarkFailed)
            {
                Caption = 'Mark Failed';
                ToolTip = 'Manuel olarak doğrulanmış case için Failed işaretle.';
                ApplicationArea = All;
                Image = Reject;
                trigger OnAction()
                var
                    Helper: Codeunit "DOPSWHS Test Result Helper";
                begin
                    Helper.MarkFailedManually(Rec, '');
                    CurrPage.Update(false);
                end;
            }
            action(RunCase)
            {
                Caption = 'Run This Case';
                ToolTip = 'Bu caseyi tek basina yeniden calistir.';
                ApplicationArea = All;
                Image = Start;
                trigger OnAction()
                var
                    Runner: Codeunit "DOPSWHS Test Runner";
                begin
                    Runner.ExecuteSingleCase(Rec."Run No.", Rec."Test Case Code");
                    CurrPage.Update(false);
                end;
            }
        }
    }

    var
        StatusStyle: Text;

    trigger OnAfterGetRecord()
    begin
        case Rec.Status of
            Rec.Status::Passed:
                StatusStyle := 'Favorable';
            Rec.Status::Failed:
                StatusStyle := 'Unfavorable';
            Rec.Status::PendingManual:
                StatusStyle := 'Attention';
            Rec.Status::Skipped:
                StatusStyle := 'Subordinate';
            else
                StatusStyle := 'Standard';
        end;
    end;
}
