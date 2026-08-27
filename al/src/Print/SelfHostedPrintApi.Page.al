page 72299 "DOPSWHS Print Job API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'printJob';
    EntitySetName = 'printJobs';
    SourceTable = "DOPSWHS Print Job Queue";
    DelayedInsert = true;
    ODataKeyFields = "Job ID";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(jobId; Rec."Job ID") { Caption = 'jobId'; }
                field(sourceDoc; Rec."Source Doc") { Caption = 'sourceDoc'; }
                field(reportId; Rec."Report ID") { Caption = 'reportId'; }
                field(printerId; Rec."Printer ID") { Caption = 'printerId'; }
                field(channel; Rec.Channel) { Caption = 'channel'; }
                field(format; Rec."Format") { Caption = 'format'; }
                field(status; Rec.Status) { Caption = 'status'; }
                field(copies; Rec.Copies) { Caption = 'copies'; }
                field(payload; PayloadBase64) { Caption = 'payload'; }
                field(payloadSize; Rec."Payload Size") { Caption = 'payloadSize'; }
                field(createdAt; Rec.Created) { Caption = 'createdAt'; }
                field(sentAt; Rec.Sent) { Caption = 'sentAt'; }
                field(agentId; Rec."Agent ID") { Caption = 'agentId'; }
                field(claimedAt; Rec."Claimed At") { Caption = 'claimedAt'; }
                field(lastError; Rec."Last Error") { Caption = 'lastError'; }
                field(retryCount; Rec."Retry Count") { Caption = 'retryCount'; }
                field(correlationId; Rec."Correlation ID") { Caption = 'correlationId'; }
                field(cloudJobId; Rec."Cloud Job ID") { Caption = 'cloudJobId'; }
                field(stationId; Rec."Station ID") { Caption = 'stationId'; }
                field(blobName; Rec."Blob Name") { Caption = 'blobName'; }
                field(payloadSha256; Rec."Payload SHA256") { Caption = 'payloadSha256'; }
                field(dispatchedAt; Rec."Dispatched At") { Caption = 'dispatchedAt'; }
                field(completedAt; Rec."Completed At") { Caption = 'completedAt'; }
                field(nextRetryAt; Rec."Next Retry At") { Caption = 'nextRetryAt'; }
            }
        }
    }

    var
        PayloadBase64: Text;

    trigger OnAfterGetRecord()
    var
        InStream: InStream;
        Base64: Codeunit "Base64 Convert";
    begin
        Clear(PayloadBase64);
        Rec.CalcFields(ZPL);
        if not Rec.ZPL.HasValue() then
            exit;
        Rec.ZPL.CreateInStream(InStream);
        PayloadBase64 := Base64.ToBase64(InStream);
    end;

    [ServiceEnabled]
    procedure claimForPrinter(agentId: Code[50]; printerId: Code[20]): Boolean
    var
        Client: Codeunit "DOPSWHS Self-Host Print Client";
    begin
        exit(Client.MarkClaimed(Rec."Job ID", agentId, printerId));
    end;

    [ServiceEnabled]
    procedure markSuccessForPrinter(message: Text[250]; agentId: Code[50]; printerId: Code[20]): Boolean
    var
        Client: Codeunit "DOPSWHS Self-Host Print Client";
    begin
        exit(Client.MarkStatus(Rec."Job ID", true, message, agentId, printerId));
    end;

    [ServiceEnabled]
    procedure markFailureForPrinter(message: Text[250]; agentId: Code[50]; printerId: Code[20]): Boolean
    var
        Client: Codeunit "DOPSWHS Self-Host Print Client";
    begin
        exit(Client.MarkStatus(Rec."Job ID", false, message, agentId, printerId));
    end;
}
