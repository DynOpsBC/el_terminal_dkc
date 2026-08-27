using Azure.Messaging.ServiceBus;
using BCWMS.PrintAgent.Core.Configuration;
using BCWMS.PrintAgent.Core.Contracts;
using BCWMS.PrintAgent.Core.Reliability;
using BCWMS.PrintAgent.Core.Validation;
using BCWMS.PrintAgent.Windows.Infrastructure;
using BCWMS.PrintAgent.Windows.Printing;

namespace BCWMS.PrintAgent.Windows.Cloud;

internal sealed class AzurePrintAgentRuntime : IAsyncDisposable
{
    private readonly AgentSettings _settings;
    private readonly AgentLogger _logger;
    private readonly FileJobJournal _journal;
    private readonly FileStatusOutbox _outbox;
    private readonly PrintCoordinator _printer;
    private readonly StatusPublisher _status;
    private readonly ServiceBusClient _jobsClient;
    private readonly ServiceBusSessionProcessor _processor;
    private CancellationTokenSource? _heartbeatCancellation;
    private Task? _heartbeatTask;
    private string? _lastJobId;
    private int _disposed;
    // 0=Starting/unknown, 1=receiver session proven, 2=faulted.
    private int _jobsHealth;

    public AzurePrintAgentRuntime(
        AgentSettings settings,
        AgentLogger logger,
        FileJobJournal journal,
        FileStatusOutbox outbox,
        PrintCoordinator printer,
        StatusPublisher status)
    {
        _settings = settings;
        _logger = logger;
        _journal = journal;
        _outbox = outbox;
        _printer = printer;
        _status = status;
        _jobsClient = new ServiceBusClient(settings.JobsListenConnectionString, new ServiceBusClientOptions
        {
            TransportType = ServiceBusTransportType.AmqpWebSockets,
            RetryOptions =
            {
                Mode = ServiceBusRetryMode.Exponential,
                MaxRetries = 3,
                Delay = TimeSpan.FromSeconds(1),
                MaxDelay = TimeSpan.FromSeconds(10),
                TryTimeout = TimeSpan.FromSeconds(30)
            }
        });
        var options = new ServiceBusSessionProcessorOptions
        {
            AutoCompleteMessages = false,
            MaxConcurrentSessions = 1,
            MaxConcurrentCallsPerSession = 1,
            PrefetchCount = 0,
            // Windows drivers can block inside native code. Keep renewing for the
            // full handler lifetime; the durable InProgress intent prevents a
            // crash/restart from silently printing the same job again.
            MaxAutoLockRenewalDuration = Timeout.InfiniteTimeSpan,
            SessionIdleTimeout = TimeSpan.FromSeconds(20),
            Identifier = settings.AgentId,
            SessionIds = { settings.StationId }
        };
        _processor = _jobsClient.CreateSessionProcessor(CloudEntityNames.PrintJobsQueue, options);
        _processor.ProcessMessageAsync += ProcessMessageAsync;
        _processor.ProcessErrorAsync += ProcessErrorAsync;
        _processor.SessionInitializingAsync += SessionInitializingAsync;
    }

