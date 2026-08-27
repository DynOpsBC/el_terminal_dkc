page 72368 "DOPSWHS Print Job Queue"
{
    Caption = 'Print Job Queue';
    PageType = List;
    SourceTable = "DOPSWHS Print Job Queue";
    ApplicationArea = All;
    UsageCategory = History;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Jobs)
            {
                field("Job ID"; Rec."Job ID") { ApplicationArea = All; }
                field("Source Doc"; Rec."Source Doc") { ApplicationArea = All; }
                field("Report ID"; Rec."Report ID") { ApplicationArea = All; }
                field("Printer ID"; Rec."Printer ID") { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; }
                field(Channel; Rec.Channel) { ApplicationArea = All; }
                field(Format; Rec."Format") { ApplicationArea = All; }
                field(Copies; Rec.Copies) { ApplicationArea = All; }
                field("Payload Size"; Rec."Payload Size") { ApplicationArea = All; }
                field(Created; Rec.Created) { ApplicationArea = All; }
                field(Sent; Rec.Sent) { ApplicationArea = All; }
                field("Agent ID"; Rec."Agent ID") { ApplicationArea = All; }
                field("Claimed At"; Rec."Claimed At") { ApplicationArea = All; }
                field("Retry Count"; Rec."Retry Count") { ApplicationArea = All; }
                field("Last Error"; Rec."Last Error") { ApplicationArea = All; }
                field("Correlation ID"; Rec."Correlation ID") { ApplicationArea = All; }
                field("Cloud Job ID"; Rec."Cloud Job ID") { ApplicationArea = All; }
                field("Station ID"; Rec."Station ID") { ApplicationArea = All; }
                field("Blob Name"; Rec."Blob Name") { ApplicationArea = All; }
                field("Payload SHA256"; Rec."Payload SHA256") { ApplicationArea = All; }
                field("Dispatched At"; Rec."Dispatched At") { ApplicationArea = All; }
                field("Completed At"; Rec."Completed At") { ApplicationArea = All; }
                field("Next Retry At"; Rec."Next Retry At") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RetryFailed)
            {
                Caption = 'Retry Failed Job';
                ApplicationArea = All;
                Image = ReOpen;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = (Rec.Status = Rec.Status::Failed) and (Rec.Channel = Rec.Channel::SelfHosted);

                trigger OnAction()
                var
                    Client: Codeunit "DOPSWHS Self-Host Print Client";
                begin
                    if not Client.RetryFailed(Rec."Job ID") then
                        Error('Only failed print jobs can be retried.');
                    CurrPage.Update(false);
                end;
            }
            action(RetryAzureFailedAsNew)
            {
                Caption = 'Retry Azure Failed as New';
                ApplicationArea = All;
                Image = ReOpen;
                Enabled = (Rec.Status = Rec.Status::Failed) and (Rec.Channel = Rec.Channel::AzureDirect);
                AccessByPermission = tabledata "DOPSWHS Setup" = M;
                ToolTip = 'Creates a new Azure job/message ID and retains the failed audit row. Investigate ambiguous dispatch errors first because a new ID can physically print twice.';

                trigger OnAction()
                var
                    AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
                    NewJobId: Integer;
                begin
                    if not Confirm(
                        'A new Azure message ID can print the document twice if the previous result was ambiguous. Have you investigated the failed job and do you want a new physical print attempt?',
                        false)
                    then
                        exit;
                    NewJobId := AzureBridge.CloneFailedJobForRetry(Rec."Job ID");
                    Message('New Azure Direct print job %1 was queued. The failed audit row was retained.', NewJobId);
                    CurrPage.Update(false);
                end;
            }
            action(ResolveStaleAndRetry)
            {
                Caption = 'Resolve Stale and Retry as New';
                ApplicationArea = All;
                Image = ReOpen;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = (Rec.Status = Rec.Status::Dispatched) and (Rec.Channel = Rec.Channel::AzureDirect);
                AccessByPermission = tabledata "DOPSWHS Setup" = M;
                ToolTip = 'After investigating the agent outbox and Azure dead-letter queues, marks a dispatch older than 8 days failed and creates a new job/message ID. This can physically print twice if the original result was merely delayed.';

                trigger OnAction()
                var
                    AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
                    NewJobId: Integer;
                begin
                    if not Confirm(
                        'This can print the document twice. Have you checked the agent outbox and Azure dead-letter queues, and do you want a new physical print attempt?',
                        false)
                    then
                        exit;
                    NewJobId := AzureBridge.ResolveStaleDispatchedAndRetry(Rec."Job ID");
                    Message('New Azure Direct print job %1 was queued. The original audit row was retained.', NewJobId);
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
