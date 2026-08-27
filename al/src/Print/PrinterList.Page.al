page 72296 "DOPSWHS Printer List"
{
    Caption = 'Printers';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "DOPSWHS Printer";
    CardPageId = "DOPSWHS Printer Card";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Code"; Rec."Code") { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field("Location Code"; Rec."Location Code") { ApplicationArea = All; }
                field("Format"; Rec."Format") { ApplicationArea = All; }
                field("Printer Handle"; Rec."Printer Handle") { ApplicationArea = All; }
                field("Station ID"; Rec."Station ID") { ApplicationArea = All; }
                field(Active; Rec.Active) { ApplicationArea = All; }
                field("Enable BC Reports"; Rec."Enable BC Reports") { ApplicationArea = All; }
                field("Last Seen At"; Rec."Last Seen At") { ApplicationArea = All; }
                field("Last Agent ID"; Rec."Last Agent ID") { ApplicationArea = All; }
                field("Agent Status"; Rec."Agent Status") { ApplicationArea = All; }
                field("Last Status At"; Rec."Last Status At") { ApplicationArea = All; }
                field("Agent Version"; Rec."Agent Version") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(GenerateToken)
            {
                Caption = 'Generate Token';
                ApplicationArea = All;
                Image = EncryptionKeys;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Visible = not IsAzureDirect;
                ToolTip = 'Generates a fresh agent secret. Copy it now — it will not be shown again.';

                trigger OnAction()
                var
                    Client: Codeunit "DOPSWHS Self-Host Print Client";
                    Token: Text;
                begin
                    Token := Client.RotateToken(Rec."Code");
                    Message('Agent token for %1:\n\n%2\n\nCopy now — only the hash is stored.', Rec."Code", Token);
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
        Setup: Record "DOPSWHS Setup";
    begin
        IsAzureDirect := Setup.Get('') and (Setup."Print Channel" = Setup."Print Channel"::AzureDirect);
    end;

    var
        IsAzureDirect: Boolean;
}
