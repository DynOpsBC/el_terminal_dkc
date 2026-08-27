page 72074 "DOPSWHS Count Sheet List"
{
    Caption = 'Count Sheets';
    PageType = List;
    SourceTable = "DOPSWHS Count Sheet Header";
    ApplicationArea = All;
    UsageCategory = Lists;
    CardPageId = "DOPSWHS Count Sheet Card";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("No."; Rec."No.") { ApplicationArea = All; }
                field("Location Code"; Rec."Location Code") { ApplicationArea = All; }
                field(Mode; Rec.Mode) { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; }
                field("Created DateTime"; Rec."Created DateTime") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(NewCountSheet)
            {
                Caption = 'New';
                ApplicationArea = All;
                Image = NewDocument;
                RunObject = page "DOPSWHS Count Sheet Card";
                RunPageMode = Create;
            }
            action(OpenCard)
            {
                Caption = 'Open Card';
                ApplicationArea = All;
                Image = EditLines;
                RunObject = page "DOPSWHS Count Sheet Card";
                RunPageLink = "No." = field("No.");
            }
            action(Post)
            {
                Caption = 'Post';
                ApplicationArea = All;
                Image = Post;
                trigger OnAction()
                var
                    CountMgmt: Codeunit "DOPSWHS Count Mgmt";
                begin
                    CountMgmt.PostSheet(Rec."No.");
                    CurrPage.Update(false);
                end;
            }
            action(GenerateLines)
            {
                Caption = 'Satırları Üret';
                ApplicationArea = All;
                Image = CalculateLines;
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
        }
    }
}
