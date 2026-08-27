page 72075 "DOPSWHS Count Sheet Card"
{
    Caption = 'Count Sheet';
    PageType = Card;
    SourceTable = "DOPSWHS Count Sheet Header";
    ApplicationArea = All;
    UsageCategory = Documents;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("No."; Rec."No.") { ApplicationArea = All; Editable = HeaderEditable; }
                field("Location Code"; Rec."Location Code") { ApplicationArea = All; Editable = HeaderEditable; }
                field(Mode; Rec.Mode) { ApplicationArea = All; Editable = HeaderEditable; }
                field(Status; Rec.Status) { ApplicationArea = All; Editable = HeaderEditable; }
                field("V2 Scan Mode"; Rec."V2 Scan Mode") { ApplicationArea = All; }
            }
            group(Progress)
            {
                Caption = 'Sayım Durumu';
                field(TotalLines; TotalLines)
                {
                    Caption = 'Toplam Satır';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(CountedLines; CountedLines)
                {
                    Caption = 'Sayılan';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Favorable;
                }
                field(RemainingLines; TotalLines - CountedLines)
                {
                    Caption = 'Kalan';
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = RemainingStyle;
                }
                field(VarianceLines; VarianceLines)
                {
                    Caption = 'Farklı Satır';
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = VarianceLinesStyle;
                }
            }
            part(Counters; "DOPSWHS Count Counter Part")
            {
                ApplicationArea = All;
                SubPageLink = "Sheet No." = field("No.");
                Editable = HeaderEditable;
            }
            part(Lines; "DOPSWHS Count Sheet Line Part")
            {
                ApplicationArea = All;
                SubPageLink = "Sheet No." = field("No.");
                Editable = HeaderEditable;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(GenerateLines)
            {
                Caption = 'Satırları Üret';
                ApplicationArea = All;
                Image = CalculateLines;
                Enabled = HeaderEditable;
                trigger OnAction()
                var
                    CountMgmt: Codeunit "DOPSWHS Count Mgmt";
                    LinesCreated: Integer;
                begin
                    LinesCreated := CountMgmt.GenerateLines(Rec."No.");
                    CurrPage.Update(false);
                    Message('%1 sayım satırı oluşturuldu.', LinesCreated);
                end;
            }
            action(Post)
            {
                Caption = 'Post';
                ApplicationArea = All;
                Image = Post;
                Enabled = HeaderEditable;
                trigger OnAction()
                var
                    CountMgmt: Codeunit "DOPSWHS Count Mgmt";
                begin
                    CountMgmt.PostSheet(Rec."No.");
                    CurrPage.Update(false);
                end;
            }
            action(PrintVarianceReport)
            {
                Caption = 'Print Variance Report';
                ApplicationArea = All;
                Image = PrintReport;
                trigger OnAction()
                var
                    CountLine: Record "DOPSWHS Count Sheet Line";
                begin
                    CountLine.SetRange("Sheet No.", Rec."No.");
                    Report.RunModal(Report::"DOPSWHS Count Variance", true, false, CountLine);
                end;
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    var
        CountLine: Record "DOPSWHS Count Sheet Line";
    begin
        HeaderEditable := Rec.Status <> Rec.Status::Posted;
        TotalLines := 0;
        CountedLines := 0;
        VarianceLines := 0;
        CountLine.SetRange("Sheet No.", Rec."No.");
        if CountLine.FindSet() then
            repeat
                TotalLines += 1;
                if CountLine."Counted 1" or CountLine."Counted 2" or CountLine."Counted 3" or
                   (CountLine."Counted Qty 1" <> 0) or (CountLine."Counted Qty 2" <> 0) or (CountLine."Counted Qty 3" <> 0)
                then begin
                    CountedLines += 1;
                    if CountLine."Counted Qty 1" <> CountLine."System Qty" then
                        VarianceLines += 1;
                end;
            until CountLine.Next() = 0;
        if TotalLines > CountedLines then
            RemainingStyle := 'Attention'
        else
            RemainingStyle := 'Favorable';
        if VarianceLines > 0 then
            VarianceLinesStyle := 'Unfavorable'
        else
            VarianceLinesStyle := 'Favorable';
    end;

    var
        TotalLines: Integer;
        CountedLines: Integer;
        VarianceLines: Integer;
        RemainingStyle: Text;
        VarianceLinesStyle: Text;
        HeaderEditable: Boolean;
}
