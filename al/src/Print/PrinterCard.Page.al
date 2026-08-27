page 72297 "DOPSWHS Printer Card"
{
    Caption = 'Printer Card';
    PageType = Card;
    ApplicationArea = All;
    SourceTable = "DOPSWHS Printer";

    layout
    {
        area(Content)
        {
            group(General)
            {
                field("Code"; Rec."Code") { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field("Location Code"; Rec."Location Code") { ApplicationArea = All; }
                field("Format"; Rec."Format") { ApplicationArea = All; }
                field(Active; Rec.Active) { ApplicationArea = All; }
                field("Station ID"; Rec."Station ID") { ApplicationArea = All; }
                field("Enable BC Reports"; Rec."Enable BC Reports") { ApplicationArea = All; }
                field(Comment; Rec.Comment) { ApplicationArea = All; }
            }
            group(Connection)
            {
                Caption = 'Local Agent Binding';
                field("Printer Handle"; Rec."Printer Handle") { ApplicationArea = All; }
                field(Hostname; Rec.Hostname) { ApplicationArea = All; Visible = not IsAzureDirect; }
                field(Port; Rec.Port) { ApplicationArea = All; Visible = not IsAzureDirect; }
                field("Default Copies"; Rec."Default Copies") { ApplicationArea = All; }
                field("Paper Width (mm)"; Rec."Paper Width (mm)") { ApplicationArea = All; }
                field("Paper Height (mm)"; Rec."Paper Height (mm)") { ApplicationArea = All; }
            }
            group(Security)
            {
                Caption = 'Security';
                field("Token Hash"; Rec."Token Hash") { ApplicationArea = All; Editable = false; Visible = not IsAzureDirect; }
                field("Token Issued At"; Rec."Token Issued At") { ApplicationArea = All; Editable = false; Visible = not IsAzureDirect; }
                field("Last Seen At"; Rec."Last Seen At") { ApplicationArea = All; Editable = false; }
                field("Last Agent ID"; Rec."Last Agent ID") { ApplicationArea = All; Editable = false; }
                field("Discovered by Agent"; Rec."Discovered by Agent") { ApplicationArea = All; Editable = false; }
                field("Agent Status"; Rec."Agent Status") { ApplicationArea = All; Editable = false; }
                field("Last Status At"; Rec."Last Status At") { ApplicationArea = All; Editable = false; }
                field("Last Status Message"; Rec."Last Status Message") { ApplicationArea = All; Editable = false; }
                field("Agent Version"; Rec."Agent Version") { ApplicationArea = All; Editable = false; }
                field("Agent Default Printer"; Rec."Agent Default Printer") { ApplicationArea = All; Editable = false; }
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
                ToolTip = 'Generates a fresh agent secret. The plain value is shown only once.';

                trigger OnAction()
                var
                    Client: Codeunit "DOPSWHS Self-Host Print Client";
                    Token: Text;
                begin
                    Token := Client.RotateToken(Rec."Code");
                    Message('Agent token for %1:\n\n%2\n\nCopy it now — only the hash is stored.', Rec."Code", Token);
                end;
            }
            action(TestPrint)
            {
                Caption = 'Test Print';
                ApplicationArea = All;
                Image = Print;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Queues a small ZPL self-test label. PDF printers are tested by printing a standard Business Central report.';

                trigger OnAction()
                var
                    Client: Codeunit "DOPSWHS Self-Host Print Client";
                begin
                    if Rec."Format" = Rec."Format"::PDF then begin
                        Message('PDF printer %1 is tested through the standard Business Central Print action. Select the DOPSWHS virtual printer in a report so BC renders and queues a real PDF.', Rec.Code);
                        exit;
                    end;
                    Client.EnqueueSelfTest(Rec."Code");
                    Message('Self-test job queued for %1.', Rec."Code");
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        RefreshChannel();
    end;

    trigger OnAfterGetRecord()
    begin
        RefreshChannel();
    end;

    var
        IsAzureDirect: Boolean;

    local procedure RefreshChannel()
    var
        Setup: Record "DOPSWHS Setup";
    begin
        IsAzureDirect := Setup.Get('') and (Setup."Print Channel" = Setup."Print Channel"::AzureDirect);
    end;
}
