page 72243 "DOPSWHS Test Run Card"
{
    Caption = 'Test Run';
    PageType = Card;
    SourceTable = "DOPSWHS Test Run";
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(General)
            {
                field("Run No."; Rec."Run No.") { ApplicationArea = All; Editable = false; }
                field("Environment Code"; Rec."Environment Code") { ApplicationArea = All; }
                field("User Group Code"; Rec."User Group Code") { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; Editable = false; }
                field("Triggered By"; Rec."Triggered By") { ApplicationArea = All; Editable = false; }
                field("Started DateTime"; Rec."Started DateTime") { ApplicationArea = All; Editable = false; }
                field("Completed DateTime"; Rec."Completed DateTime") { ApplicationArea = All; Editable = false; }
                field("Duration (sec)"; Rec."Duration (sec)") { ApplicationArea = All; Editable = false; }
                field(Notes; Rec.Notes) { ApplicationArea = All; }
            }
            group(Aggregate)
            {
                Caption = 'Result Aggregate';
                field("Total Cases"; Rec."Total Cases") { ApplicationArea = All; Editable = false; }
                field(Passed; Rec.Passed) { ApplicationArea = All; Editable = false; StyleExpr = 'Favorable'; }
                field(Failed; Rec.Failed) { ApplicationArea = All; Editable = false; StyleExpr = 'Unfavorable'; }
                field("Pending Manual"; Rec."Pending Manual") { ApplicationArea = All; Editable = false; StyleExpr = 'Attention'; }
                field(Skipped; Rec.Skipped) { ApplicationArea = All; Editable = false; StyleExpr = 'Subordinate'; }
                field("Pass Rate %"; Rec."Pass Rate %") { ApplicationArea = All; Editable = false; }
            }
            part(ResultLines; "DOPSWHS Test Run Result Lines")
            {
                ApplicationArea = All;
                SubPageLink = "Run No." = field("Run No.");
                UpdatePropagation = Both;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(StartRun)
            {
                Caption = '▶ Start Run';
                ToolTip = 'Bu Test Run icin tum aktif caseleri sirayla calistir.';
                ApplicationArea = All;
                Image = Start;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                trigger OnAction()
                var
                    Runner: Codeunit "DOPSWHS Test Runner";
                begin
                    Runner.StartRun(Rec."Run No.");
                    CurrPage.Update(false);
                    Message('Run %1 tamamlandı: Passed=%2, Failed=%3, Pending=%4', Rec."Run No.", Rec.Passed, Rec.Failed, Rec."Pending Manual");
                end;
            }
            action(RerunFailed)
            {
                Caption = 'Re-run Failed Only';
                ToolTip = 'Sadece Failed caseleri tekrar calistir.';
                ApplicationArea = All;
                Image = RefreshLines;
                Promoted = true;
                PromotedCategory = Process;
                trigger OnAction()
                var
                    Runner: Codeunit "DOPSWHS Test Runner";
                begin
                    Runner.StartRunForFailedOnly(Rec."Run No.");
                    CurrPage.Update(false);
                end;
            }
            action(MarkAllPendingPassed)
            {
                Caption = 'Mark All Pending Manual as Passed';
                ToolTip = '(Admin) Tum PendingManual caseleri Passed isaretle. Sadece manuel dogrulama yapildiktan sonra kullanin.';
                ApplicationArea = All;
                Image = ApproveAll;
                trigger OnAction()
                var
                    Result: Record "DOPSWHS Test Run Result";
                    Helper: Codeunit "DOPSWHS Test Result Helper";
                begin
                    Result.SetRange("Run No.", Rec."Run No.");
                    Result.SetRange(Status, Result.Status::PendingManual);
                    if Result.FindSet() then
                        repeat
                            Helper.MarkPassedManually(Result, 'Bulk approved');
                        until Result.Next() = 0;
                    Helper.UpdateRunAggregate(Rec."Run No.");
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
