using System.Environment;
using System.Utilities;

codeunit 72372 "DOPSWHS Azure Print Bridge"
{
    Access = Internal;
    Permissions =
        tabledata "DOPSWHS Setup" = rimd,
        tabledata "DOPSWHS Printer" = rimd,
        tabledata "DOPSWHS Print Job Queue" = rimd,
        tabledata "DOPSWHS Print Job Log" = rimd;

    /// <summary>
    /// Imports the deployment's business-central.runtime.secrets.json without persisting any
    /// connection string, SAS token or shared key in a Business Central table.
    /// Unknown JSON properties are intentionally ignored for forward compatibility.
    /// </summary>
    [NonDebuggable]
    procedure ImportRuntimeConfiguration(var ConfigStream: InStream)
    var
        Setup: Record "DOPSWHS Setup";
        CandidateSetup: Record "DOPSWHS Setup" temporary;
        AzurePrintWorker: Codeunit "DOPSWHS Azure Print Worker";
        Root: JsonObject;
        BusinessCentral: JsonObject;
        Routing: JsonObject;
        SchemaToken: JsonToken;
        StationId: Text;
        JobsConnection: Text;
        StatusConnection: Text;
        BlobContainerUrl: Text;
        BlobUploadSas: Text;
        JobsKey: Text;
        StatusKey: Text;
        JobsNamespace: Text;
        StatusNamespace: Text;
        JobsQueue: Text;
        StatusQueue: Text;
        JobsPolicy: Text;
        StatusPolicy: Text;
        JobsSuffix: Text;
        StatusSuffix: Text;
        TenantRouteId: Text;
        CompanyRouteId: Text;
        ConfigTenantRouteId: Text;
        ConfigCompanyRouteId: Text;
        BlobSasExpiresAt: DateTime;
    begin
        if not Root.ReadFrom(ConfigStream) then
            Error('The selected business-central.runtime.secrets.json file is not valid JSON.');
        if not Root.Get('schemaVersion', SchemaToken) or not SchemaToken.IsValue() or
           (SchemaToken.AsValue().AsInteger() <> 1)
        then
            Error('business-central.runtime.secrets.json must use schemaVersion 1.');
        BusinessCentral := RequireJsonObject(Root, 'businessCentral');
        Routing := RequireJsonObject(Root, 'routing');
        JobsConnection := RequireJsonText(BusinessCentral, 'printJobsSendConnectionString');
        StatusConnection := RequireJsonText(BusinessCentral, 'printerStatusListenConnectionString');
        BlobContainerUrl := RequireJsonText(BusinessCentral, 'blobContainerUrl');
        BlobUploadSas := RequireJsonText(BusinessCentral, 'blobCreateWriteSasToken');
        BlobSasExpiresAt := RequireJsonUtcDateTime(Root, 'blobSasExpiresAtUtc');
        ValidateBlobSasExpiry(BlobSasExpiresAt);
        StationId := RequireJsonText(Root, 'stationId');
        ConfigTenantRouteId := RequireJsonText(Routing, 'tenantId');
        ConfigCompanyRouteId := RequireJsonText(Routing, 'companyId');

        ParseServiceBusConnectionString(JobsConnection, JobsNamespace, JobsSuffix, JobsQueue, JobsPolicy, JobsKey);
        ParseServiceBusConnectionString(StatusConnection, StatusNamespace, StatusSuffix, StatusQueue, StatusPolicy, StatusKey);
        if (LowerCase(JobsNamespace) <> LowerCase(StatusNamespace)) or
           (LowerCase(JobsSuffix) <> LowerCase(StatusSuffix))
        then
            Error('The jobs and status connection strings must use the same Service Bus namespace.');

        ParseStationRoute(StationId, TenantRouteId, CompanyRouteId);
        if (ConfigTenantRouteId <> TenantRouteId) or (ConfigCompanyRouteId <> CompanyRouteId) then
            Error('routing.tenantId/companyId must match the first two canonical stationId segments exactly.');

        // Validate the complete, non-secret deployment contract before changing
        // company setup or Isolated Storage. Import never normalizes a route ID.
        ValidateImportedServiceBusMetadata(
            JobsNamespace, JobsSuffix, JobsQueue, JobsPolicy,
            StatusNamespace, StatusSuffix, StatusQueue, StatusPolicy);
        CandidateSetup.Init();
        CandidateSetup.ApplyAzureDefaults();
        ParseBlobContainerUrl(BlobContainerUrl, CandidateSetup);
        ValidateStorageAccount(CandidateSetup."Azure Storage Account");
        ValidateContainer(CandidateSetup."Azure Blob Container");
        ValidateBlobUploadSas(BlobUploadSas);
        ValidateSharedAccessKey(JobsKey, 'jobs Send');
        ValidateSharedAccessKey(StatusKey, 'status Listen');

        if not Setup.Get('') then begin
            Setup.Init();
            Setup.Insert(true);
        end;
        Setup.ApplyAzureDefaults();
        Setup.Validate("Azure SB Namespace", JobsNamespace);
        Setup.Validate("Azure Print Jobs Queue", JobsQueue);
        Setup.Validate("Azure Printer Status Queue", StatusQueue);
        Setup."Azure Jobs SAS Policy" := CopyStr(JobsPolicy, 1, MaxStrLen(Setup."Azure Jobs SAS Policy"));
        Setup."Azure Status SAS Policy" := CopyStr(StatusPolicy, 1, MaxStrLen(Setup."Azure Status SAS Policy"));
        Setup."Azure SB Endpoint Suffix" := CopyStr(JobsSuffix, 1, MaxStrLen(Setup."Azure SB Endpoint Suffix"));
        Setup.Validate("Azure Tenant Route ID", TenantRouteId);
        Setup.Validate("Azure Company Route ID", CompanyRouteId);
        ParseBlobContainerUrl(BlobContainerUrl, Setup);
        Setup."Azure Blob SAS Expires At" := BlobSasExpiresAt;
        Setup."Azure Expiry Warning At" := 0DT;
        Setup.Modify(true);

        StoreSecret(BlobUploadSasKeyLbl, BlobUploadSas);
        StoreSecret(JobsSharedKeyKeyLbl, JobsKey);
        StoreSecret(StatusSharedKeyKeyLbl, StatusKey);
        ValidateConfiguration(true);
        Setup.Get('');
        Setup.Validate("Print Channel", Setup."Print Channel"::AzureDirect);
        Setup.Modify(true);
        AzurePrintWorker.ScheduleWorkerJob();
    end;

    [NonDebuggable]
    procedure ConfigureSecrets(BlobUploadSas: Text; BlobSasExpiresAt: DateTime; JobsSharedKey: Text; StatusSharedKey: Text)
    var
        Setup: Record "DOPSWHS Setup";
    begin
        if (BlobUploadSas = '') and not HasSecret(BlobUploadSasKeyLbl) then
            Error('The Blob create/write SAS token has not been configured.');
        if (JobsSharedKey = '') and not HasSecret(JobsSharedKeyKeyLbl) then
            Error('The Service Bus jobs Send policy key has not been configured.');
        if (StatusSharedKey = '') and not HasSecret(StatusSharedKeyKeyLbl) then
            Error('The Service Bus status Listen policy key has not been configured.');
        if BlobUploadSas <> '' then begin
            if not Setup.Get('') then
                Error('Advanced WMS Setup must be configured.');
            ValidateBlobUploadSas(BlobUploadSas);
            ValidateBlobSasExpiry(BlobSasExpiresAt);
        end else
            if BlobSasExpiresAt <> 0DT then
                Error('Blob SAS Expires At can be supplied only when a new Blob SAS token is supplied.');
        if JobsSharedKey <> '' then
            ValidateSharedAccessKey(JobsSharedKey, 'jobs Send');
        if StatusSharedKey <> '' then
            ValidateSharedAccessKey(StatusSharedKey, 'status Listen');

        if BlobUploadSas <> '' then
            StoreSecret(BlobUploadSasKeyLbl, BlobUploadSas);
        if JobsSharedKey <> '' then
            StoreSecret(JobsSharedKeyKeyLbl, JobsSharedKey);
        if StatusSharedKey <> '' then
            StoreSecret(StatusSharedKeyKeyLbl, StatusSharedKey);
        if BlobUploadSas <> '' then begin
            Setup."Azure Blob SAS Expires At" := BlobSasExpiresAt;
            Setup."Azure Expiry Warning At" := 0DT;
            Setup.Modify(true);
        end;
    end;

    procedure ClearSecrets()
    var
        Setup: Record "DOPSWHS Setup";
    begin
        DeleteSecret(BlobUploadSasKeyLbl);
        DeleteSecret(JobsSharedKeyKeyLbl);
        DeleteSecret(StatusSharedKeyKeyLbl);
        if Setup.Get('') then begin
            Setup."Azure Blob SAS Expires At" := 0DT;
            Setup."Azure Expiry Warning At" := 0DT;
            Setup.Modify(true);
        end;
    end;

    procedure BlobSecretIsSet(): Boolean
    begin
        exit(HasSecret(BlobUploadSasKeyLbl));
    end;

    procedure JobsSecretIsSet(): Boolean
    begin
        exit(HasSecret(JobsSharedKeyKeyLbl));
    end;

    procedure StatusSecretIsSet(): Boolean
    begin
        exit(HasSecret(StatusSharedKeyKeyLbl));
    end;

    procedure ValidateConfiguration(RequireStatusSecret: Boolean)
    var
        Setup: Record "DOPSWHS Setup";
    begin
        if not Setup.Get('') then
            Error('Advanced WMS Setup must be configured.');
        Setup.TestField("Azure SB Namespace");
        Setup.TestField("Azure Print Jobs Queue");
        Setup.TestField("Azure Printer Status Queue");
        Setup.TestField("Azure Jobs SAS Policy");
        Setup.TestField("Azure Status SAS Policy");
        Setup.TestField("Azure Storage Account");
        Setup.TestField("Azure Blob Container");
        Setup.TestField("Azure Blob Endpoint Suffix");
        Setup.TestField("Azure SB Endpoint Suffix");
        Setup.TestField("Azure Tenant Route ID");
        Setup.TestField("Azure Company Route ID");
        Setup.TestField("Azure Blob SAS Expires At");
        if Setup."Azure Blob SAS Expires At" <= CurrentDateTime() then
            Error('The Blob upload SAS expired at %1. Generate and import new Azure Direct credentials.', Setup."Azure Blob SAS Expires At");
        if Setup."Azure Dispatch Max Attempts" <= 0 then
            Error('Maximum Dispatch Attempts must be greater than zero.');

        ValidateDnsLabel(Setup."Azure SB Namespace", 6, 50, 'Service Bus namespace');
        ValidateStorageAccount(Setup."Azure Storage Account");
        ValidateContainer(Setup."Azure Blob Container");
        ValidateEntityName(Setup."Azure Print Jobs Queue", 'Print Jobs Queue');
        ValidateEntityName(Setup."Azure Printer Status Queue", 'Printer Status Queue');
        ValidateEndpointSuffix(Setup."Azure Blob Endpoint Suffix", 'Blob Endpoint Suffix');
        ValidateEndpointSuffix(Setup."Azure SB Endpoint Suffix", 'Service Bus Endpoint Suffix');
        if Setup."Azure Blob Endpoint Suffix" <> 'blob.core.windows.net' then
            Error('Azure Direct v1 supports only the blob.core.windows.net endpoint.');
        if Setup."Azure SB Endpoint Suffix" <> 'servicebus.windows.net' then
            Error('Azure Direct v1 supports only the servicebus.windows.net endpoint.');
        if Setup."Azure Print Jobs Queue" <> 'print-jobs-queue' then
            Error('Azure Direct v1 requires the print-jobs-queue entity.');
        if Setup."Azure Printer Status Queue" <> 'printer-status-queue' then
            Error('Azure Direct v1 requires the printer-status-queue entity.');
        if Setup."Azure Jobs SAS Policy" <> 'bc-send-jobs' then
            Error('Azure Direct v1 requires the queue-scoped bc-send-jobs policy. RootManageSharedAccessKey is not allowed.');
        if Setup."Azure Status SAS Policy" <> 'bc-listen-status' then
            Error('Azure Direct v1 requires the queue-scoped bc-listen-status policy. RootManageSharedAccessKey is not allowed.');
        if Setup."Azure Blob Container" <> 'print-jobs' then
            Error('Azure Direct v1 requires the private print-jobs blob container.');
        ValidateRouteToken(Setup."Azure Tenant Route ID", 'Tenant Route ID');
        ValidateRouteToken(Setup."Azure Company Route ID", 'Company Route ID');

        if not HasSecret(BlobUploadSasKeyLbl) then
            Error('Configure the Blob create/write SAS token in Isolated Storage.');
        if not HasSecret(JobsSharedKeyKeyLbl) then
            Error('Configure the queue-scoped jobs Send policy key in Isolated Storage.');
        if RequireStatusSecret and not HasSecret(StatusSharedKeyKeyLbl) then
            Error('Configure the queue-scoped status Listen policy key in Isolated Storage.');

    end;

    procedure ValidateStatusConfiguration()
    var
        Setup: Record "DOPSWHS Setup";
    begin
        if not Setup.Get('') then
            Error('Advanced WMS Setup must be configured.');
        Setup.TestField("Azure SB Namespace");
        Setup.TestField("Azure Printer Status Queue");
        Setup.TestField("Azure Status SAS Policy");
        Setup.TestField("Azure SB Endpoint Suffix");
        Setup.TestField("Azure Tenant Route ID");
        Setup.TestField("Azure Company Route ID");
        ValidateDnsLabel(Setup."Azure SB Namespace", 6, 50, 'Service Bus namespace');
        ValidateEntityName(Setup."Azure Printer Status Queue", 'Printer Status Queue');
        ValidateEndpointSuffix(Setup."Azure SB Endpoint Suffix", 'Service Bus Endpoint Suffix');
        if Setup."Azure SB Endpoint Suffix" <> 'servicebus.windows.net' then
            Error('Azure Direct v1 supports only the servicebus.windows.net endpoint.');
        if Setup."Azure Printer Status Queue" <> 'printer-status-queue' then
            Error('Azure Direct v1 requires the printer-status-queue entity.');
        if Setup."Azure Status SAS Policy" <> 'bc-listen-status' then
            Error('Azure Direct v1 requires the queue-scoped bc-listen-status policy. RootManageSharedAccessKey is not allowed.');
        ValidateRouteToken(Setup."Azure Tenant Route ID", 'Tenant Route ID');
        ValidateRouteToken(Setup."Azure Company Route ID", 'Company Route ID');
        if not HasSecret(StatusSharedKeyKeyLbl) then
            Error('Configure the queue-scoped status Listen policy key in Isolated Storage.');
    end;

    procedure ValidateStationId(StationId: Text)
    var
        Setup: Record "DOPSWHS Setup";
        Segments: List of [Text];
    begin
        ValidateCanonicalStationId(StationId);
        Segments := StationId.Split('.');
        if Setup.Get('') then begin
            if (Setup."Azure Tenant Route ID" <> '') and
               (Segments.Get(1) <> Setup."Azure Tenant Route ID")
            then
                Error('Station ID %1 does not belong to tenant route %2.', StationId, Setup."Azure Tenant Route ID");
            if (Setup."Azure Company Route ID" <> '') and
               (Segments.Get(2) <> Setup."Azure Company Route ID")
            then
                Error('Station ID %1 does not belong to company route %2.', StationId, Setup."Azure Company Route ID");
        end;
    end;

    procedure ValidateAzurePrinterId(PrinterId: Text)
    var
        Position: Integer;
    begin
        if (StrLen(PrinterId) <> 17) or (CopyStr(PrinterId, 1, 1) <> 'P') then
            Error('Azure Direct printer ID %1 must use P followed by 16 uppercase hexadecimal characters.', PrinterId);
        for Position := 2 to 17 do
            if StrPos('0123456789ABCDEF', Format(PrinterId[Position])) = 0 then
                Error('Azure Direct printer ID %1 must use P followed by 16 uppercase hexadecimal characters.', PrinterId);
    end;

    procedure ComputePayloadSha256(var Payload: InStream): Text[64]
    var
        Cryptography: Codeunit "Cryptography Management";
    begin
        exit(CopyStr(UpperCase(Cryptography.GenerateHash(Payload, 2)), 1, 64));
    end;

    procedure PrepareAzureJob(var Queue: Record "DOPSWHS Print Job Queue"; Printer: Record "DOPSWHS Printer"; PayloadSha256: Text)
    begin
        ValidateAzurePrinter(Printer);
        ValidateSha256(PayloadSha256);
        Queue.Channel := Queue.Channel::AzureDirect;
        Queue."Station ID" := Printer."Station ID";
        Queue."Payload SHA256" := CopyStr(PayloadSha256, 1, MaxStrLen(Queue."Payload SHA256"));
    end;

    procedure ValidateAzurePrinter(Printer: Record "DOPSWHS Printer")
    begin
        ValidateConfiguration(false);
        Printer.TestField(Active, true);
        ValidateAzurePrinterId(Printer.Code);
        if Printer."Station ID" = '' then
            Error('Printer %1 has no Station ID.', Printer.Code);
        ValidateStationId(Printer."Station ID");
        if Printer."Printer Handle" = '' then
            Error('Printer %1 has no operating-system Printer Handle.', Printer.Code);
        ValidateAzurePrinterName(Printer."Printer Handle", Printer.Code);
        // Azure Service Bus is the durable hand-off. Agent liveness is shown as
        // health state, but must not reject a job while a workstation is briefly
        // offline; the selected printer remains Active and consumes on recovery.
    end;

    [TryFunction]
    procedure TryValidateAzurePrinter(Printer: Record "DOPSWHS Printer")
    begin
        ValidateAzurePrinter(Printer);
    end;

    procedure FinalizeAndScheduleAzureJob(var Queue: Record "DOPSWHS Print Job Queue")
    begin
        FinalizeAzureJob(Queue);
        ScheduleDispatch(Queue, CurrentDateTime());
    end;

    procedure FinalizeAzureJob(var Queue: Record "DOPSWHS Print Job Queue")
    begin
        if Queue.Channel <> Queue.Channel::AzureDirect then
            exit;
        if IsNullGuid(Queue.SystemId) then
            Error('The print queue row must be inserted before Azure dispatch is scheduled.');
        Queue."Cloud Job ID" := Queue.SystemId;
        Queue."Blob Name" := CopyStr(BuildBlobName(Queue), 1, MaxStrLen(Queue."Blob Name"));
        Queue.Modify(true);
        Log(Queue."Job ID", 'AzureQueued', StrSubstNo('Azure Direct job %1 queued for station %2.', CloudJobId(Queue), Queue."Station ID"));
    end;

    procedure ScheduleDispatch(Queue: Record "DOPSWHS Print Job Queue"; NotBefore: DateTime)
    begin
        if not TaskScheduler.CanCreateTask() then
            exit;
        if not TryCreateDispatchTask(Queue, NotBefore) then
            ClearLastError();
    end;

    [TryFunction]
    local procedure TryCreateDispatchTask(Queue: Record "DOPSWHS Print Job Queue"; NotBefore: DateTime)
    var
        TaskId: Guid;
    begin
        TaskId := TaskScheduler.CreateTask(
            Codeunit::"DOPSWHS Azure Dispatch Task",
            0,
            true,
            CompanyName(),
            NotBefore,
            Queue.RecordId());
    end;

    procedure DispatchJob(JobId: Integer)
    var
        Queue: Record "DOPSWHS Print Job Queue";
        Setup: Record "DOPSWHS Setup";
        ErrorText: Text;
    begin
        if not Queue.Get(JobId) then
            exit;
        if Queue.Channel <> Queue.Channel::AzureDirect then
            exit;
        if Queue.Status <> Queue.Status::Queued then
            exit;
        if Queue."Dispatched At" <> 0DT then
            exit;
        if (Queue."Next Retry At" <> 0DT) and (Queue."Next Retry At" > CurrentDateTime()) then
            exit;

        if TryDispatchJob(JobId) then
            exit;
        ErrorText := CopyStr(GetLastErrorText(), 1, MaxStrLen(Queue."Last Error"));
        ClearLastError();
        if ErrorText = '' then
            ErrorText := 'Azure dispatch failed without a detailed error.';
        Queue.LockTable();
        if not Queue.Get(JobId) then
            exit;
        if Queue.Status <> Queue.Status::Queued then
            exit;
        Queue."Retry Count" += 1;
        Queue."Last Error" := ErrorText;
        if not Setup.Get('') then
            Setup."Azure Dispatch Max Attempts" := 5;
        if Setup."Azure Dispatch Max Attempts" <= 0 then
            Setup."Azure Dispatch Max Attempts" := 5;
        if Queue."Retry Count" >= Setup."Azure Dispatch Max Attempts" then begin
            Queue.Status := Queue.Status::Failed;
            Queue."Completed At" := CurrentDateTime();
            Queue."Next Retry At" := 0DT;
            Queue.Modify(true);
            Log(JobId, 'AzureDispatchFailed', ErrorText);
            exit;
        end;
        Queue."Next Retry At" := CurrentDateTime() + RetryDelay(Queue."Retry Count");
        Queue.Modify(true);
        Log(JobId, 'AzureDispatchRetry', StrSubstNo('Attempt %1 failed; retry scheduled. %2', Queue."Retry Count", ErrorText));
        ScheduleDispatch(Queue, Queue."Next Retry At");
    end;

    [TryFunction]
    local procedure TryDispatchJob(JobId: Integer)
    var
        Queue: Record "DOPSWHS Print Job Queue";
        Printer: Record "DOPSWHS Printer";
        PayloadStream: InStream;
        HashStream: InStream;
        ActualHash: Text[64];
    begin
        ValidateConfiguration(false);
        Queue.Get(JobId);
        Queue.TestField(Channel, Queue.Channel::AzureDirect);
        Queue.TestField(Status, Queue.Status::Queued);
        Queue.TestField("Cloud Job ID");
        Queue.TestField("Station ID");
        Queue.TestField("Blob Name");
        Queue.TestField("Payload SHA256");
        if Queue."Cloud Job ID" <> Queue.SystemId then
            Error('Print job %1 cloud ID does not match its immutable SystemId.', Queue."Job ID");
        if Queue."Blob Name" <> BuildBlobName(Queue) then
            Error('Print job %1 blob name does not match the canonical Azure Direct path.', Queue."Job ID");
        ValidateStationId(Queue."Station ID");
        ValidateAzurePrinterId(Queue."Printer ID");
        if (Queue.Copies < 1) or (Queue.Copies > 10) then
            Error('Print job %1 copies must be between 1 and 10.', Queue."Job ID");
        if (Queue.Created = 0DT) or (Queue.Created < CurrentDateTime() - (30 * OneDay())) or
           (Queue.Created > CurrentDateTime() + (5 * 60 * 1000))
        then
            Error('Print job %1 creation time is outside the Azure Direct acceptance window.', Queue."Job ID");
        Printer.Get(CopyStr(Queue."Printer ID", 1, MaxStrLen(Printer.Code)));
        Printer.TestField(Active, true);
        Printer.TestField("Station ID", Queue."Station ID");
        Printer.TestField("Printer Handle");
        ValidateAzurePrinter(Printer);
        ValidateSha256(Queue."Payload SHA256");
        if (Queue."Payload Size" <= 0) or (Queue."Payload Size" > MaxPayloadBytes()) then
            Error('Print job %1 payload size must be between 1 byte and 50 MiB.', Queue."Job ID");
        Queue.CalcFields(ZPL);
        if not Queue.ZPL.HasValue() then
            Error('Print job %1 has no payload.', Queue."Job ID");
        Queue.ZPL.CreateInStream(HashStream);
        ActualHash := ComputePayloadSha256(HashStream);
        if ActualHash <> Queue."Payload SHA256" then
            Error('Print job %1 payload integrity validation failed.', Queue."Job ID");
        Queue.ZPL.CreateInStream(PayloadStream);
        UploadBlob(Queue."Blob Name", Queue."Format", Queue."Payload Size", PayloadStream);
        SendPrintJobMessage(Queue, Printer);

        Queue.LockTable();
        Queue.Get(JobId);
        if Queue.Status <> Queue.Status::Queued then
            Error('Print job %1 changed state during Azure dispatch.', JobId);
        Queue.Status := Queue.Status::Dispatched;
        Queue."Dispatched At" := CurrentDateTime();
        Queue."Next Retry At" := 0DT;
        Queue."Last Error" := '';
        Queue.Modify(true);
        Log(JobId, 'AzureDispatched', 'Blob uploaded and Service Bus accepted the print message.');
    end;

    procedure DispatchPending(MaxJobs: Integer)
    var
        Queue: Record "DOPSWHS Print Job Queue";
        JobIds: List of [Integer];
        JobId: Integer;
    begin
        if MaxJobs <= 0 then
            MaxJobs := 20;
        Queue.SetRange(Channel, Queue.Channel::AzureDirect);
        Queue.SetRange(Status, Queue.Status::Queued);
        Queue.SetRange("Dispatched At", 0DT);
        Queue.SetFilter("Next Retry At", '%1|<=%2', 0DT, CurrentDateTime());
        if Queue.FindSet() then
            repeat
                JobIds.Add(Queue."Job ID");
            until (Queue.Next() = 0) or (JobIds.Count() >= MaxJobs);
        foreach JobId in JobIds do
            DispatchJob(JobId);
    end;

    procedure MarkStaleDispatched(MaxJobs: Integer): Integer
    var
        Queue: Record "DOPSWHS Print Job Queue";
        StaleMessage: Text[250];
        Marked: Integer;
        Scanned: Integer;
    begin
        if MaxJobs <= 0 then
            MaxJobs := 100;
        StaleMessage := 'No agent result after 8 days. Inspect the agent outbox and Service Bus dead-letter queues before deciding whether to retry.';
        Queue.SetRange(Channel, Queue.Channel::AzureDirect);
        Queue.SetRange(Status, Queue.Status::Dispatched);
        Queue.SetFilter("Dispatched At", '<>%1&<=%2', 0DT, CurrentDateTime() - StaleResultAge());
        if Queue.FindSet(true) then
            repeat
                Scanned += 1;
                if Queue."Last Error" <> StaleMessage then begin
                    Queue."Last Error" := StaleMessage;
                    Queue.Modify(true);
                    Log(Queue."Job ID", 'AzureResultStale', StaleMessage);
                    Marked += 1;
                end;
            until (Queue.Next() = 0) or (Scanned >= MaxJobs);
        exit(Marked);
    end;

    procedure CountStaleDispatched(): Integer
    var
        Queue: Record "DOPSWHS Print Job Queue";
    begin
        Queue.SetRange(Channel, Queue.Channel::AzureDirect);
        Queue.SetRange(Status, Queue.Status::Dispatched);
        Queue.SetFilter("Dispatched At", '<>%1&<=%2', 0DT, CurrentDateTime() - StaleResultAge());
        exit(Queue.Count());
    end;

    procedure CountUnavailableActivePrinters(): Integer
    var
        Printer: Record "DOPSWHS Printer";
        Unavailable: Integer;
    begin
        Printer.SetRange(Active, true);
        Printer.SetFilter("Station ID", '<>%1', '');
        if Printer.FindSet() then
            repeat
                if not (Printer."Agent Status" in [Printer."Agent Status"::Online, Printer."Agent Status"::Printing]) or
                   (Printer."Last Seen At" = 0DT) or
                   (Printer."Last Seen At" < CurrentDateTime() - AgentFreshness())
                then
                    Unavailable += 1;
            until Printer.Next() = 0;
        exit(Unavailable);
    end;

    procedure ResolveStaleDispatchedAndRetry(JobId: Integer): Integer
    var
        Queue: Record "DOPSWHS Print Job Queue";
    begin
        Queue.LockTable();
        Queue.Get(JobId);
        Queue.TestField(Channel, Queue.Channel::AzureDirect);
        Queue.TestField(Status, Queue.Status::Dispatched);
        if (Queue."Dispatched At" = 0DT) or (Queue."Dispatched At" > CurrentDateTime() - StaleResultAge()) then
            Error('Azure Direct job %1 is not yet stale. Wait at least 8 days for the durable agent status outbox.', JobId);
        Queue.Status := Queue.Status::Failed;
        Queue."Completed At" := CurrentDateTime();
        Queue."Last Error" := 'Operator resolved stale dispatch and explicitly requested a new physical print attempt.';
        Queue.Modify(true);
        Log(JobId, 'AzureStaleResolved', Queue."Last Error");
        exit(CloneFailedJobForRetry(JobId));
    end;

    procedure CloneFailedJobForRetry(JobId: Integer): Integer
    var
        SourceQueue: Record "DOPSWHS Print Job Queue";
        NewQueue: Record "DOPSWHS Print Job Queue";
        Printer: Record "DOPSWHS Printer";
        SourceStream: InStream;
        TargetStream: OutStream;
    begin
        SourceQueue.Get(JobId);
        SourceQueue.TestField(Channel, SourceQueue.Channel::AzureDirect);
        SourceQueue.TestField(Status, SourceQueue.Status::Failed);
        SourceQueue.CalcFields(ZPL);
        if not SourceQueue.ZPL.HasValue() then
            Error('Failed job %1 no longer has a payload and cannot be retried.', JobId);
        if (SourceQueue."Payload Size" <= 0) or (SourceQueue."Payload Size" > MaxPayloadBytes()) then
            Error('Failed job %1 has an invalid payload size and cannot be retried.', JobId);
        ValidateSha256(SourceQueue."Payload SHA256");
        Printer.Get(CopyStr(SourceQueue."Printer ID", 1, MaxStrLen(Printer.Code)));
        ValidateAzurePrinter(Printer);
        if Printer."Format" <> SourceQueue."Format" then
            Error('Failed job %1 format no longer matches printer %2.', JobId, Printer.Code);

        NewQueue.Init();
        NewQueue."Source Doc" := SourceQueue."Source Doc";
        NewQueue."Report ID" := SourceQueue."Report ID";
        NewQueue."Printer ID" := SourceQueue."Printer ID";
        NewQueue.Status := NewQueue.Status::Queued;
        NewQueue.Channel := NewQueue.Channel::AzureDirect;
        NewQueue."Format" := SourceQueue."Format";
        NewQueue.Copies := SourceQueue.Copies;
        NewQueue.Created := CurrentDateTime();
        NewQueue."Payload Size" := SourceQueue."Payload Size";
        NewQueue."Payload SHA256" := SourceQueue."Payload SHA256";
        NewQueue."Station ID" := SourceQueue."Station ID";
        NewQueue."Correlation ID" := CopyStr('RETRY:' + CloudJobId(SourceQueue), 1, MaxStrLen(NewQueue."Correlation ID"));
        SourceQueue.ZPL.CreateInStream(SourceStream);
        NewQueue.ZPL.CreateOutStream(TargetStream);
        CopyStream(TargetStream, SourceStream);
        NewQueue.Insert(true);
        FinalizeAndScheduleAzureJob(NewQueue);
        Log(JobId, 'RetriedAsNewJob', StrSubstNo('Manual retry created print job %1.', NewQueue."Job ID"));
        exit(NewQueue."Job ID");
    end;

    [NonDebuggable]
    local procedure UploadBlob(BlobName: Text; PrintFormat: Enum "DOPSWHS Print Format"; PayloadSize: BigInteger; var PayloadStream: InStream)
    var
        Setup: Record "DOPSWHS Setup";
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Content: HttpContent;
        RequestHeaders: HttpHeaders;
        ContentHeaders: HttpHeaders;
        UploadSas: Text;
        RequestUrl: Text;
    begin
        Setup.Get('');
        GetRequiredLegacyTextSecret(BlobUploadSasKeyLbl, UploadSas, 'Blob create/write SAS token');
        if CopyStr(UploadSas, 1, 1) = '?' then
            UploadSas := CopyStr(UploadSas, 2);

        // ABS Blob Client escapes the complete blob name and changes virtual-path
        // separators from '/' to '%2F'. Azure then rejects jobs/<station>/<id>.
        // The job path is generated and validated internally, so preserve its
        // separators and send the standard Put Blob request directly.
        RequestUrl := StrSubstNo(
            'https://%1.%2/%3/%4?%5',
            Setup."Azure Storage Account",
            Setup."Azure Blob Endpoint Suffix",
            Setup."Azure Blob Container",
            BlobName,
            UploadSas);

        Content.WriteFrom(PayloadStream);
        Content.GetHeaders(ContentHeaders);
        if ContentHeaders.Contains('Content-Type') then
            ContentHeaders.Remove('Content-Type');
        if ContentHeaders.Contains('Content-Length') then
            ContentHeaders.Remove('Content-Length');
        ContentHeaders.Add('Content-Type', ContentTypeFor(PrintFormat));
        ContentHeaders.Add('Content-Length', Format(PayloadSize, 0, 9));

        Request.Method := 'PUT';
        Request.SetRequestUri(RequestUrl);
        Request.Content := Content;
        Request.GetHeaders(RequestHeaders);
        RequestHeaders.Add('x-ms-blob-type', 'BlockBlob');
        RequestHeaders.Add('x-ms-version', '2020-10-02');

        if not Client.Send(Request, Response) then
            Error('The print payload could not be uploaded to Azure Blob Storage.');
        if not Response.IsSuccessStatusCode() then
            Error(
                'Azure Blob rejected upload of %1 (HTTP %2). Verify the account, container and create/write SAS permissions.',
                BlobName,
                Response.HttpStatusCode());
    end;

    [NonDebuggable]
    local procedure SendPrintJobMessage(Queue: Record "DOPSWHS Print Job Queue"; Printer: Record "DOPSWHS Printer")
    var
        Setup: Record "DOPSWHS Setup";
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Content: HttpContent;
        Headers: HttpHeaders;
        Payload: JsonObject;
        BrokerProperties: JsonObject;
        PayloadText: Text;
        BrokerText: Text;
        EntityUrl: Text;
        RequestUrl: Text;
        SharedKey: SecretText;
        Authorization: SecretText;
        MessageId: Text;
    begin
        Setup.Get('');
        EntityUrl := BuildServiceBusEntityUrl(Setup."Azure Print Jobs Queue");
        RequestUrl := EntityUrl + '/messages?api-version=2017-04';
        GetRequiredSecret(JobsSharedKeyKeyLbl, SharedKey, 'Service Bus jobs Send policy key');
        Authorization := GenerateServiceBusSasToken(EntityUrl, Setup."Azure Jobs SAS Policy", SharedKey, 3600);
        MessageId := CloudJobId(Queue);

        Payload.Add('schemaVersion', 1);
        Payload.Add('jobId', MessageId);
        Payload.Add('tenantId', Setup."Azure Tenant Route ID");
        Payload.Add('companyId', Setup."Azure Company Route ID");
        Payload.Add('stationId', Queue."Station ID");
        Payload.Add('printerId', Queue."Printer ID");
        Payload.Add('printerName', Printer."Printer Handle");
        Payload.Add('format', FormatName(Queue."Format"));
        Payload.Add('copies', Queue.Copies);
        Payload.Add('blobName', Queue."Blob Name");
        Payload.Add('payloadSha256', Queue."Payload SHA256");
        Payload.Add('payloadSize', Queue."Payload Size");
        Payload.Add('createdAtUtc', FormatUtc(Queue.Created));
        Payload.WriteTo(PayloadText);

        BrokerProperties.Add('SessionId', Queue."Station ID");
        BrokerProperties.Add('MessageId', MessageId);
        BrokerProperties.Add('CorrelationId', MessageId);
        BrokerProperties.WriteTo(BrokerText);

        Request.Method := 'POST';
        Request.SetRequestUri(RequestUrl);
        Request.GetHeaders(Headers);
        Headers.Add('Authorization', Authorization);
        Headers.Add('BrokerProperties', BrokerText);
        Content.WriteFrom(PayloadText);
        Content.GetHeaders(Headers);
        if Headers.Contains('Content-Type') then
            Headers.Remove('Content-Type');
        // Service Bus maps the HTTP Content-Type header to the AMQP message
        // ContentType. The Windows agent deliberately requires this exact media
        // type, without an automatically appended charset parameter.
        Headers.Add('Content-Type', 'application/json');
        Request.Content := Content;
        if not Client.Send(Request, Response) then
            Error('The print message could not be sent to Azure Service Bus.');
        if not Response.IsSuccessStatusCode() then
            Error('Azure Service Bus rejected the print message (HTTP %1). Inspect Azure diagnostics using job/message ID %2.', Response.HttpStatusCode(), MessageId);
    end;

    [NonDebuggable]
    procedure GenerateServiceBusSasToken(ResourceUri: Text; PolicyName: Text; SharedKey: SecretText; LifetimeSeconds: Integer): SecretText
    var
        Cryptography: Codeunit "Cryptography Management";
        TypeHelper: Codeunit "Type Helper";
        EncodedUri: Text;
        Expiry: BigInteger;
        Epoch: DateTime;
        StringToSign: Text;
        Signature: Text;
        LF: Char;
    begin
        if LifetimeSeconds <= 0 then
            Error('The SAS lifetime must be positive.');
        EncodedUri := TypeHelper.UriEscapeDataString(LowerCase(ResourceUri));
        Epoch := CreateDateTime(DMY2Date(1, 1, 1970), 000000T);
        Expiry := Round((CurrentDateTime() - Epoch) / 1000, 1, '=') + LifetimeSeconds;
        LF := 10;
        StringToSign := EncodedUri + Format(LF) + Format(Expiry, 0, 9);
        // Azure Service Bus signs with the UTF-8 bytes of the SharedAccessKey
        // string. Do not Base64-decode the key before HMACSHA256.
        Signature := Cryptography.GenerateHashAsBase64String(StringToSign, SharedKey, 2);
        Signature := TypeHelper.UriEscapeDataString(Signature);
        exit(SecretStrSubstNo(
            'SharedAccessSignature sr=%1&sig=%2&se=%3&skn=%4',
            EncodedUri,
            Signature,
            Format(Expiry, 0, 9),
            TypeHelper.UriEscapeDataString(PolicyName)));
    end;

    procedure BuildServiceBusEntityUrl(QueueName: Text): Text
    var
        Setup: Record "DOPSWHS Setup";
    begin
        Setup.Get('');
        exit(LowerCase(StrSubstNo('https://%1.%2/%3', Setup."Azure SB Namespace", Setup."Azure SB Endpoint Suffix", QueueName)));
    end;

    procedure CloudJobId(Queue: Record "DOPSWHS Print Job Queue"): Text
    var
        JobGuid: Guid;
    begin
        JobGuid := Queue."Cloud Job ID";
        if IsNullGuid(JobGuid) then
            JobGuid := Queue.SystemId;
        exit(LowerCase(DelChr(Format(JobGuid), '=', '{}')));
    end;

    procedure Log(JobId: Integer; EventType: Text; MessageText: Text)
    var
        LogEntry: Record "DOPSWHS Print Job Log";
    begin
        LogEntry.Init();
        LogEntry."Job ID" := JobId;
        LogEntry.EventType := CopyStr(EventType, 1, MaxStrLen(LogEntry.EventType));
        LogEntry.Message := CopyStr(MessageText, 1, MaxStrLen(LogEntry.Message));
        LogEntry.DateTime := CurrentDateTime();
        LogEntry.Insert(true);
    end;

    local procedure BuildBlobName(Queue: Record "DOPSWHS Print Job Queue"): Text
    begin
        exit(StrSubstNo('jobs/%1/%2.%3', Queue."Station ID", CloudJobId(Queue), LowerCase(FormatName(Queue."Format"))));
    end;

    local procedure FormatName(PrintFormat: Enum "DOPSWHS Print Format"): Text
    begin
        case PrintFormat of
            PrintFormat::ZPL:
                exit('ZPL');
            PrintFormat::PDF:
                exit('PDF');
            PrintFormat::ESCPOS:
                exit('ESCPOS');
            PrintFormat::RAW:
                exit('RAW');
            else
                Error('Unsupported print format %1.', PrintFormat);
        end;
    end;

    local procedure ContentTypeFor(PrintFormat: Enum "DOPSWHS Print Format"): Text
    begin
        case PrintFormat of
            PrintFormat::PDF:
                exit('application/pdf');
            PrintFormat::ZPL:
                exit('application/vnd.zebra-zpl');
            else
                exit('application/octet-stream');
        end;
    end;

    local procedure FormatUtc(Value: DateTime): Text
    begin
        if Value = 0DT then
            exit('');
        exit(Format(Value, 0, 9));
    end;

    local procedure RetryDelay(RetryCount: Integer): Duration
    begin
        case RetryCount of
            1:
                exit(15 * 1000);
            2:
                exit(60 * 1000);
            3:
                exit(5 * 60 * 1000);
            else
                exit(15 * 60 * 1000);
        end;
    end;

    local procedure StaleResultAge(): Duration
    begin
        exit(8 * OneDay());
    end;

    local procedure AgentFreshness(): Duration
    begin
        exit(15 * 60 * 1000);
    end;

    local procedure OneDay(): Duration
    begin
        exit(24 * 60 * 60 * 1000);
    end;

    procedure MaxPayloadBytes(): Integer
    begin
        // Kept in lockstep with Windows agent AgentSettings.MaxPayloadBytes.
        exit(50 * 1024 * 1024);
    end;

    procedure BlobSasExpiresSoon(): Boolean
    var
        Setup: Record "DOPSWHS Setup";
    begin
        if not Setup.Get('') then
            exit(false);
        if Setup."Azure Blob SAS Expires At" = 0DT then
            exit(false);
        exit(Setup."Azure Blob SAS Expires At" <= CurrentDateTime() + ExpiryWarningWindow());
    end;

    procedure WarnIfBlobSasExpiresSoon()
    var
        Setup: Record "DOPSWHS Setup";
        Telemetry: Codeunit "DOPSWHS Telemetry";
        Dimensions: Dictionary of [Text, Text];
    begin
        if not Setup.Get('') then
            exit;
        if Setup."Azure Blob SAS Expires At" = 0DT then
            exit;
        if Setup."Azure Blob SAS Expires At" > CurrentDateTime() + ExpiryWarningWindow() then
            exit;
        if (Setup."Azure Expiry Warning At" <> 0DT) and
           (Setup."Azure Expiry Warning At" > CurrentDateTime() - OneDay())
        then
            exit;

        Dimensions.Add('expiresAtUtc', FormatUtc(Setup."Azure Blob SAS Expires At"));
        if Setup."Azure Blob SAS Expires At" <= CurrentDateTime() then
            Dimensions.Add('state', 'expired')
        else
            Dimensions.Add('state', 'expires-soon');
        Telemetry.Log(
            'AzurePrint.BlobSasExpiry',
            'Azure Direct Blob upload SAS is expired or expires within seven days.',
            Verbosity::Warning,
            Dimensions);
        Setup."Azure Expiry Warning At" := CurrentDateTime();
        Setup.Modify(true);
    end;

    [NonDebuggable]
    procedure GetStatusSharedKey(var SharedKey: SecretText)
    begin
        GetRequiredSecret(StatusSharedKeyKeyLbl, SharedKey, 'Service Bus status Listen policy key');
    end;

    local procedure RequireJsonObject(Parent: JsonObject; PropertyName: Text): JsonObject
    var
        Token: JsonToken;
    begin
        if not Parent.Get(PropertyName, Token) or not Token.IsObject() then
            Error('Runtime configuration property %1 is missing or is not an object.', PropertyName);
        exit(Token.AsObject());
    end;

    local procedure RequireJsonText(Parent: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
        Value: Text;
    begin
        if not Parent.Get(PropertyName, Token) or not Token.IsValue() then
            Error('Runtime configuration property %1 is missing.', PropertyName);
        Value := Token.AsValue().AsText();
        if Value = '' then
            Error('Runtime configuration property %1 is empty.', PropertyName);
        exit(Value);
    end;

    local procedure RequireJsonUtcDateTime(Parent: JsonObject; PropertyName: Text): DateTime
    var
        Token: JsonToken;
        ValueText: Text;
    begin
        ValueText := RequireJsonText(Parent, PropertyName);
        if not IsCanonicalUtcTimestamp(ValueText) then
            Error('Runtime configuration property %1 must be an ISO-8601 UTC timestamp.', PropertyName);
        if not Parent.Get(PropertyName, Token) or not Token.IsValue() then
            Error('Runtime configuration property %1 is missing.', PropertyName);
        exit(Token.AsValue().AsDateTime());
    end;

    local procedure IsCanonicalUtcTimestamp(Value: Text): Boolean
    begin
        if (Value = '') or (StrPos(Value, 'T') = 0) then
            exit(false);
        if CopyStr(Value, StrLen(Value), 1) = 'Z' then
            exit(true);
        if (StrLen(Value) >= 6) and (CopyStr(Value, StrLen(Value) - 5, 6) = '+00:00') then
            exit(true);
        exit(false);
    end;

    local procedure ValidateBlobSasExpiry(BlobSasExpiresAt: DateTime)
    begin
        if BlobSasExpiresAt = 0DT then
            Error('Blob SAS Expires At is required when configuring a Blob upload SAS token.');
        if BlobSasExpiresAt <= CurrentDateTime() + (5 * 60 * 1000) then
            Error('The Blob upload SAS must remain valid for at least five minutes. Generate a new credential.');
    end;

    [NonDebuggable]
    local procedure ParseServiceBusConnectionString(ConnectionString: Text; var NamespaceName: Text; var EndpointSuffix: Text; var EntityPath: Text; var PolicyName: Text; var SharedKey: Text)
    var
        Endpoint: Text;
        Host: Text;
        DotPosition: Integer;
    begin
        Endpoint := GetConnectionStringValue(ConnectionString, 'Endpoint');
        EntityPath := GetConnectionStringValue(ConnectionString, 'EntityPath');
        PolicyName := GetConnectionStringValue(ConnectionString, 'SharedAccessKeyName');
        SharedKey := GetConnectionStringValue(ConnectionString, 'SharedAccessKey');
        if (Endpoint = '') or (EntityPath = '') or (PolicyName = '') or (SharedKey = '') then
            Error('A Service Bus connection string is missing Endpoint, EntityPath, SharedAccessKeyName or SharedAccessKey.');
        if CopyStr(LowerCase(Endpoint), 1, 5) <> 'sb://' then
            Error('Service Bus Endpoint must start with sb://.');
        Host := DelChr(CopyStr(Endpoint, 6), '>', '/');
        DotPosition := StrPos(Host, '.');
        if DotPosition <= 1 then
            Error('Service Bus Endpoint host is invalid.');
        NamespaceName := CopyStr(Host, 1, DotPosition - 1);
        EndpointSuffix := CopyStr(Host, DotPosition + 1);
    end;

    [NonDebuggable]
    local procedure GetConnectionStringValue(ConnectionString: Text; Name: Text): Text
    var
        Parts: List of [Text];
        Part: Text;
        Separator: Integer;
    begin
        Parts := ConnectionString.Split(';');
        foreach Part in Parts do begin
            Separator := StrPos(Part, '=');
            if (Separator > 1) and (LowerCase(CopyStr(Part, 1, Separator - 1)) = LowerCase(Name)) then
                exit(CopyStr(Part, Separator + 1));
        end;
        exit('');
    end;

    local procedure ParseBlobContainerUrl(BlobContainerUrl: Text; var Setup: Record "DOPSWHS Setup")
    var
        WithoutScheme: Text;
        Host: Text;
        ContainerName: Text;
        SlashPosition: Integer;
        DotPosition: Integer;
    begin
        if CopyStr(BlobContainerUrl, 1, 8) <> 'https://' then
            Error('blobContainerUrl must use HTTPS.');
        if (StrPos(BlobContainerUrl, '?') > 0) or (StrPos(BlobContainerUrl, '#') > 0) then
            Error('blobContainerUrl must not contain a query string or fragment.');
        WithoutScheme := CopyStr(BlobContainerUrl, 9);
        SlashPosition := StrPos(WithoutScheme, '/');
        if SlashPosition <= 1 then
            Error('blobContainerUrl must include a container name.');
        Host := CopyStr(WithoutScheme, 1, SlashPosition - 1);
        ContainerName := CopyStr(WithoutScheme, SlashPosition + 1);
        if (ContainerName = '') or (StrPos(ContainerName, '/') > 0) then
            Error('blobContainerUrl must contain exactly one container path segment.');
        DotPosition := StrPos(Host, '.');
        if DotPosition <= 1 then
            Error('blobContainerUrl host is invalid.');
        Setup.Validate("Azure Storage Account", CopyStr(Host, 1, DotPosition - 1));
        Setup."Azure Blob Endpoint Suffix" := CopyStr(Host, DotPosition + 1, MaxStrLen(Setup."Azure Blob Endpoint Suffix"));
        Setup.Validate("Azure Blob Container", ContainerName);
        if Setup."Azure Blob Endpoint Suffix" <> 'blob.core.windows.net' then
            Error('business-central.runtime.secrets.json must use Azure public Blob Storage.');
        if Setup."Azure Blob Container" <> 'print-jobs' then
            Error('business-central.runtime.secrets.json must target the private print-jobs container.');
    end;

    local procedure ParseStationRoute(StationId: Text; var TenantRouteId: Text; var CompanyRouteId: Text)
    var
        Segments: List of [Text];
    begin
        ValidateCanonicalStationId(StationId);
        Segments := StationId.Split('.');
        TenantRouteId := Segments.Get(1);
        CompanyRouteId := Segments.Get(2);
    end;

    local procedure ValidateCanonicalStationId(StationId: Text)
    var
        Segments: List of [Text];
        Segment: Text;
    begin
        if (StrLen(StationId) < 7) or (StrLen(StationId) > 128) then
            Error('Station ID must contain between 7 and 128 characters.');
        if StationId <> UpperCase(StationId) then
            Error('Station ID %1 must be uppercase.', StationId);
        ValidateSafeIdentifier(StationId, 'Station ID', true);
        Segments := StationId.Split('.');
        if Segments.Count() <> 4 then
            Error('Station ID %1 must use TENANT.COMPANY.WAREHOUSE.STATION format.', StationId);
        foreach Segment in Segments do
            ValidateRouteToken(Segment, 'Station ID segment');
    end;

    local procedure ValidateImportedServiceBusMetadata(JobsNamespace: Text; JobsSuffix: Text; JobsQueue: Text; JobsPolicy: Text; StatusNamespace: Text; StatusSuffix: Text; StatusQueue: Text; StatusPolicy: Text)
    begin
        if JobsNamespace <> LowerCase(JobsNamespace) then
            Error('Service Bus namespace must already be lowercase canonical text.');
        ValidateDnsLabel(JobsNamespace, 6, 50, 'Service Bus namespace');
        if StatusNamespace <> JobsNamespace then
            Error('The jobs and status connection strings must use the exact same Service Bus namespace.');
        if (JobsSuffix <> 'servicebus.windows.net') or (StatusSuffix <> 'servicebus.windows.net') then
            Error('business-central.runtime.secrets.json must use Azure public Service Bus (servicebus.windows.net).');
        if JobsQueue <> 'print-jobs-queue' then
            Error('The jobs connection string must target print-jobs-queue.');
        if StatusQueue <> 'printer-status-queue' then
            Error('The status connection string must target printer-status-queue.');
        if JobsPolicy <> 'bc-send-jobs' then
            Error('The jobs connection string must use queue-scoped policy bc-send-jobs. RootManageSharedAccessKey is not allowed.');
        if StatusPolicy <> 'bc-listen-status' then
            Error('The status connection string must use queue-scoped policy bc-listen-status. RootManageSharedAccessKey is not allowed.');
    end;

    local procedure ValidateDnsLabel(Value: Text; MinimumLength: Integer; MaximumLength: Integer; FieldCaption: Text)
    var
        Allowed: Text;
        Position: Integer;
    begin
        if (StrLen(Value) < MinimumLength) or (StrLen(Value) > MaximumLength) then
            Error('%1 must contain between %2 and %3 characters.', FieldCaption, MinimumLength, MaximumLength);
        Allowed := 'abcdefghijklmnopqrstuvwxyz0123456789-';
        for Position := 1 to StrLen(Value) do
            if StrPos(Allowed, Format(Value[Position])) = 0 then
                Error('%1 may contain only lowercase letters, digits and hyphens.', FieldCaption);
        if (Value[1] = '-') or (Value[StrLen(Value)] = '-') then
            Error('%1 cannot start or end with a hyphen.', FieldCaption);
    end;

    local procedure ValidateStorageAccount(Value: Text)
    var
        Position: Integer;
        Allowed: Text;
    begin
        if (StrLen(Value) < 3) or (StrLen(Value) > 24) then
            Error('Storage Account must contain between 3 and 24 characters.');
        Allowed := 'abcdefghijklmnopqrstuvwxyz0123456789';
        for Position := 1 to StrLen(Value) do
            if StrPos(Allowed, Format(Value[Position])) = 0 then
                Error('Storage Account may contain only lowercase letters and digits.');
    end;

    local procedure ValidateContainer(Value: Text)
    begin
        if (StrLen(Value) < 3) or (StrLen(Value) > 63) then
            Error('Print Blob Container must contain between 3 and 63 characters.');
        // Validate the original ASCII text. UpperCase() is language-sensitive in AL;
        // for example, Turkish converts the "i" in print-jobs to a dotted capital I.
        ValidateSafeIdentifier(Value, 'Print Blob Container', false);
        if StrPos(Value, '_') > 0 then
            Error('Print Blob Container cannot contain underscores.');
        if (Value <> LowerCase(Value)) or (Value[1] = '-') or (Value[StrLen(Value)] = '-') or
           (StrPos(Value, '--') > 0)
        then
            Error('Print Blob Container must be lowercase, start/end with a letter or digit, and cannot contain consecutive hyphens.');
    end;

    local procedure ValidateEntityName(Value: Text; FieldCaption: Text)
    begin
        if (StrLen(Value) < 1) or (StrLen(Value) > 260) then
            Error('%1 must contain between 1 and 260 characters.', FieldCaption);
        // Service Bus entity names are case-sensitive. Do not normalize them with
        // a language-sensitive UpperCase() call before validating their characters.
        ValidateSafeIdentifier(Value, FieldCaption, true);
    end;

    local procedure ValidateEndpointSuffix(Value: Text; FieldCaption: Text)
    begin
        if (Value = '') or (StrPos(Value, '://') > 0) or (StrPos(Value, '/') > 0) or (StrPos(Value, ' ') > 0) then
            Error('%1 must be a DNS suffix without protocol, slash or spaces.', FieldCaption);
    end;

    [NonDebuggable]
    local procedure ValidateBlobUploadSas(SasToken: Text)
    var
        Permissions: Text;
        SignedIdentifier: Text;
        Protocol: Text;
        ResourceType: Text;
        Position: Integer;
    begin
        if CopyStr(SasToken, 1, 1) = '?' then
            SasToken := CopyStr(SasToken, 2);
        if (StrPos(SasToken, '://') > 0) or (StrPos(SasToken, '#') > 0) then
            Error('The Blob upload credential must be a SAS query token, not a URL.');
        if (GetQueryValue(SasToken, 'sv') = '') or (GetQueryValue(SasToken, 'sig') = '') then
            Error('The Blob upload SAS token is missing sv or sig.');
        Protocol := LowerCase(GetQueryValue(SasToken, 'spr'));
        if Protocol <> 'https' then
            Error('The Blob upload SAS token must be restricted to HTTPS (spr=https).');
        ResourceType := LowerCase(GetQueryValue(SasToken, 'sr'));
        if ResourceType <> 'c' then
            Error('The Blob upload SAS token must be scoped to the print-jobs container (sr=c).');
        SignedIdentifier := LowerCase(GetQueryValue(SasToken, 'si'));
        Permissions := LowerCase(GetQueryValue(SasToken, 'sp'));
        if SignedIdentifier <> '' then begin
            if SignedIdentifier <> 'bc-upload' then
                Error('The Blob stored access policy must be named bc-upload.');
            exit;
        end;
        if (StrPos(Permissions, 'c') = 0) or (StrPos(Permissions, 'w') = 0) then
            Error('The Blob upload SAS token must include create and write permissions.');
        for Position := 1 to StrLen(Permissions) do
            if StrPos('cw', Format(Permissions[Position])) = 0 then
                Error('The Blob upload SAS token may contain only create and write permissions.');
    end;

    [NonDebuggable]
    local procedure ValidateSharedAccessKey(SharedKey: Text; PolicyDescription: Text)
    var
        ControlCharacter: Char;
        ControlNumber: Integer;
    begin
        if (StrLen(SharedKey) < 16) or (StrLen(SharedKey) > 256) then
            Error('The Service Bus %1 policy key must contain between 16 and 256 characters.', PolicyDescription);
        if DelChr(SharedKey, '=', ' ') = '' then
            Error('The Service Bus %1 policy key cannot be blank.', PolicyDescription);
        for ControlNumber := 1 to 31 do begin
            ControlCharacter := ControlNumber;
            if StrPos(SharedKey, Format(ControlCharacter)) > 0 then
                Error('The Service Bus %1 policy key contains a control character.', PolicyDescription);
        end;
        ControlCharacter := 127;
        if StrPos(SharedKey, Format(ControlCharacter)) > 0 then
            Error('The Service Bus %1 policy key contains a control character.', PolicyDescription);
    end;

    [NonDebuggable]
    local procedure GetQueryValue(QueryText: Text; Name: Text): Text
    var
        Parts: List of [Text];
        Part: Text;
        Separator: Integer;
    begin
        Parts := QueryText.Split('&');
        foreach Part in Parts do begin
            Separator := StrPos(Part, '=');
            if (Separator > 1) and (LowerCase(CopyStr(Part, 1, Separator - 1)) = LowerCase(Name)) then
                exit(CopyStr(Part, Separator + 1));
        end;
        exit('');
    end;

    local procedure ValidateRouteToken(Value: Text; FieldCaption: Text)
    begin
        if (Value = '') or (StrLen(Value) > 32) then
            Error('%1 must contain between 1 and 32 characters.', FieldCaption);
        if Value <> UpperCase(Value) then
            Error('%1 must be uppercase.', FieldCaption);
        if StrPos('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', CopyStr(Value, 1, 1)) = 0 then
            Error('%1 must start with an uppercase letter or digit.', FieldCaption);
        ValidateSafeIdentifier(Value, FieldCaption, false);
    end;

    local procedure ValidateSafeIdentifier(Value: Text; FieldCaption: Text; AllowPeriod: Boolean)
    var
        Allowed: Text;
        Position: Integer;
    begin
        Allowed := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';
        if AllowPeriod then
            Allowed += '.';
        for Position := 1 to StrLen(Value) do
            if StrPos(Allowed, Format(Value[Position])) = 0 then
                Error('%1 contains an unsupported character.', FieldCaption);
    end;

    local procedure ValidateSha256(Value: Text)
    var
        Position: Integer;
    begin
        if StrLen(Value) <> 64 then
            Error('The print payload SHA-256 value must contain 64 hexadecimal characters.');
        for Position := 1 to 64 do
            if StrPos('0123456789ABCDEF', Format(Value[Position])) = 0 then
                Error('The print payload SHA-256 value must contain only uppercase hexadecimal characters.');
    end;

    procedure ValidateAzurePrinterName(PrinterName: Text; PrinterId: Text)
    var
        ControlCharacter: Char;
        ControlNumber: Integer;
    begin
        if (PrinterName = '') or (DelChr(PrinterName, '=', ' ') = '') then
            Error('Azure Direct printer %1 must have a non-blank operating-system name.', PrinterId);
        if StrLen(PrinterName) > 260 then
            Error('Printer %1 operating-system name exceeds 260 characters.', PrinterId);
        for ControlNumber := 1 to 31 do begin
            ControlCharacter := ControlNumber;
            if StrPos(PrinterName, Format(ControlCharacter)) > 0 then
                Error('Printer %1 operating-system name contains a control character.', PrinterId);
        end;
        ControlCharacter := 127;
        if StrPos(PrinterName, Format(ControlCharacter)) > 0 then
            Error('Printer %1 operating-system name contains a control character.', PrinterId);
    end;

    local procedure ExpiryWarningWindow(): Duration
    begin
        exit(7 * OneDay());
    end;

    [NonDebuggable]
    local procedure StoreSecret(StorageKey: Text; Value: Text)
    begin
        if Value = '' then
            Error('A required Azure credential is empty.');
        if StorageKey = BlobUploadSasKeyLbl then
            ValidateBlobUploadSas(Value);
        if EncryptionEnabled() then begin
            if not IsolatedStorage.SetEncrypted(StorageKey, Value, DataScope::Company) then
                Error('Business Central could not store an Azure credential securely.');
        end else
            if not IsolatedStorage.Set(StorageKey, Value, DataScope::Company) then
                Error('Business Central could not store an Azure credential in Isolated Storage.');
    end;

    local procedure HasSecret(StorageKey: Text): Boolean
    begin
        exit(IsolatedStorage.Contains(StorageKey, DataScope::Company));
    end;

    local procedure DeleteSecret(StorageKey: Text)
    begin
        if IsolatedStorage.Contains(StorageKey, DataScope::Company) then
            IsolatedStorage.Delete(StorageKey, DataScope::Company);
    end;

    [NonDebuggable]
    local procedure GetRequiredSecret(StorageKey: Text; var Value: SecretText; Description: Text)
    begin
        Clear(Value);
        if not IsolatedStorage.Get(StorageKey, DataScope::Company, Value) then
            Error('%1 is not configured in Isolated Storage.', Description);
        if Value.IsEmpty() then
            Error('%1 is empty in Isolated Storage.', Description);
    end;

    // BC 24 requires the Blob SAS in the request URI. Keep the unavoidable Text
    // conversion inside this non-debuggable compatibility boundary; every
    // Service Bus credential remains SecretText.
    [NonDebuggable]
    local procedure GetRequiredLegacyTextSecret(StorageKey: Text; var Value: Text; Description: Text)
    begin
        Clear(Value);
        if not IsolatedStorage.Get(StorageKey, DataScope::Company, Value) then
            Error('%1 is not configured in Isolated Storage.', Description);
        if Value = '' then
            Error('%1 is empty in Isolated Storage.', Description);
    end;

    var
        BlobUploadSasKeyLbl: Label 'DOPSWHS.AzurePrint.BlobUploadSas', Locked = true;
        JobsSharedKeyKeyLbl: Label 'DOPSWHS.AzurePrint.JobsSharedKey', Locked = true;
        StatusSharedKeyKeyLbl: Label 'DOPSWHS.AzurePrint.StatusSharedKey', Locked = true;
}
