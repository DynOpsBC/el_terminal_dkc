page 72261 "DOPSWHS Config Check"
{
    PageType = List;
    SourceTable = "DOPSWHS Config Check";
    SourceTableView = sorting("Sort Order");
    Caption = 'WMS Configuration Check';
    ApplicationArea = All;
    UsageCategory = Administration;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Checks)
            {
                field(Indicator; StatusIcon)
                {
                    ApplicationArea = All;
                    Caption = ' ';
                    Editable = false;
                    StyleExpr = StatusStyle;
                }
                field("Title"; Rec."Title")
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = StatusStyle;
                }
                field("Status"; Rec."Status")
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = StatusStyle;
                }
                field("Detail"; Rec."Detail") { ApplicationArea = All; Editable = false; }
                field("Required"; Rec."Required") { ApplicationArea = All; Editable = false; }
                field("Auto Fixable"; Rec."Auto Fixable") { ApplicationArea = All; Editable = false; Caption = 'Auto-Fix'; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Recheck)
            {
                ApplicationArea = All;
                Caption = 'Yeniden Denetle';
                ToolTip = 'Re-evaluate every configuration item.';
                Image = Refresh;
                trigger OnAction()
                begin
                    Checker.RefreshChecks();
                    CurrPage.Update(false);
                end;
            }
            action(FixSelected)
            {
                ApplicationArea = All;
                Caption = 'Seçiliyi Düzelt';
                ToolTip = 'Automatically configure the selected item (if supported).';
                Image = Approve;
                trigger OnAction()
                begin
                    if not Rec."Auto Fixable" then begin
                        Message('Bu madde otomatik düzeltilemez — manuel yapılandırma gerekir.');
                        exit;
                    end;
                    Checker.FixByCode(Rec."Code");
                    CurrPage.Update(false);
                    Message('Düzeltme uygulandı: %1', Rec."Title");
                end;
            }
            action(FixAll)
            {
                ApplicationArea = All;
                Caption = 'Tümünü Düzelt';
                ToolTip = 'Automatically configure every auto-fixable item that is missing or incomplete.';
                Image = SuggestLines;
                trigger OnAction()
                begin
                    Checker.FixAll();
                    CurrPage.Update(false);
                    Message('Otomatik düzeltilebilen tüm yapılandırmalar uygulandı.');
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(Recheck_Promoted; Recheck) { }
                actionref(FixSelected_Promoted; FixSelected) { }
                actionref(FixAll_Promoted; FixAll) { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Checker.RefreshChecks();
    end;

    trigger OnAfterGetRecord()
    begin
        case Rec."Status" of
            Rec."Status"::OK:
                begin
                    StatusIcon := '';
                    StatusStyle := 'Favorable';
                end;
            Rec."Status"::Warning:
                begin
                    StatusIcon := '';
                    StatusStyle := 'Ambiguous';
                end;
            Rec."Status"::Missing:
                begin
                    StatusIcon := '';
                    StatusStyle := 'Unfavorable';
                end;
            else begin
                StatusIcon := '•';
                StatusStyle := 'Subordinate';
            end;
        end;
    end;

    var
        Checker: Codeunit "DOPSWHS Config Checker";
        StatusIcon: Text[4];
        StatusStyle: Text[30];
}
