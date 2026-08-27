using BCWMS.PrintAgent.Core.Configuration;
using BCWMS.PrintAgent.Core.Reliability;
using BCWMS.PrintAgent.Core.Validation;
using BCWMS.PrintAgent.Windows.Cloud;
using BCWMS.PrintAgent.Windows.Configuration;
using BCWMS.PrintAgent.Windows.Infrastructure;
using BCWMS.PrintAgent.Windows.Printing;

namespace BCWMS.PrintAgent.Windows.App;

internal enum AgentState
{
    NotConfigured,
    Starting,
    Connected,
    Disconnected,
    Error,
    Stopped
}

internal sealed class AgentController : IAsyncDisposable
{
    private readonly WindowsConfigurationStore _configurationStore;
    private readonly WindowsPrinterDiscovery _discovery = new();
    private readonly FileJobJournal _journal;
    private readonly FileStatusOutbox _outbox;
    private readonly SemaphoreSlim _printGate = new(1, 1);
    private readonly SemaphoreSlim _gate = new(1, 1);
    private AzurePrintAgentRuntime? _runtime;

    public AgentController(AgentLogger logger)
    {
        Logger = logger;
        _configurationStore = new WindowsConfigurationStore(AgentPaths.ConfigPath);
        _journal = new FileJobJournal(AgentPaths.JournalPath);
        _outbox = new FileStatusOutbox(AgentPaths.StatusOutboxPath);
    }

