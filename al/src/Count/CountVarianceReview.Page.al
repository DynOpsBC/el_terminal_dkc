page 72085 "DOPSWHS Count Variance Review"
{
    Caption = 'Count Variance Review';
    PageType = List;
    SourceTable = "DOPSWHS Count Sheet Line";
    SourceTableView = where("Recount Required" = const(true));
    ApplicationArea = All;
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Sheet No."; Rec."Sheet No.") { ApplicationArea = All; }
                field("Line No."; Rec."Line No.") { ApplicationArea = All; }
                field("Item No."; Rec."Item No.") { ApplicationArea = All; }
                field("Bin Code"; Rec."Bin Code") { ApplicationArea = All; }
                field("LP No."; Rec."LP No.") { ApplicationArea = All; }
                field("Lot No."; Rec."Lot No.") { ApplicationArea = All; }
                field("Serial No."; Rec."Serial No.") { ApplicationArea = All; }
                field("System Qty"; Rec."System Qty") { ApplicationArea = All; }
                field("Counted Qty 1"; Rec."Counted Qty 1") { ApplicationArea = All; }
                field("Counted Qty 2"; Rec."Counted Qty 2") { ApplicationArea = All; }
                field("Counted Qty 3"; Rec."Counted Qty 3") { ApplicationArea = All; }
                field(Variance; Rec.Variance) { ApplicationArea = All; }
                field("Recount Required"; Rec."Recount Required") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ApproveVariance)
            {
                Caption = 'Approve Variance';
                ApplicationArea = All;
                Image = Approve;
                trigger OnAction()
                begin
                    Rec."Recount Required" := false;
                    Rec.Modify(true);
                end;
            }
            action(SupervisorApproveAll)
            {
                Caption = 'Supervisor Approve All';
                ApplicationArea = All;
                Image = Approve;
                trigger OnAction()
                var
                    CountLine: Record "DOPSWHS Count Sheet Line";
                begin
                    CurrPage.SetSelectionFilter(CountLine);
                    if CountLine.FindSet(true) then
                        repeat
                            CountLine."Recount Required" := false;
                            CountLine.Modify(true);
                        until CountLine.Next() = 0;
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetFilter("Recount Required", '%1', true);
        Rec.SetFilter(Variance, '<>%1', 0);
    end;
}