    public event EventHandler<bool>? ConnectivityChanged;
    public bool IsReceiverReady => Volatile.Read(ref _jobsHealth) == 1;

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        await _processor.StartProcessingAsync(cancellationToken).ConfigureAwait(false);
        _logger.Info($"Azure dinleyici başladı. SessionId={_settings.StationId}.");
        await _status.SendSnapshotAsync(receiverHealthy: IsReceiverReady, cancellationToken).ConfigureAwait(false);
        await _status.SendHeartbeatAsync(_lastJobId, CurrentHealthStatus(), cancellationToken).ConfigureAwait(false);
        _heartbeatCancellation = new CancellationTokenSource();
        _heartbeatTask = RunHeartbeatAsync(_heartbeatCancellation.Token);
        RaiseConnectivity(IsReceiverReady);
    }

    public async Task StopAsync(CancellationToken cancellationToken)
    {
        _heartbeatCancellation?.Cancel();
        if (_heartbeatTask is not null)
        {
            try
            {
                await _heartbeatTask.ConfigureAwait(false);
            }
            catch (OperationCanceledException) { }
        }

        await _processor.StopProcessingAsync(cancellationToken).ConfigureAwait(false);
        RaiseConnectivity(false);
        _logger.Info("Azure dinleyici durdu.");
    }

    public Task SendSnapshotAsync(CancellationToken cancellationToken) =>
        _status.SendSnapshotAsync(string.Equals(CurrentHealthStatus(), "Online", StringComparison.Ordinal), cancellationToken);
    public Task PrintLabelTestAsync(CancellationToken cancellationToken) => _printer.PrintLabelTestAsync(cancellationToken);
    public Task PrintDocumentTestAsync(CancellationToken cancellationToken) => _printer.PrintDocumentTestAsync(cancellationToken);

    private async Task ProcessMessageAsync(ProcessSessionMessageEventArgs args)
    {
        PrintJobV1? job = null;
        var intentDurable = false;
        var spoolAccepted = false;
        var journalCompleted = false;
        try
        {
            ValidateBrokerMetadata(args.Message);
            job = ContractSerializer.ParsePrintJob(args.Message.Body.ToMemory());
            ValidateMessageIdentity(args.Message, job);
            // Routing is checked before journal dedupe so a forged replay cannot
            // bypass the local tenant/station/printer allowlist.
            JobRoutingPolicy.Validate(job, _settings);
            Interlocked.Exchange(ref _jobsHealth, 1);
            RaiseConnectivity(true);

            var journalMatch = await _journal.CheckAsync(job, args.CancellationToken).ConfigureAwait(false);
            if (journalMatch == JournalMatch.Conflict)
            {
                throw new PermanentJobException("Aynı JobId farklı immutable iş alanlarıyla tekrar kullanıldı.");
            }

            if (journalMatch == JournalMatch.InProgress)
            {
                intentDurable = true;
                throw new OutcomeUncertainException("OutcomeUncertain: önceki çalışmadan kalan durable print intent bulundu; otomatik yeniden baskı engellendi. Fiziksel çıktıyı kontrol edin ve gerekirse yeni JobId ile manuel tekrar gönderin.");
            }

            if (journalMatch == JournalMatch.Completed)
            {
                spoolAccepted = true;
                journalCompleted = true;
                var duplicateResult = _status.CreateJobResult(job, true, args.Message.DeliveryCount, "DuplicateSkipped: daha önce spool kabul edildi.");
                await _outbox.EnqueueAsync(duplicateResult, args.CancellationToken).ConfigureAwait(false);
                await args.CompleteMessageAsync(args.Message, args.CancellationToken).ConfigureAwait(false);
                _logger.Info($"İş {job.JobId}: journal duplicate; tekrar basılmadı.");
                await TryFlushOutboxAsync(args.CancellationToken).ConfigureAwait(false);
                return;
            }

            await _printer.PrintAsync(
                job,
                async cancellationToken =>
                {
                    await _journal.RecordInProgressAsync(job, DateTimeOffset.UtcNow, cancellationToken).ConfigureAwait(false);
                    intentDurable = true;
                },
                args.CancellationToken).ConfigureAwait(false);
            spoolAccepted = true;
            var completedAt = DateTimeOffset.UtcNow;
            await _journal.RecordCompletedAsync(job, completedAt, args.CancellationToken).ConfigureAwait(false);
            journalCompleted = true;
            _lastJobId = job.JobId;
            var successResult = _status.CreateJobResult(job, true, args.Message.DeliveryCount, "Windows spooler işi kabul etti.");
            await _outbox.EnqueueAsync(successResult, args.CancellationToken).ConfigureAwait(false);
            await args.CompleteMessageAsync(args.Message, args.CancellationToken).ConfigureAwait(false);
            RaiseConnectivity(true);
            _logger.Info($"İş {job.JobId}: tamamlandı ve broker mesajı complete edildi.");
            await TryFlushOutboxAsync(args.CancellationToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (args.CancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (PermanentJobException ex)
        {
            await FailAndSettleAsync(args, job, ex, permanent: true, intentDurable, spoolAccepted, journalCompleted).ConfigureAwait(false);
        }
        catch (AgentConfigurationException ex)
        {
            await HoldForConfigurationRepairAsync(args, ex).ConfigureAwait(false);
        }
        catch (OutcomeUncertainException ex)
        {
            // A validation/discovery helper can time out before the durable print
            // intent exists; that is retryable. It becomes quarantine-only once
            // physical printing may have started behind a durable intent.
            await FailAndSettleAsync(args, job, ex, intentDurable, intentDurable, spoolAccepted, journalCompleted: false).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            await FailAndSettleAsync(args, job, ex, permanent: false, intentDurable, spoolAccepted, journalCompleted).ConfigureAwait(false);
        }
    }

    private async Task FailAndSettleAsync(
        ProcessSessionMessageEventArgs args,
        PrintJobV1? job,
        Exception exception,
        bool permanent,
        bool intentDurable,
        bool spoolAccepted,
        bool journalCompleted)
    {
        var outcomeUncertain = intentDurable && !journalCompleted;
        if (outcomeUncertain)
        {
            permanent = true;
        }

        var decision = RetryPolicy.Decide(args.Message.DeliveryCount, _settings.MaxDeliveryAttempts, permanent);
        var safeMessage = exception.Message.Length <= 500 ? exception.Message : exception.Message[..500];
        var phase = journalCompleted
            ? "spool kabul edildikten sonra broker settlement"
            : outcomeUncertain
                ? "durable intent sonrası sonucu belirsiz baskı"
                : "yazdırma";
        _logger.Error($"İş {(job?.JobId ?? args.Message.MessageId)} {phase} hatası; attempt={args.Message.DeliveryCount}, action={decision}", exception);
        if (decision == RetryAction.Abandon)
        {
            var baseDelay = RetryPolicy.GetAbandonDelay(args.Message.DeliveryCount);
            var jitteredDelay = TimeSpan.FromMilliseconds(baseDelay.TotalMilliseconds * (0.9d + Random.Shared.NextDouble() * 0.2d));
            await Task.Delay(jitteredDelay, args.CancellationToken).ConfigureAwait(false);
            await args.AbandonMessageAsync(
                args.Message,
                new Dictionary<string, object> { ["lastFailure"] = safeMessage, ["lastFailureUtc"] = DateTimeOffset.UtcNow.ToString("O") },
                CancellationToken.None).ConfigureAwait(false);
            return;
        }

        // A completed journal entry is the authoritative physical outcome.
        // Never overwrite its durable success result with a failure merely
        // because CompleteMessageAsync or another post-spool operation failed.
        if (job is not null && !journalCompleted)
        {
            try
            {
                var resultMessage = outcomeUncertain
                    ? $"OutcomeUncertain: {(spoolAccepted ? "spool kabul edildi ancak journal completion yazılamadı" : "durable intent sonrası fiziksel sonuç kesin değil")}; otomatik tekrar baskı engellendi."
                    : safeMessage;
                var failedResult = _status.CreateJobResult(job, false, args.Message.DeliveryCount, resultMessage);
                await _outbox.EnqueueAsync(failedResult, CancellationToken.None).ConfigureAwait(false);
                await TryFlushOutboxAsync(CancellationToken.None).ConfigureAwait(false);
            }
            catch (Exception statusException)
            {
                _logger.Warning($"İş sonucu status kuyruğuna gönderilemedi: {statusException.Message}");
            }
        }

        await args.DeadLetterMessageAsync(
            args.Message,
            journalCompleted ? "BCWMSSettlementAfterPrint" : outcomeUncertain ? "BCWMSOutcomeUncertain" : "BCWMSPrintFailure",
            journalCompleted ? $"Physical spool accepted; broker settlement failed: {safeMessage}" : safeMessage,
            CancellationToken.None).ConfigureAwait(false);
    }

    private void ValidateBrokerMetadata(ServiceBusReceivedMessage message)
    {
        if (!string.Equals(message.SessionId, _settings.StationId, StringComparison.Ordinal))
        {
            throw new PermanentJobException("Service Bus SessionId yerel stationId ile eşleşmiyor.");
        }

        if (!string.Equals(message.ContentType, "application/json", StringComparison.OrdinalIgnoreCase))
        {
            throw new PermanentJobException("Service Bus ContentType application/json olmalıdır.");
        }
    }

    private static void ValidateMessageIdentity(ServiceBusReceivedMessage message, PrintJobV1 job)
    {
        if (!string.Equals(message.MessageId, job.JobId, StringComparison.Ordinal) ||
            !string.Equals(message.CorrelationId, job.JobId, StringComparison.Ordinal))
        {
            throw new PermanentJobException("Service Bus MessageId/CorrelationId body jobId ile birebir ve canonical eşleşmelidir.");
        }
    }

    private async Task ProcessErrorAsync(ProcessErrorEventArgs args)
    {
        Interlocked.Exchange(ref _jobsHealth, 2);
        RaiseConnectivity(false);
        _logger.Error($"Service Bus hata kaynağı={args.ErrorSource}, entity={args.EntityPath}", args.Exception);
        try
        {
            await _status.SendSnapshotAsync(receiverHealthy: false, CancellationToken.None).ConfigureAwait(false);
            await _status.SendHeartbeatAsync(_lastJobId, "Degraded", CancellationToken.None).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            _logger.Warning($"Degraded heartbeat gönderilemedi: {ex.Message}");
        }
    }

    private async Task SessionInitializingAsync(ProcessSessionEventArgs args)
    {
        Interlocked.Exchange(ref _jobsHealth, 1);
        RaiseConnectivity(true);
        try
        {
            await _status.SendSnapshotAsync(receiverHealthy: true, args.CancellationToken).ConfigureAwait(false);
            await _status.SendHeartbeatAsync(_lastJobId, CurrentHealthStatus(), args.CancellationToken).ConfigureAwait(false);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _logger.Warning($"Session recovery heartbeat gönderilemedi: {ex.Message}");
        }
    }

    private async Task HoldForConfigurationRepairAsync(ProcessSessionMessageEventArgs args, AgentConfigurationException exception)
    {
        Interlocked.Exchange(ref _jobsHealth, 2);
        RaiseConnectivity(false);
        _logger.Error("Agent credential/configuration hatası nedeniyle iş kilidi korunuyor; ayarlar yenilenip agent yeniden başlatılana kadar mesaj DLQ'ya atılmayacak.", exception);
        try
        {
            await _status.SendHeartbeatAsync(_lastJobId, "Degraded", CancellationToken.None).ConfigureAwait(false);
        }
        catch (Exception statusException)
        {
            _logger.Warning($"Configuration-failure heartbeat gönderilemedi: {statusException.Message}");
        }

        await Task.Delay(Timeout.InfiniteTimeSpan, args.CancellationToken).ConfigureAwait(false);
    }

    private async Task RunHeartbeatAsync(CancellationToken cancellationToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(_settings.HeartbeatSeconds));
        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                await _outbox.DrainAsync(_status.SendJobResultAsync, cancellationToken).ConfigureAwait(false);
                await _status.SendHeartbeatAsync(_lastJobId, CurrentHealthStatus(), cancellationToken).ConfigureAwait(false);
                if (IsReceiverReady)
                {
                    RaiseConnectivity(true);
                }
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception ex)
            {
                RaiseConnectivity(false);
                _logger.Warning($"Heartbeat gönderilemedi: {ex.Message}");
            }

            if (!await timer.WaitForNextTickAsync(cancellationToken).ConfigureAwait(false))
            {
                return;
            }
        }
    }

    private async Task TryFlushOutboxAsync(CancellationToken cancellationToken)
    {
        try
        {
            await _outbox.DrainAsync(_status.SendJobResultAsync, cancellationToken).ConfigureAwait(false);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _logger.Warning($"Status outbox Azure'a gönderilemedi; diskte saklanıp heartbeat ile tekrar denenecek: {ex.Message}");
        }
        catch (OperationCanceledException) { }
    }

    private string CurrentHealthStatus() =>
        _settings.BlobSasExpiresAtUtc is not { } expiry || expiry <= DateTimeOffset.UtcNow
            ? "Degraded"
            : Volatile.Read(ref _jobsHealth) switch
            {
                1 => "Online",
                2 => "Degraded",
                // BC keeps selected routes Active while Starting; health and
                // durable offline queueing are intentionally separate.
                _ => "Starting"
            };

    private void RaiseConnectivity(bool connected)
    {
        var handlers = ConnectivityChanged;
        if (handlers is null)
        {
            return;
        }

        foreach (EventHandler<bool> handler in handlers.GetInvocationList())
        {
            try
            {
                handler(this, connected);
            }
            catch (Exception ex)
            {
                // UI notification failures must never affect printing or broker
                // settlement semantics.
                _logger.Warning($"Bağlantı durumu UI'a iletilemedi: {ex.Message}");
            }
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (Interlocked.Exchange(ref _disposed, 1) != 0)
        {
            return;
        }

        _heartbeatCancellation?.Cancel();
        if (_heartbeatTask is not null)
        {
            try { await _heartbeatTask.ConfigureAwait(false); }
            catch (OperationCanceledException) { }
            catch (Exception ex) { _logger.Warning($"Heartbeat kapanış hatası: {ex.Message}"); }
        }

        // Azure SDK forbids changing processor event handlers while it is
        // running. Stop first so startup-failure cleanup cannot orphan a live
        // receiver or mask the original status-credential exception.
        try
        {
            if (_processor.IsProcessing)
            {
                await _processor.StopProcessingAsync(CancellationToken.None).ConfigureAwait(false);
            }
        }
        catch (Exception ex) { _logger.Warning($"Service Bus processor durdurulamadı: {ex.Message}"); }

        try { _processor.ProcessMessageAsync -= ProcessMessageAsync; }
        catch (Exception ex) { _logger.Warning($"ProcessMessage handler ayrılamadı: {ex.Message}"); }
        try { _processor.ProcessErrorAsync -= ProcessErrorAsync; }
        catch (Exception ex) { _logger.Warning($"ProcessError handler ayrılamadı: {ex.Message}"); }
        try { _processor.SessionInitializingAsync -= SessionInitializingAsync; }
        catch (Exception ex) { _logger.Warning($"SessionInitializing handler ayrılamadı: {ex.Message}"); }
        _heartbeatCancellation?.Dispose();
        try { await _processor.DisposeAsync().ConfigureAwait(false); }
        catch (Exception ex) { _logger.Warning($"Service Bus processor dispose hatası: {ex.Message}"); }
        try { await _jobsClient.DisposeAsync().ConfigureAwait(false); }
        catch (Exception ex) { _logger.Warning($"Jobs Service Bus client dispose hatası: {ex.Message}"); }
        try { await _status.DisposeAsync().ConfigureAwait(false); }
        catch (Exception ex) { _logger.Warning($"Status publisher dispose hatası: {ex.Message}"); }
    }
}
