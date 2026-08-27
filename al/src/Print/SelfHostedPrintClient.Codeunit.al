codeunit 72081 "DOPSWHS Self-Host Print Client"
{
    Access = Public;

    procedure Enqueue(SourceDoc: Code[50]; PrinterCode: Code[20]; Format: Enum "DOPSWHS Print Format"; Payload: Text; Copies: Integer): Integer
    var
        TempBlob: Codeunit "Temp Blob";
        InStream: InStream;
        OutStream: OutStream;
    begin
        TempBlob.CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.WriteText(Payload);
        TempBlob.CreateInStream(InStream);
        exit(EnqueueStream(SourceDoc, 0, PrinterCode, Format, InStream, Copies, ''));
    end;

    /// <summary>
    /// Persists an arbitrary binary payload (PDF, ZPL, ESC/POS or RAW) in the
    /// existing WMS queue. CorrelationId makes BC printer events idempotent.
    /// </summary>
    procedure EnqueueStream(SourceDoc: Code[50]; ReportId: Integer; PrinterCode: Code[20]; Format: Enum "DOPSWHS Print Format"; Payload: InStream; Copies: Integer; CorrelationId: Text[100]): Integer
    begin
        exit(EnqueueStreamInternal(SourceDoc, ReportId, PrinterCode, Format, Payload, Copies, CorrelationId, true));
    end;

    /// <summary>
    /// Creates a durable Azure Direct job without scheduling a parallel task.
    /// The caller must commit and invoke AzurePrintBridge.DispatchJob exactly
    /// once; dispatch failure itself schedules the normal retry path.
    /// </summary>
    procedure EnqueueStreamForImmediateDispatch(SourceDoc: Code[50]; ReportId: Integer; PrinterCode: Code[20]; Format: Enum "DOPSWHS Print Format"; Payload: InStream; Copies: Integer; CorrelationId: Text[100]): Integer
    begin
        exit(EnqueueStreamInternal(SourceDoc, ReportId, PrinterCode, Format, Payload, Copies, CorrelationId, false));
    end;

    local procedure EnqueueStreamInternal(SourceDoc: Code[50]; ReportId: Integer; PrinterCode: Code[20]; Format: Enum "DOPSWHS Print Format"; Payload: InStream; Copies: Integer; CorrelationId: Text[100]; ScheduleAzureDispatch: Boolean): Integer
    var
        Printer: Record "DOPSWHS Printer";
        Queue: Record "DOPSWHS Print Job Queue";
        ExistingQueue: Record "DOPSWHS Print Job Queue";
        Setup: Record "DOPSWHS Setup";
        TempBlob: Codeunit "Temp Blob";
        AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
        BufferInStream: InStream;
        HashInStream: InStream;
        BufferOutStream: OutStream;
        QueueOutStream: OutStream;
        PayloadSha256: Text[64];
        IsAzureDirect: Boolean;
    begin
        if not Printer.Get(PrinterCode) then
            Error('Printer %1 is not registered.', PrinterCode);
        if not Printer.Active then
            Error('Printer %1 is inactive.', PrinterCode);
        if Printer."Format" <> Format then
            Error('Printer %1 is configured for %2, but this job is %3.', PrinterCode, Printer."Format", Format);
        if Copies <= 0 then
            Copies := Printer."Default Copies";
        if Copies <= 0 then
            Copies := 1;
        if Copies > 10 then
            Error('A print job cannot exceed 10 copies.');

        if CorrelationId <> '' then begin
            ExistingQueue.SetRange("Correlation ID", CorrelationId);
            ExistingQueue.SetRange("Printer ID", PrinterCode);
            if ExistingQueue.FindFirst() then
                exit(ExistingQueue."Job ID");
        end;

        TempBlob.CreateOutStream(BufferOutStream);
        CopyStream(BufferOutStream, Payload);
        if not TempBlob.HasValue() then
            Error('The print payload is empty.');
        Setup.Get('');
        IsAzureDirect := Setup."Print Channel" = Setup."Print Channel"::AzureDirect;
        if IsAzureDirect then begin
            if TempBlob.Length() > AzureBridge.MaxPayloadBytes() then
                Error('Azure Direct print payloads cannot exceed 50 MiB. This payload is %1 bytes.', TempBlob.Length());
            TempBlob.CreateInStream(HashInStream);
            PayloadSha256 := AzureBridge.ComputePayloadSha256(HashInStream);
        end;

        Queue.Init();
        Queue."Source Doc" := SourceDoc;
        Queue."Report ID" := ReportId;
        Queue."Printer ID" := Printer."Code";
        if IsAzureDirect then
            Queue.Channel := Queue.Channel::AzureDirect
        else
            Queue.Channel := Queue.Channel::SelfHosted;
        Queue."Format" := Format;
        Queue.Status := Queue.Status::Queued;
        Queue.Created := CurrentDateTime();
        Queue.Copies := Copies;
        Queue."Correlation ID" := CorrelationId;
        Queue."Payload Size" := TempBlob.Length();
        if IsAzureDirect then
            AzureBridge.PrepareAzureJob(Queue, Printer, PayloadSha256);
        TempBlob.CreateInStream(BufferInStream);
        Queue.ZPL.CreateOutStream(QueueOutStream);
        CopyStream(QueueOutStream, BufferInStream);
        Queue.Insert(true);
        if IsAzureDirect then
            if ScheduleAzureDispatch then
                AzureBridge.FinalizeAndScheduleAzureJob(Queue)
            else
                AzureBridge.FinalizeAzureJob(Queue)
        else
            Log(Queue."Job ID", 'Queued', StrSubstNo('SelfHosted job queued for %1 (%2 bytes).', Printer."Code", Queue."Payload Size"));
        exit(Queue."Job ID");
    end;

    procedure RotateToken(PrinterCode: Code[20]): Text
    var
        Printer: Record "DOPSWHS Printer";
        TypeHelper: Codeunit "Cryptography Management";
        Random: Text;
        Hash: Text;
    begin
        Printer.Get(PrinterCode);
        Random := NewSecret();
        Hash := TypeHelper.GenerateHash(Random, 3); // 3 = HashAlgorithmType::SHA256
        Printer."Token Hash" := CopyStr(Hash, 1, MaxStrLen(Printer."Token Hash"));
        Printer."Token Issued At" := CurrentDateTime();
        Printer.Modify(true);
        // Only the hash is persisted; the plain secret returned here is shown to the caller
        // once (Card UI / API response) and then lives only in the agent's config.json.
        exit(Random);
    end;

    procedure VerifyToken(PrinterCode: Code[20]; CandidateToken: Text): Boolean
    var
        Printer: Record "DOPSWHS Printer";
        TypeHelper: Codeunit "Cryptography Management";
        Hash: Text;
    begin
        if not Printer.Get(PrinterCode) then
            exit(false);
        if Printer."Token Hash" = '' then
            exit(false);
        Hash := TypeHelper.GenerateHash(CandidateToken, 3);
        exit(Hash = Printer."Token Hash");
    end;

    procedure MarkClaimed(JobId: Integer; AgentId: Code[50]; PrinterCode: Code[20]): Boolean
    var
        Queue: Record "DOPSWHS Print Job Queue";
        Printer: Record "DOPSWHS Printer";
    begin
        if (AgentId = '') or (PrinterCode = '') then
            exit(false);
        Queue.LockTable();
        if not Queue.Get(JobId) then
            exit(false);
        if Queue.Channel <> Queue.Channel::SelfHosted then
            exit(false);
        if (PrinterCode <> '') and (Queue."Printer ID" <> PrinterCode) then
            exit(false);
        if Queue.Status <> Queue.Status::Queued then
            exit(false);
        if Queue."Agent ID" <> '' then begin
            if (Queue."Claimed At" <> 0DT) and (Queue."Claimed At" > CurrentDateTime() - LeaseDuration()) then
                exit(false);
            Log(JobId, 'LeaseExpired', StrSubstNo('Expired claim from agent %1 was released.', Queue."Agent ID"));
        end;
        Queue."Agent ID" := AgentId;
        Queue."Claimed At" := CurrentDateTime();
        Queue.Modify(true);
        if Printer.Get(CopyStr(Queue."Printer ID", 1, MaxStrLen(Printer."Code"))) then begin
            Printer."Last Seen At" := CurrentDateTime();
            Printer.Modify(true);
        end;
        Log(JobId, 'Claimed', StrSubstNo('Claimed by agent %1.', AgentId));
        exit(true);
    end;

    procedure MarkStatus(JobId: Integer; Success: Boolean; Message: Text; AgentId: Code[50]; PrinterCode: Code[20]): Boolean
    var
        Queue: Record "DOPSWHS Print Job Queue";
        Printer: Record "DOPSWHS Printer";
    begin
        if (AgentId = '') or (PrinterCode = '') then
            exit(false);
        if not Queue.Get(JobId) then
            exit(false);
        if Queue.Channel <> Queue.Channel::SelfHosted then
            exit(false);
        if (PrinterCode <> '') and (Queue."Printer ID" <> PrinterCode) then
            exit(false);
        if (AgentId <> '') and (Queue."Agent ID" <> AgentId) then
            exit(false);
        if Success and (Queue.Status = Queue.Status::Sent) then
            exit(true);
        if Queue.Status <> Queue.Status::Queued then
            exit(false);
        if Success then begin
            Queue.Status := Queue.Status::Sent;
            Queue.Sent := CurrentDateTime();
        end else begin
            Queue.Status := Queue.Status::Failed;
            Queue."Last Error" := CopyStr(Message, 1, MaxStrLen(Queue."Last Error"));
            Queue."Retry Count" += 1;
        end;
        Queue.Modify(true);
        if Printer.Get(CopyStr(Queue."Printer ID", 1, MaxStrLen(Printer."Code"))) then begin
            Printer."Last Seen At" := CurrentDateTime();
            Printer.Modify(true);
        end;
        if Success then
            Log(JobId, 'Sent', 'Agent confirmed delivery.')
        else
            Log(JobId, 'Failed', CopyStr(Message, 1, 250));
        exit(true);
    end;

    procedure EnqueueSelfTest(PrinterCode: Code[20]): Integer
    var
        Printer: Record "DOPSWHS Printer";
        ZplEncoder: Codeunit "DOPSWHS ZPL Encoder";
        Zpl: Text;
    begin
        if not Printer.Get(PrinterCode) then
            Error('Printer %1 is not registered.', PrinterCode);
        if Printer."Format" <> Printer."Format"::ZPL then
            Error('The built-in test label is ZPL-only. Test PDF printers by printing a standard BC report.');
        // ^CI28 = UTF-8; matches the LP label template so the agent and printer
        // always speak the same encoding regardless of payload origin.
        Zpl := '^XA^CI28^PW812^LL406^FO50,50^A0N,40,40^FH_^FDDynOps WMS Self-Test^FS' +
            '^FO50,120^A0N,30,30^FH_^FDPrinter: ' + ZplEncoder.EncodeFieldData(PrinterCode) + '^FS' +
            '^FO50,180^BCN,80,Y,N,N^FH_^FD' + ZplEncoder.EncodeFieldData(Format(CurrentDateTime(), 0, 9)) + '^FS^XZ';
        exit(Enqueue('SELFTEST', PrinterCode, Enum::"DOPSWHS Print Format"::ZPL, Zpl, 1));
    end;

    procedure RetryFailed(JobId: Integer): Boolean
    var
        Queue: Record "DOPSWHS Print Job Queue";
        AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
    begin
        Queue.LockTable();
        if not Queue.Get(JobId) then
            exit(false);
        if Queue.Status <> Queue.Status::Failed then
            exit(false);
        if Queue.Channel = Queue.Channel::AzureDirect then begin
            AzureBridge.CloneFailedJobForRetry(JobId);
            exit(true);
        end;
        if Queue.Channel <> Queue.Channel::SelfHosted then
            exit(false);
        Queue.Status := Queue.Status::Queued;
        Queue."Agent ID" := '';
        Queue."Claimed At" := 0DT;
        Queue."Last Error" := '';
        Queue.Sent := 0DT;
        Queue.Modify(true);
        Log(JobId, 'RetryQueued', StrSubstNo('Failed job re-queued after %1 attempt(s).', Queue."Retry Count"));
        exit(true);
    end;

    procedure ResolvePrinter(DeviceId: Code[50]; Usage: Enum "DOPSWHS IWX Report Usage"): Code[20]
    var
        Map: Record "DOPSWHS Device Printer Map";
    begin
        if DeviceId <> '' then
            if Map.Get(DeviceId, Usage) then
                exit(Map."Printer Code");
        if Map.Get('', Usage) then
            exit(Map."Printer Code");
        exit('');
    end;

    procedure ResolvePrinterAndCopies(DeviceId: Code[50]; Usage: Enum "DOPSWHS IWX Report Usage"; RequestedCopies: Integer; var PrinterCode: Code[20]; var EffectiveCopies: Integer): Boolean
    var
        Map: Record "DOPSWHS Device Printer Map";
        Printer: Record "DOPSWHS Printer";
        MappingFound: Boolean;
    begin
        Clear(PrinterCode);
        Clear(EffectiveCopies);
        if DeviceId <> '' then
            MappingFound := Map.Get(DeviceId, Usage);
        if not MappingFound then
            MappingFound := Map.Get('', Usage);
        if not MappingFound then
            exit(false);
        if Map."Printer Code" = '' then
            exit(false);
        if not Printer.Get(Map."Printer Code") then
            Error('Mapped printer %1 is not registered.', Map."Printer Code");
        if not Printer.Active then
            Error('Mapped printer %1 is inactive.', Printer.Code);

        PrinterCode := Printer.Code;
        EffectiveCopies := RequestedCopies;
        if EffectiveCopies <= 0 then
            EffectiveCopies := Map.Copies;
        if EffectiveCopies <= 0 then
            EffectiveCopies := Printer."Default Copies";
        if EffectiveCopies <= 0 then
            EffectiveCopies := 1;
        if EffectiveCopies > 10 then
            Error('A print job cannot exceed 10 copies. Mapping %1/%2 resolved to %3 copies.', Map."Device ID", Usage, EffectiveCopies);
        exit(true);
    end;

    local procedure NewSecret(): Text
    var
        Guid1: Guid;
        Guid2: Guid;
        Combined: Text;
    begin
        Guid1 := CreateGuid();
        Guid2 := CreateGuid();
        Combined := DelChr(Format(Guid1), '=', '{}-') + DelChr(Format(Guid2), '=', '{}-');
        exit(Combined);
    end;

    local procedure LeaseDuration(): Duration
    begin
        exit(15 * 60 * 1000);
    end;

    local procedure Log(JobId: Integer; EventType: Text[100]; Message: Text[250])
    var
        LogEntry: Record "DOPSWHS Print Job Log";
    begin
        LogEntry.Init();
        LogEntry."Job ID" := JobId;
        LogEntry.EventType := EventType;
        LogEntry.Message := Message;
        LogEntry.DateTime := CurrentDateTime();
        LogEntry.Insert(true);
    end;
}
