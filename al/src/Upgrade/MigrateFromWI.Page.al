page 72488 "DOPSWHS Migrate From WI"
{
    Caption = 'Migrate from WI';
    PageType = Card;
    SourceTable = "DOPSWHS Migration Map WI";
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field(LocationCode; LocationCode)
                {
                    Caption = 'Location Code';
                    ApplicationArea = All;
                    TableRelation = Location;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(PreflightCheck)
            {
                Caption = 'Preflight Check';
                ApplicationArea = All;
                trigger OnAction()
                var
                    Migration: Codeunit "DOPSWHS Migrate From WI";
                begin
                    Migration.PreflightCheck();
                end;
            }
            action(DryRun)
            {
                Caption = 'Dry Run';
                ApplicationArea = All;
                trigger OnAction()
                var
                    Migration: Codeunit "DOPSWHS Migrate From WI";
                begin
                    Migration.DryRun(LocationCode);
                end;
            }
            action(Apply)
            {
                Caption = 'Apply';
                ApplicationArea = All;
                trigger OnAction()
                var
                    Migration: Codeunit "DOPSWHS Migrate From WI";
                begin
                    Migration.Apply(LocationCode);
                end;
            }
            action(Cutover)
            {
                Caption = 'Cutover';
                ApplicationArea = All;
                trigger OnAction()
                var
                    Migration: Codeunit "DOPSWHS Migrate From WI";
                begin
                    Migration.Cutover(LocationCode);
                end;
            }
        }
    }

    var
        LocationCode: Code[10];
}
