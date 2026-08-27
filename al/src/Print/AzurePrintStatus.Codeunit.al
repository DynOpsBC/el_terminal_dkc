codeunit 72375 "DOPSWHS Azure Print Status"
{
    Access = Internal;
    Permissions =
        tabledata "DOPSWHS Setup" = rimd,
        tabledata "DOPSWHS Printer" = rimd,
        tabledata "DOPSWHS Print Job Queue" = rimd,
        tabledata "DOPSWHS Print Job Log" = rimd;

    procedure Poll(MaxMessages: Integer)
    var
        Processed: Integer;
    begin
        if MaxMessages <= 0 then
            MaxMessages := 20;
        // Keep consuming durable agent results even if the independent Blob
        // upload credential has expired and new dispatches are blocked.
        AzureBridge.ValidateStatusConfiguration();
        while Processed < MaxMessages do begin
            if not ReceiveOne() then
                exit;
            Processed += 1;
        end;
    end;

    procedure MarkStalePrinters(MaxPrinters: Integer): Integer
    var
        Printer: Record "DOPSWHS Printer";
        Marked: Integer;
    begin
        if MaxPrinters <= 0 then
            MaxPrinters := 100;
        Printer.SetFilter("Station ID", '<>%1', '');
        Printer.SetFilter("Last Seen At", '<>%1&<%2', 0DT, CurrentDateTime() - LiveStatusFreshness());
        Printer.SetFilter("Agent Status", '%1|%2', Printer."Agent Status"::Online, Printer."Agent Status"::Printing);
        if Printer.FindSet(true) then
            repeat
                Printer."Agent Status" := Printer."Agent Status"::Offline;
                Printer."Last Status Message" := 'No fresh agent heartbeat/snapshot in the last 15 minutes.';
                Printer.Modify(true);
                Marked += 1;
            until (Printer.Next() = 0) or (Marked >= MaxPrinters);
        exit(Marked);
    end;

    [NonDebuggable]
    local procedure ReceiveOne(): Boolean
    var
        Setup: Record "DOPSWHS Setup";
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Content: HttpContent;
        Headers: HttpHeaders;
        SharedKey: SecretText;
        Authorization: SecretText;
        EntityUrl: Text;
        ReceiveUrl: Text;
        LockUrl: Text;
        Body: Text;
        ErrorText: Text;
        ForeignMessageId: Text;
    begin
        Setup.Get('');
        EntityUrl := AzureBridge.BuildServiceBusEntityUrl(Setup."Azure Printer Status Queue");
        ReceiveUrl := EntityUrl + '/messages/head?timeout=1&api-version=2017-04';
        AzureBridge.GetStatusSharedKey(SharedKey);
        Authorization := AzureBridge.GenerateServiceBusSasToken(EntityUrl, Setup."Azure Status SAS Policy", SharedKey, 3600);

        Request.Method := 'POST';
        Request.SetRequestUri(ReceiveUrl);
        Request.GetHeaders(Headers);
        Headers.Add('Authorization', Authorization);
        Content.WriteFrom('');
        Request.Content := Content;
        if not Client.Send(Request, Response) then
            Error('The printer status queue could not be reached.');
        if Response.HttpStatusCode() = 204 then
            exit(false);
        if not Response.IsSuccessStatusCode() then
            Error('Azure Service Bus status receive failed (HTTP %1).', Response.HttpStatusCode());
        Response.Content().ReadAs(Body);
        LockUrl := GetResponseHeader(Response, 'Location');
        ValidateLockUrl(EntityUrl, LockUrl);

        if IsForeignOwnedMessage(Body, ForeignMessageId) then begin
            CompleteMessage(EntityUrl, LockUrl, Setup, SharedKey);
            LogSecurityWarning(
                'A foreign tenant/company printer-status message was ignored and completed.',
                ForeignMessageId,
                '');
            exit(true);
        end;

        if TryProcessMessage(Body) then begin
            // Persist the idempotent BC state before broker settlement. If
            // DELETE fails, Azure redelivers and the same message is harmless.
            Commit();
            CompleteMessage(EntityUrl, LockUrl, Setup, SharedKey);
            exit(true);
        end;

        ErrorText := CopyStr(GetLastErrorText(), 1, 250);
        ClearLastError();
        AbandonMessage(EntityUrl, LockUrl, Setup, SharedKey);
        LogSecurityWarning('Printer-status message processing failed and the message was abandoned.', '', ErrorText);
        exit(false);
    end;

    [TryFunction]
    local procedure TryProcessMessage(Body: Text)
    var
        Root: JsonObject;
        MessageType: Text;
    begin
        if StrLen(Body) > MaxStatusMessageCharacters() then
            Error('Printer-status message exceeds the 1 MiB processing limit.');
        if not Root.ReadFrom(Body) then
            Error('Printer-status message is not valid JSON.');
        RequireSchemaV1(Root);
        ValidateOwnedMessage(Root);
        MessageType := LowerCase(RequireText(Root, 'messageType'));
        case MessageType of
            'printersnapshot':
                ProcessPrinterSnapshot(Root);
            'heartbeat':
                ProcessHeartbeat(Root);
            'jobresult':
                ProcessJobResult(Root);
            else
                Error('Unsupported printer-status message type %1.', MessageType);
        end;
    end;

    local procedure ProcessPrinterSnapshot(Root: JsonObject)
    var
        Printer: Record "DOPSWHS Printer";
        Printers: JsonArray;
        PrinterToken: JsonToken;
        SeenPrinterIds: List of [Text];
        SnapshotPrinterIds: List of [Text];
        StationId: Code[128];
        AgentId: Code[50];
        AgentVersion: Text[50];
        SnapshotAt: DateTime;
        PrinterId: Text;
    begin
        StationId := CopyStr(RequireText(Root, 'stationId'), 1, MaxStrLen(StationId));
        AgentId := CopyStr(RequireText(Root, 'agentId'), 1, MaxStrLen(AgentId));
        AgentVersion := CopyStr(RequireText(Root, 'agentVersion'), 1, MaxStrLen(AgentVersion));
        SnapshotAt := RequireUtcDateTime(Root, 'sentAtUtc');
        Printers := RequireArray(Root, 'printers');
        if Printers.Count() > 256 then
            Error('Printer snapshot cannot contain more than 256 printer entries.');
        foreach PrinterToken in Printers do begin
            if not PrinterToken.IsObject() then
                Error('Printer snapshot contains a non-object printer entry.');
            PrinterId := RequireText(PrinterToken.AsObject(), 'printerId');
            ValidatePrinterId(PrinterId);
            if SnapshotPrinterIds.Contains(PrinterId) then
                Error('Printer snapshot contains duplicate printer ID %1.', PrinterId);
            SnapshotPrinterIds.Add(PrinterId);
            ValidateSnapshotPrinterContract(PrinterToken.AsObject());
        end;
        if SnapshotAt < CurrentDateTime() - LiveStatusFreshness() then
            exit;
        if StationHasNewerStatus(StationId, SnapshotAt) then
            exit;
        foreach PrinterToken in Printers do begin
            PrinterId := RequireText(PrinterToken.AsObject(), 'printerId');
            if UpsertSnapshotPrinter(PrinterToken.AsObject(), PrinterId, StationId, AgentId, AgentVersion, SnapshotAt) then
                SeenPrinterIds.Add(PrinterId);
        end;

        Printer.SetRange("Station ID", StationId);
        Printer.SetRange("Discovered by Agent", true);
        if Printer.FindSet(true) then
            repeat
                if not SeenPrinterIds.Contains(Printer.Code) and
                   ((Printer."Last Status At" = 0DT) or (Printer."Last Status At" <= SnapshotAt))
                then begin
                    Printer.Active := false;
                    Printer."Agent Status" := Printer."Agent Status"::Offline;
                    Printer."Last Status At" := SnapshotAt;
                    Printer."Last Status Message" := 'Not present in the latest agent snapshot.';
                    Printer.Modify(true);
                end;
            until Printer.Next() = 0;
    end;

    local procedure ValidateSnapshotPrinterContract(PrinterObject: JsonObject)
    var
        Printer: Record "DOPSWHS Printer";
        FormatText: Text;
        PrinterName: Text;
        ParsedFormat: Enum "DOPSWHS Print Format";
    begin
        PrinterName := RequireText(PrinterObject, 'printerName');
        if StrLen(PrinterName) > MaxStrLen(Printer."Printer Handle") then
            Error('Printer snapshot printerName exceeds %1 characters.', MaxStrLen(Printer."Printer Handle"));
        AzureBridge.ValidateAzurePrinterName(PrinterName, RequireText(PrinterObject, 'printerId'));
        FormatText := RequireText(PrinterObject, 'format');
        if FormatText <> UpperCase(FormatText) then
            Error('Printer snapshot format must use canonical uppercase text.');
        ParsedFormat := ParseFormat(FormatText);
        RequireText(PrinterObject, 'status');
        RequireBoolean(PrinterObject, 'isDefault');
    end;

    local procedure UpsertSnapshotPrinter(PrinterObject: JsonObject; PrinterIdText: Text; StationId: Code[128]; AgentId: Code[50]; AgentVersion: Text[50]; SnapshotAt: DateTime): Boolean
    var
        Printer: Record "DOPSWHS Printer";
        PrinterCode: Code[20];
        PrinterName: Text;
        StatusText: Text;
        FormatText: Text;
        IsNew: Boolean;
    begin
        ValidatePrinterId(PrinterIdText);
        PrinterCode := CopyStr(PrinterIdText, 1, MaxStrLen(PrinterCode));
        PrinterName := RequireText(PrinterObject, 'printerName');
        if StrLen(PrinterName) > MaxStrLen(Printer."Printer Handle") then
            Error('Printer name for %1 exceeds %2 characters.', PrinterCode, MaxStrLen(Printer."Printer Handle"));
        StatusText := LowerCase(RequireText(PrinterObject, 'status'));
        IsNew := not Printer.Get(PrinterCode);
        if IsNew then begin
            Printer.Init();
            Printer.Code := PrinterCode;
            Printer.Validate("Station ID", StationId);
            Printer."Discovered by Agent" := true;
            Printer."Default Copies" := 1;
            Printer.Port := 9100;
            Printer.Insert(true);
        end else begin
            if Printer."Station ID" <> StationId then begin
                LogSecurityWarning(
                    'Printer ID collision rejected; an existing printer belongs to another station.',
                    PrinterIdText,
                    StrSubstNo('Existing=%1 Incoming=%2', Printer."Station ID", StationId));
                exit(false);
            end;
            if (Printer."Last Status At" <> 0DT) and (Printer."Last Status At" > SnapshotAt) then
                exit(true);
        end;

        Printer.Description := CopyStr(PrinterName, 1, MaxStrLen(Printer.Description));
        Printer."Printer Handle" := CopyStr(PrinterName, 1, MaxStrLen(Printer."Printer Handle"));
        FormatText := RequireText(PrinterObject, 'format');
        if FormatText <> UpperCase(FormatText) then
            Error('Printer snapshot format for %1 must use canonical uppercase text.', PrinterCode);
        Printer.Validate("Format", ParseFormat(FormatText));
        Printer."Agent Status" := ParsePrinterStatus(StatusText);
        // Presence in the agent's selected-printer snapshot means this is a
        // configured route. Liveness belongs to Agent Status, not Active.
        Printer.Active := true;
        if IsNew and (Printer."Format" = Printer."Format"::PDF) then
            Printer."Enable BC Reports" := true;
        Printer."Agent Default Printer" := RequireBoolean(PrinterObject, 'isDefault');
        Printer."Last Seen At" := SnapshotAt;
        Printer."Last Status At" := SnapshotAt;
        Printer."Last Agent ID" := AgentId;
        Printer."Agent Version" := AgentVersion;
        Printer."Last Status Message" := CopyStr(StatusText, 1, MaxStrLen(Printer."Last Status Message"));
        Printer.Modify(true);
        exit(true);
    end;

    local procedure ProcessHeartbeat(Root: JsonObject)
    var
        Printer: Record "DOPSWHS Printer";
        StationId: Code[128];
        AgentId: Code[50];
        AgentVersion: Text[50];
        HeartbeatAt: DateTime;
        StatusText: Text;
    begin
        StationId := CopyStr(RequireText(Root, 'stationId'), 1, MaxStrLen(StationId));
        AgentId := CopyStr(RequireText(Root, 'agentId'), 1, MaxStrLen(AgentId));
        AgentVersion := CopyStr(RequireText(Root, 'agentVersion'), 1, MaxStrLen(AgentVersion));
        HeartbeatAt := RequireUtcDateTime(Root, 'sentAtUtc');
        StatusText := CopyStr(RequireText(Root, 'status'), 1, MaxStrLen(Printer."Last Status Message"));
        ValidateOptionalCanonicalGuid(Root, 'lastJobId');
        if HeartbeatAt < CurrentDateTime() - LiveStatusFreshness() then
            exit;
        Printer.SetRange("Station ID", StationId);
        if Printer.FindSet(true) then
            repeat
                if (Printer."Last Status At" = 0DT) or (Printer."Last Status At" <= HeartbeatAt) then begin
                    Printer."Last Seen At" := HeartbeatAt;
                    Printer."Last Status At" := HeartbeatAt;
                    Printer."Last Agent ID" := AgentId;
                    Printer."Agent Version" := AgentVersion;
                    Printer."Last Status Message" := StatusText;
                    ApplyHeartbeatStatus(Printer, StatusText);
                    Printer.Modify(true);
                end;
            until Printer.Next() = 0;
    end;

    local procedure ProcessJobResult(Root: JsonObject)
    var
        Queue: Record "DOPSWHS Print Job Queue";
        Printer: Record "DOPSWHS Printer";
        JobGuid: Guid;
        JobIdText: Text;
        PrinterIdText: Text;
        PrinterId: Code[20];
        PrinterName: Text;
        StationId: Code[128];
        AgentId: Code[50];
        ResultMessage: Text;
        ResultFormat: Text;
        ValidatedFormat: Enum "DOPSWHS Print Format";
        CompletedAt: DateTime;
        Success: Boolean;
        Attempt: Integer;
    begin
        JobIdText := RequireText(Root, 'jobId');
        ValidateCanonicalGuid(JobIdText, 'jobId');
        if not Evaluate(JobGuid, JobIdText) then
            Error('JobResult jobId is not a GUID.');
        StationId := CopyStr(RequireText(Root, 'stationId'), 1, MaxStrLen(StationId));
        PrinterIdText := RequireText(Root, 'printerId');
        ValidatePrinterId(PrinterIdText);
        PrinterId := CopyStr(PrinterIdText, 1, MaxStrLen(PrinterId));
        PrinterName := RequireText(Root, 'printerName');
        if StrLen(PrinterName) > MaxStrLen(Printer."Printer Handle") then
            Error('JobResult printerName exceeds %1 characters.', MaxStrLen(Printer."Printer Handle"));
        AzureBridge.ValidateAzurePrinterName(PrinterName, PrinterIdText);
        AgentId := CopyStr(RequireText(Root, 'agentId'), 1, MaxStrLen(AgentId));
        ResultFormat := RequireText(Root, 'format');
        if ResultFormat <> UpperCase(ResultFormat) then
            Error('JobResult format must use canonical uppercase text.');
        ValidatedFormat := ParseFormat(ResultFormat);
        Success := RequireBoolean(Root, 'success');
        ResultMessage := CopyStr(RequireText(Root, 'message'), 1, MaxStrLen(Queue."Last Error"));
        CompletedAt := RequireUtcDateTime(Root, 'completedAtUtc');
        Attempt := RequireInteger(Root, 'attempt');
        if (Attempt < 1) or (Attempt > 10) then
            Error('JobResult attempt must be between 1 and 10.');

        Queue.SetRange("Cloud Job ID", JobGuid);
        if not Queue.FindFirst() then begin
            // Azure-only smoke tests and results arriving after BC retention do
            // not have a local queue row. The complete v1 envelope and route
            // ownership were validated above, so settle the orphan instead of
            // poisoning the shared status queue with repeated abandon cycles.
            LogSecurityWarning(
                'A valid printer JobResult without a local BC job was ignored and completed.',
                OptionalText(Root, 'messageId'),
                StrSubstNo('jobId=%1; stationId=%2; printerId=%3', JobIdText, StationId, PrinterIdText));
            exit;
        end;

        if Queue.Channel <> Queue.Channel::AzureDirect then
            Error('JobResult %1 does not reference an Azure Direct job.', JobIdText);
        if Queue."Station ID" <> StationId then
            Error('JobResult station ownership does not match job %1.', JobIdText);
        if Queue."Printer ID" <> PrinterId then
            Error('JobResult printer ownership does not match job %1.', JobIdText);
        if Queue."Format" <> ValidatedFormat then
            Error('JobResult format does not match job %1.', JobIdText);
        Printer.Get(PrinterId);
        if Printer."Station ID" <> StationId then
            Error('JobResult printer station ownership validation failed.');
        if Printer."Printer Handle" <> PrinterName then
            Error('JobResult printer name does not match the registered operating-system printer.');
        if (Queue."Dispatched At" <> 0DT) and (CompletedAt < Queue."Dispatched At" - ClockSkewTolerance()) then
            Error('JobResult completedAtUtc predates dispatch for job %1.', JobIdText);

        if (Queue.Status = Queue.Status::Sent) and Success then
            exit;
        if (Queue.Status = Queue.Status::Failed) and not Success then
            exit;
        if Queue.Status <> Queue.Status::Dispatched then
            Error('JobResult %1 arrived while the job was in state %2.', JobIdText, Queue.Status);

        Queue."Agent ID" := AgentId;
        Queue."Claimed At" := CompletedAt;
        Queue."Completed At" := CompletedAt;
        if Success then begin
            Queue.Status := Queue.Status::Sent;
            Queue.Sent := CompletedAt;
            Queue."Last Error" := '';
        end else begin
            Queue.Status := Queue.Status::Failed;
            if ResultMessage = '' then
                ResultMessage := 'The print agent reported a failed physical print attempt.';
            Queue."Last Error" := ResultMessage;
        end;
        Queue.Modify(true);

        if (Printer."Last Status At" = 0DT) or (Printer."Last Status At" <= CompletedAt) then begin
            Printer."Last Seen At" := CompletedAt;
            Printer."Last Status At" := CompletedAt;
            Printer."Last Agent ID" := AgentId;
            if Success then begin
                Printer."Agent Status" := Printer."Agent Status"::Online;
                Printer."Last Status Message" := 'Print spool accepted.';
            end else begin
                Printer."Agent Status" := Printer."Agent Status"::Error;
                Printer."Last Status Message" := ResultMessage;
            end;
            Printer.Modify(true);
        end;
        if Success then
            AzureBridge.Log(Queue."Job ID", 'AgentPrintSucceeded', StrSubstNo('Agent accepted the payload into the spooler on attempt %1.', Attempt))
        else
            AzureBridge.Log(Queue."Job ID", 'AgentPrintFailed', ResultMessage);
    end;

    local procedure IsForeignOwnedMessage(Body: Text; var MessageId: Text): Boolean
    var
        Setup: Record "DOPSWHS Setup";
        Root: JsonObject;
        TenantId: Text;
        CompanyId: Text;
    begin
        if not Root.ReadFrom(Body) then
            exit(false);
        MessageId := OptionalText(Root, 'messageId');
        TenantId := OptionalText(Root, 'tenantId');
        CompanyId := OptionalText(Root, 'companyId');
        if (TenantId = '') or (CompanyId = '') then
            exit(false);
        Setup.Get('');
        exit((TenantId <> Setup."Azure Tenant Route ID") or
            (CompanyId <> Setup."Azure Company Route ID"));
    end;

    local procedure ValidateOwnedMessage(Root: JsonObject)
    var
        Setup: Record "DOPSWHS Setup";
        StationId: Text;
        MessageId: Text;
        AgentId: Text;
        AgentVersion: Text;
    begin
        Setup.Get('');
        if RequireText(Root, 'tenantId') <> Setup."Azure Tenant Route ID" then
            Error('Printer-status tenant ownership validation failed.');
        if RequireText(Root, 'companyId') <> Setup."Azure Company Route ID" then
            Error('Printer-status company ownership validation failed.');
        StationId := RequireText(Root, 'stationId');
        AzureBridge.ValidateStationId(StationId);
        MessageId := RequireText(Root, 'messageId');
        ValidateCanonicalGuid(MessageId, 'messageId');
        AgentId := RequireText(Root, 'agentId');
        ValidateCanonicalGuid(AgentId, 'agentId');
        AgentVersion := RequireText(Root, 'agentVersion');
        if StrLen(AgentVersion) > 50 then
            Error('Printer-status agentVersion exceeds 50 characters.');
        RequireUtcDateTime(Root, 'sentAtUtc');
    end;

    local procedure RequireSchemaV1(Root: JsonObject)
    var
        Token: JsonToken;
    begin
        if not Root.Get('schemaVersion', Token) or not Token.IsValue() then
            Error('Printer-status schemaVersion is missing.');
        if Token.AsValue().AsInteger() <> 1 then
            Error('Unsupported printer-status schemaVersion %1.', Token.AsValue().AsInteger());
    end;

    [NonDebuggable]
    local procedure CompleteMessage(EntityUrl: Text; LockUrl: Text; Setup: Record "DOPSWHS Setup"; SharedKey: SecretText)
    begin
        SettleMessage('DELETE', EntityUrl, LockUrl, Setup, SharedKey, 'complete');
    end;

    [NonDebuggable]
    local procedure AbandonMessage(EntityUrl: Text; LockUrl: Text; Setup: Record "DOPSWHS Setup"; SharedKey: SecretText)
    begin
        if not TrySettleMessage('PUT', EntityUrl, LockUrl, Setup, SharedKey, 'abandon') then
            ClearLastError();
    end;

    [TryFunction]
    [NonDebuggable]
    local procedure TrySettleMessage(Method: Text; EntityUrl: Text; LockUrl: Text; Setup: Record "DOPSWHS Setup"; SharedKey: SecretText; OperationName: Text)
    begin
        SettleMessage(Method, EntityUrl, LockUrl, Setup, SharedKey, OperationName);
    end;

    [NonDebuggable]
    local procedure SettleMessage(Method: Text; EntityUrl: Text; LockUrl: Text; Setup: Record "DOPSWHS Setup"; SharedKey: SecretText; OperationName: Text)
    var
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Content: HttpContent;
        Headers: HttpHeaders;
        Authorization: SecretText;
    begin
        ValidateLockUrl(EntityUrl, LockUrl);
        Authorization := AzureBridge.GenerateServiceBusSasToken(EntityUrl, Setup."Azure Status SAS Policy", SharedKey, 3600);
        Request.Method := Method;
        Request.SetRequestUri(LockUrl);
        Request.GetHeaders(Headers);
        Headers.Add('Authorization', Authorization);
        if Method = 'PUT' then begin
            Content.WriteFrom('');
            Request.Content := Content;
        end;
        if not Client.Send(Request, Response) then
            Error('Azure Service Bus could not %1 the locked status message.', OperationName);
        if not Response.IsSuccessStatusCode() then
            Error('Azure Service Bus status-message %1 failed (HTTP %2).', OperationName, Response.HttpStatusCode());
    end;

    local procedure ValidateLockUrl(EntityUrl: Text; LockUrl: Text)
    var
        RequiredPrefix: Text;
    begin
        RequiredPrefix := LowerCase(EntityUrl + '/messages/');
        if (LockUrl = '') or
           (CopyStr(LowerCase(LockUrl), 1, StrLen(RequiredPrefix)) <> RequiredPrefix) or
           (StrPos(LockUrl, '\') > 0) or (StrPos(LockUrl, '..') > 0) or
           (StrPos(LockUrl, '#') > 0)
        then
            Error('Azure Service Bus returned an unsafe message lock URL.');
    end;

    local procedure GetResponseHeader(Response: HttpResponseMessage; HeaderName: Text): Text
    var
        Headers: HttpHeaders;
        Values: array[10] of Text;
    begin
        Headers := Response.Headers();
        if not Headers.GetValues(HeaderName, Values) then
            exit('');
        exit(Values[1]);
    end;

    local procedure RequireText(Object: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
        Value: Text;
    begin
        if not Object.Get(PropertyName, Token) or not Token.IsValue() then
            Error('Printer-status property %1 is missing.', PropertyName);
        Value := Token.AsValue().AsText();
        if Value = '' then
            Error('Printer-status property %1 is empty.', PropertyName);
        exit(Value);
    end;

    local procedure OptionalText(Object: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not Object.Get(PropertyName, Token) or not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure RequireBoolean(Object: JsonObject; PropertyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not Object.Get(PropertyName, Token) or not Token.IsValue() then
            Error('Printer-status property %1 is missing.', PropertyName);
        exit(Token.AsValue().AsBoolean());
    end;

    local procedure RequireInteger(Object: JsonObject; PropertyName: Text): Integer
    var
        Token: JsonToken;
    begin
        if not Object.Get(PropertyName, Token) or not Token.IsValue() then
            Error('Printer-status property %1 is missing.', PropertyName);
        exit(Token.AsValue().AsInteger());
    end;

    local procedure RequireArray(Object: JsonObject; PropertyName: Text): JsonArray
    var
        Token: JsonToken;
    begin
        if not Object.Get(PropertyName, Token) or not Token.IsArray() then
            Error('Printer-status property %1 is missing or is not an array.', PropertyName);
        exit(Token.AsArray());
    end;

    local procedure RequireUtcDateTime(Object: JsonObject; PropertyName: Text): DateTime
    var
        Token: JsonToken;
        ValueText: Text;
        Value: DateTime;
    begin
        ValueText := RequireText(Object, PropertyName);
        if not IsCanonicalUtcTimestamp(ValueText) then
            Error('Printer-status property %1 must be an ISO-8601 UTC timestamp.', PropertyName);
        if not Object.Get(PropertyName, Token) or not Token.IsValue() then
            Error('Printer-status property %1 is missing.', PropertyName);
        Value := Token.AsValue().AsDateTime();
        if Value < CurrentDateTime() - (30 * OneDay()) then
            Error('Printer-status property %1 is older than 30 days.', PropertyName);
        if Value > CurrentDateTime() + ClockSkewTolerance() then
            Error('Printer-status property %1 is too far in the future.', PropertyName);
        exit(Value);
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

    local procedure ValidateCanonicalGuid(Value: Text; PropertyName: Text)
    var
        ParsedGuid: Guid;
        Canonical: Text;
    begin
        if not Evaluate(ParsedGuid, Value) or IsNullGuid(ParsedGuid) then
            Error('Printer-status property %1 must be a non-empty GUID.', PropertyName);
        Canonical := LowerCase(DelChr(Format(ParsedGuid), '=', '{}'));
        if Value <> Canonical then
            Error('Printer-status property %1 must use canonical lowercase GUID D format.', PropertyName);
    end;

    local procedure ValidateOptionalCanonicalGuid(Object: JsonObject; PropertyName: Text)
    var
        Value: Text;
    begin
        Value := OptionalText(Object, PropertyName);
        if Value <> '' then
            ValidateCanonicalGuid(Value, PropertyName);
    end;

    local procedure StationHasNewerStatus(StationId: Code[128]; SnapshotAt: DateTime): Boolean
    var
        Printer: Record "DOPSWHS Printer";
    begin
        Printer.SetRange("Station ID", StationId);
        Printer.SetFilter("Last Status At", '>%1', SnapshotAt);
        exit(not Printer.IsEmpty());
    end;

    local procedure ApplyHeartbeatStatus(var Printer: Record "DOPSWHS Printer"; StatusText: Text)
    begin
        case LowerCase(StatusText) of
            'online':
                begin
                    if Printer."Agent Status" <> Printer."Agent Status"::Printing then
                        Printer."Agent Status" := Printer."Agent Status"::Online;
                end;
            'degraded', 'error', 'faulted':
                begin
                    Printer."Agent Status" := Printer."Agent Status"::Error;
                end;
            'offline':
                begin
                    Printer."Agent Status" := Printer."Agent Status"::Offline;
                end;
            'starting':
                begin
                    // Startup proves only status-queue send connectivity. Keep
                    // the configured Active selection and wait for Online.
                    Printer."Agent Status" := Printer."Agent Status"::Unknown;
                end;
            else
                Error('Unsupported Heartbeat status %1.', StatusText);
        end;
    end;

    local procedure ClockSkewTolerance(): Duration
    begin
        exit(5 * 60 * 1000);
    end;

    local procedure LiveStatusFreshness(): Duration
    begin
        exit(15 * 60 * 1000);
    end;

    local procedure OneDay(): Duration
    begin
        exit(24 * 60 * 60 * 1000);
    end;

    local procedure MaxStatusMessageCharacters(): Integer
    begin
        exit(1024 * 1024);
    end;

    local procedure ParseFormat(Value: Text): Enum "DOPSWHS Print Format"
    var
        PrintFormat: Enum "DOPSWHS Print Format";
    begin
        case UpperCase(Value) of
            'ZPL':
                exit(PrintFormat::ZPL);
            'PDF':
                exit(PrintFormat::PDF);
            'ESCPOS':
                exit(PrintFormat::ESCPOS);
            'RAW':
                exit(PrintFormat::RAW);
            else
                Error('Unsupported printer format %1.', Value);
        end;
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

    local procedure ParsePrinterStatus(Value: Text) Result: Option Unknown,Online,Offline,Printing,Error
    begin
        case LowerCase(Value) of
            'online', 'ready', 'installed':
                exit(Result::Online);
            'offline':
                exit(Result::Offline);
            'printing', 'busy':
                exit(Result::Printing);
            'error', 'faulted':
                exit(Result::Error);
            else
                exit(Result::Unknown);
        end;
    end;

    local procedure ValidatePrinterId(PrinterId: Text)
    begin
        AzureBridge.ValidateAzurePrinterId(PrinterId);
    end;

    local procedure LogSecurityWarning(MessageText: Text; MessageId: Text; Detail: Text)
    var
        Telemetry: Codeunit "DOPSWHS Telemetry";
        Dimensions: Dictionary of [Text, Text];
    begin
        if MessageId <> '' then
            Dimensions.Add('messageId', CopyStr(MessageId, 1, 100));
        if Detail <> '' then
            Dimensions.Add('detail', CopyStr(Detail, 1, 250));
        Telemetry.Log('AzurePrint.StatusSecurity', MessageText, Verbosity::Warning, Dimensions);
    end;

    var
        AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
}
