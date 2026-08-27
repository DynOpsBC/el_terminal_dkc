page 72281 "DOPSWHS Demo E2E Results"
{
    PageType = List;
    SourceTable = "DOPSWHS Demo E2E Result";
    Caption = 'Demo E2E Suite Results';
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = false;
    SourceTableView = sorting("Function Code", "Transaction No.");

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Function Code"; Rec."Function Code") { ApplicationArea = All; }
                field("Transaction No."; Rec."Transaction No.") { ApplicationArea = All; }
                field("Status"; Rec.Status)
                {
                    ApplicationArea = All;
                    StyleExpr = StatusStyle;
                }
                field("Title"; Rec.Title) { ApplicationArea = All; }
                field("Duration Ms"; Rec."Duration Ms") { ApplicationArea = All; }
                field("LP No."; Rec."LP No.") { ApplicationArea = All; }
                field("Source Document No."; Rec."Source Document No.") { ApplicationArea = All; }
                field("Item No."; Rec."Item No.") { ApplicationArea = All; }
                field("Quantity"; Rec.Quantity) { ApplicationArea = All; }
                field("Location Code"; Rec."Location Code") { ApplicationArea = All; }
                field("Surrogate"; Rec.Surrogate) { ApplicationArea = All; ToolTip = 'AL-side equivalent of the mobile call (same Mgmt codeunit path).'; }
                field("Started DateTime"; Rec."Started DateTime") { ApplicationArea = All; }
                field("Completed DateTime"; Rec."Completed DateTime") { ApplicationArea = All; }
                field("Result Detail"; Rec."Result Detail") { ApplicationArea = All; }
                field("Error Message"; Rec."Error Message")
                {
                    ApplicationArea = All;
                    StyleExpr = 'Unfavorable';
                    Visible = Rec.Status = Rec.Status::Failed;
                }
                field("Run No."; Rec."Run No.") { ApplicationArea = All; }
            }
        }
        area(FactBoxes)
        {
            part(Stats; "DOPSWHS Demo E2E Cue")
            {
                Caption = 'Stats';
                ApplicationArea = All;
                SubPageView = where("Primary Key" = const(''));
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RunAllSuite)
            {
                Caption = 'Run All E2E Suite';
                Image = Start;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Runs all 10 transactions across each of the 10 WMS functions (LP, Receive, Put-Away, Pick, Ship, Move, Count, Quality, Production, Assembly). Same code paths the mobile app exercises via API bound actions.';

                trigger OnAction()
                var
                    Suite: Codeunit "DOPSWHS Demo E2E Suite";
                begin
                    Suite.RunAll();
                    CurrPage.Update();
                end;
            }
            action(ClearAll)
            {
                Caption = 'Clear All Results';
                Image = ClearLog;
                ApplicationArea = All;
                ToolTip = 'Removes every Demo E2E result row. Next Run All re-creates them.';

                trigger OnAction()
                var
                    Result: Record "DOPSWHS Demo E2E Result";
                begin
                    if Confirm('Delete all Demo E2E result rows?') then begin
                        Result.DeleteAll();
                        CurrPage.Update();
                    end;
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.Status of
            Rec.Status::Passed:
                StatusStyle := 'Favorable';
            Rec.Status::Failed:
                StatusStyle := 'Unfavorable';
            Rec.Status::Running:
                StatusStyle := 'Attention';
            else
                StatusStyle := 'Subordinate';
        end;
    end;

    var
        StatusStyle: Text;
}