    public AgentLogger Logger { get; }
    public AgentSettings Settings { get; private set; } = new();
    public AgentState State { get; private set; } = AgentState.NotConfigured;
    public string StateMessage { get; private set; } = "Ayar bekleniyor";
    public event EventHandler? StateChanged;

    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        AgentPaths.EnsureCreated();
        try
        {
            Settings = await _configurationStore.LoadAsync(cancellationToken).ConfigureAwait(true) ?? new AgentSettings();
            WarnIfSasExpiresSoon(Settings);
            if (AgentSettingsValidator.Validate(Settings).Count == 0)
            {
                await RestartRuntimeAsync(cancellationToken).ConfigureAwait(true);
            }
            else
            {
                SetState(AgentState.NotConfigured, "Ayarlar tamamlanmalı");
            }
        }
        catch (Exception ex)
        {
            Logger.Error("Agent başlatılamadı", ex);
            SetState(AgentState.Error, ex.Message);
        }
    }

    public Task<IReadOnlyList<DiscoveredPrinter>> DiscoverPrintersAsync(CancellationToken cancellationToken = default) =>
        _discovery.DiscoverAsync(cancellationToken);

    public async Task SaveAndRestartAsync(AgentSettings settings, IReadOnlyList<DiscoveredPrinter> printers, CancellationToken cancellationToken = default)
    {
        var canonicalStationId = StationId.NormalizeValue(settings.StationId);
        var segments = canonicalStationId.Split('.');
        var mappings = PrinterIdentity.EnsureMappings(settings.PrinterIdsByName, printers.Select(static printer => printer.Name));
        mappings = PrinterIdentity.EnsureMappings(mappings, new[] { settings.LabelPrinterName, settings.DocumentPrinterName });
        settings = settings with
        {
            StationId = canonicalStationId,
            TenantId = segments.Length > 0 ? segments[0] : string.Empty,
            CompanyId = segments.Length > 1 ? segments[1] : string.Empty,
            BlobReadSas = settings.BlobReadSas.Trim().TrimStart('?'),
            BlobEndpoint = settings.BlobEndpoint.Trim().TrimEnd('/'),
            LabelPrinterId = GetId(mappings, settings.LabelPrinterName),
            DocumentPrinterId = GetId(mappings, settings.DocumentPrinterName),
            PrinterIdsByName = mappings
        };
        var errors = AgentSettingsValidator.Validate(settings);
        if (errors.Count > 0)
        {
            throw new ArgumentException(string.Join(Environment.NewLine, errors));
        }

        await _gate.WaitAsync(cancellationToken).ConfigureAwait(true);
        try
        {
            var previousSettings = Settings;
            var previousSettingsWereValid = AgentSettingsValidator.Validate(previousSettings).Count == 0;
            await StopRuntimeCoreAsync(cancellationToken).ConfigureAwait(true);
            try
            {
                await _configurationStore.SaveAsync(settings, cancellationToken).ConfigureAwait(true);
                Settings = settings;
                WarnIfSasExpiresSoon(Settings);
                await StartRuntimeCoreAsync(cancellationToken).ConfigureAwait(true);
            }
            catch
            {
                if (previousSettingsWereValid)
                {
                    try
                    {
                        await _configurationStore.SaveAsync(previousSettings, CancellationToken.None).ConfigureAwait(true);
                        Settings = previousSettings;
                        await StartRuntimeCoreAsync(CancellationToken.None).ConfigureAwait(true);
                        Logger.Warning("Yeni ayarlar başlatılamadı; önceki çalışan DPAPI ayarları geri yüklendi.");
                    }
                    catch (Exception rollbackException)
                    {
                        Logger.Error("Yeni ayar hatasından sonra önceki ayarlara rollback başarısız", rollbackException);
                    }
                }

                throw;
            }
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task SyncSnapshotAsync(CancellationToken cancellationToken = default)
    {
        var runtime = RequireRuntime();
        await runtime.SendSnapshotAsync(cancellationToken).ConfigureAwait(true);
        Logger.Info("Yazıcı snapshot durumu buluta eşitlendi.");
    }

    public async Task PrintLabelTestAsync(CancellationToken cancellationToken = default)
    {
        if (_runtime is not null)
        {
            await _runtime.PrintLabelTestAsync(cancellationToken).ConfigureAwait(true);
        }
        else
        {
            await CreateLocalPrinter().PrintLabelTestAsync(cancellationToken).ConfigureAwait(true);
        }
        Logger.Info("Yerel etiket test işi spool tarafından kabul edildi.");
    }

    public async Task PrintDocumentTestAsync(CancellationToken cancellationToken = default)
    {
        if (_runtime is not null)
        {
            await _runtime.PrintDocumentTestAsync(cancellationToken).ConfigureAwait(true);
        }
        else
        {
            await CreateLocalPrinter().PrintDocumentTestAsync(cancellationToken).ConfigureAwait(true);
        }
        Logger.Info("Yerel PDF test işi spool tarafından kabul edildi.");
    }

    public Task<IReadOnlyList<JournalEntry>> GetUncertainPrintsAsync(CancellationToken cancellationToken = default) =>
        _journal.GetInProgressAsync(cancellationToken);

    public async Task MarkUncertainPrintAsCompletedAsync(string jobId, CancellationToken cancellationToken = default)
    {
        await _journal.MarkInProgressCompletedAsync(jobId, DateTimeOffset.UtcNow, cancellationToken).ConfigureAwait(true);
        Logger.Warning($"Operatör {jobId} işini fiziksel çıktıyı kontrol ederek Completed işaretledi.");
    }

    public async Task StopAsync(CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(true);
        try
        {
            await StopRuntimeCoreAsync(cancellationToken).ConfigureAwait(true);
            SetState(AgentState.Stopped, "Durduruldu");
        }
        finally
        {
            _gate.Release();
        }
    }

    private async Task RestartRuntimeAsync(CancellationToken cancellationToken)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(true);
        try
        {
            await StopRuntimeCoreAsync(cancellationToken).ConfigureAwait(true);
            await StartRuntimeCoreAsync(cancellationToken).ConfigureAwait(true);
        }
        finally
        {
            _gate.Release();
        }
    }

    private async Task StartRuntimeCoreAsync(CancellationToken cancellationToken)
    {
        SetState(AgentState.Starting, "Azure bağlantısı kuruluyor");
        StatusPublisher? status = null;
        AzurePrintAgentRuntime? runtime = null;
        try
        {
            status = new StatusPublisher(Settings, _discovery);
            var downloader = new BlobPayloadDownloader(Settings, Logger);
            var printer = new PrintCoordinator(Settings, downloader, Logger, _printGate);
            runtime = new AzurePrintAgentRuntime(Settings, Logger, _journal, _outbox, printer, status);
            runtime.ConnectivityChanged += RuntimeOnConnectivityChanged;
            await runtime.StartAsync(cancellationToken).ConfigureAwait(true);
            _runtime = runtime;
            SetState(
                runtime.IsReceiverReady ? AgentState.Connected : AgentState.Disconnected,
                runtime.IsReceiverReady ? "Azure kuyruğu dinleniyor" : "Listen doğrulaması için smoke job bekleniyor");
        }
        catch
        {
            if (runtime is not null)
            {
                runtime.ConnectivityChanged -= RuntimeOnConnectivityChanged;
                await runtime.DisposeAsync().ConfigureAwait(true);
            }
            else if (status is not null)
            {
                await status.DisposeAsync().ConfigureAwait(true);
            }
            SetState(AgentState.Error, "Azure bağlantısı başlatılamadı");
            throw;
        }
    }

    private async Task StopRuntimeCoreAsync(CancellationToken cancellationToken)
    {
        if (_runtime is null)
        {
            return;
        }

        var runtime = _runtime;
        _runtime = null;
        runtime.ConnectivityChanged -= RuntimeOnConnectivityChanged;
        try
        {
            await runtime.StopAsync(cancellationToken).ConfigureAwait(true);
        }
        finally
        {
            await runtime.DisposeAsync().ConfigureAwait(true);
        }
    }

    private void RuntimeOnConnectivityChanged(object? sender, bool connected) =>
        SetState(connected ? AgentState.Connected : AgentState.Disconnected, connected ? "Azure kuyruğu dinleniyor" : "Azure bağlantısı bekleniyor");

    private AzurePrintAgentRuntime RequireRuntime() =>
        _runtime ?? throw new InvalidOperationException("Önce geçerli ayarları kaydedip agent bağlantısını başlatın.");

    private PrintCoordinator CreateLocalPrinter() =>
        new(Settings, null, Logger, _printGate);

    private static string GetId(IReadOnlyDictionary<string, string> mappings, string printerName) =>
        string.IsNullOrWhiteSpace(printerName) ? string.Empty : mappings[printerName];

    private void WarnIfSasExpiresSoon(AgentSettings settings)
    {
        if (settings.BlobSasExpiresAtUtc is { } expiry && expiry - DateTimeOffset.UtcNow <= TimeSpan.FromDays(7))
        {
            Logger.Warning($"Blob SAS {expiry.LocalDateTime:g} tarihinde sona erecek; print-agent.runtime.secrets.json yenilenmeli.");
        }
    }

    private void SetState(AgentState state, string message)
    {
        State = state;
        StateMessage = message;
        StateChanged?.Invoke(this, EventArgs.Empty);
    }

    public async ValueTask DisposeAsync()
    {
        await StopAsync(CancellationToken.None).ConfigureAwait(true);
        // These gates intentionally live for the process lifetime. A local UI
        // test may still be unwinding its cancellation while the WinForms
        // message loop exits; disposing here would race its final Release().
    }
}
