using System.Reflection;
using System.Text.Json;
using Azure.Messaging.ServiceBus;
using BCWMS.PrintAgent.Core.Configuration;
using BCWMS.PrintAgent.Core.Contracts;
using BCWMS.PrintAgent.Windows.Printing;

namespace BCWMS.PrintAgent.Windows.Cloud;

internal sealed class StatusPublisher : IAsyncDisposable
{
    private readonly AgentSettings _settings;
    private readonly ServiceBusClient _client;
    private readonly ServiceBusSender _sender;
    private readonly WindowsPrinterDiscovery _discovery;
    private readonly string _version;

    public StatusPublisher(AgentSettings settings, WindowsPrinterDiscovery discovery)
    {
        _settings = settings;
        _discovery = discovery;
        _version = Assembly.GetExecutingAssembly().GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
            ?? Assembly.GetExecutingAssembly().GetName().Version?.ToString()
            ?? "1.0.0";
        _client = new ServiceBusClient(settings.StatusSendConnectionString, new ServiceBusClientOptions
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
        _sender = _client.CreateSender(CloudEntityNames.PrinterStatusQueue);
    }

    public async Task SendSnapshotAsync(bool receiverHealthy, CancellationToken cancellationToken)
    {
        var installed = await _discovery.DiscoverAsync(cancellationToken).ConfigureAwait(false);
        var byName = installed.ToDictionary(static printer => printer.Name, StringComparer.OrdinalIgnoreCase);
        var rows = new List<PrinterSnapshotItemV1>();
        AddSelectedPrinter(rows, byName, _settings.LabelPrinterId, _settings.LabelPrinterName, _settings.LabelFormat, receiverHealthy);
        AddSelectedPrinter(rows, byName, _settings.DocumentPrinterId, _settings.DocumentPrinterName, PrintFormat.PDF, receiverHealthy);

        var selection = new PrinterSelectionV1
        {
            LabelPrinterId = _settings.LabelPrinterId,
            DocumentPrinterId = _settings.DocumentPrinterId,
            LabelTransport = "WindowsRaw"
        };
        await SendAsync(new PrinterSnapshotV1
        {
            MessageId = Guid.NewGuid().ToString("D"),
            TenantId = _settings.TenantId,
            CompanyId = _settings.CompanyId,
            StationId = _settings.StationId,
            AgentId = _settings.AgentId,
            SentAtUtc = DateTimeOffset.UtcNow,
            AgentVersion = _version,
            Printers = rows,
            Selection = selection
        }, cancellationToken).ConfigureAwait(false);
    }

    public Task SendHeartbeatAsync(string? lastJobId, string status, CancellationToken cancellationToken) => SendAsync(new HeartbeatV1
    {
        MessageId = Guid.NewGuid().ToString("D"),
        TenantId = _settings.TenantId,
        CompanyId = _settings.CompanyId,
        StationId = _settings.StationId,
        AgentId = _settings.AgentId,
        SentAtUtc = DateTimeOffset.UtcNow,
        AgentVersion = _version,
        Status = status,
        LastJobId = lastJobId
    }, cancellationToken);

    public JobResultV1 CreateJobResult(PrintJobV1 job, bool success, int attempt, string message) => new()
    {
        MessageId = Guid.NewGuid().ToString("D"),
        TenantId = _settings.TenantId,
        CompanyId = _settings.CompanyId,
        StationId = _settings.StationId,
        AgentId = _settings.AgentId,
        SentAtUtc = DateTimeOffset.UtcNow,
        AgentVersion = _version,
        JobId = job.JobId,
        PrinterId = job.PrinterId,
        PrinterName = job.PrinterName,
        Format = job.Format,
        Success = success,
        Message = message.Length <= 500 ? message : message[..500],
        CompletedAtUtc = DateTimeOffset.UtcNow,
        Attempt = attempt
    };

    public Task SendJobResultAsync(JobResultV1 result, CancellationToken cancellationToken) => SendAsync(result, cancellationToken);

    private static void AddSelectedPrinter(
        ICollection<PrinterSnapshotItemV1> rows,
        IReadOnlyDictionary<string, DiscoveredPrinter> installed,
        string printerId,
        string printerName,
        PrintFormat format,
        bool receiverHealthy)
    {
        if (string.IsNullOrWhiteSpace(printerId) || string.IsNullOrWhiteSpace(printerName))
        {
            return;
        }

        var exists = installed.TryGetValue(printerName, out var printer);
        rows.Add(new PrinterSnapshotItemV1
        {
            PrinterId = printerId,
            PrinterName = printerName,
            Format = format,
            Status = receiverHealthy && exists ? printer!.Status : "Offline",
            IsDefault = exists && printer!.IsDefault
        });
    }

    private async Task SendAsync(StatusMessageV1 value, CancellationToken cancellationToken)
    {
        var body = JsonSerializer.SerializeToUtf8Bytes(value, value.GetType(), ContractSerializer.Options);
        var message = new ServiceBusMessage(body)
        {
            MessageId = value.MessageId,
            Subject = value.MessageType,
            ContentType = "application/json",
            CorrelationId = value is JobResultV1 result ? result.JobId : value.AgentId
        };
        if (value is HeartbeatV1)
        {
            message.TimeToLive = TimeSpan.FromSeconds(Math.Max(90, _settings.HeartbeatSeconds * 3));
        }
        else if (value is PrinterSnapshotV1)
        {
            message.TimeToLive = TimeSpan.FromMinutes(15);
        }
        message.ApplicationProperties["schemaVersion"] = ContractV1.SchemaVersion;
        message.ApplicationProperties["messageType"] = value.MessageType;
        message.ApplicationProperties["tenantId"] = value.TenantId;
        message.ApplicationProperties["companyId"] = value.CompanyId;
        message.ApplicationProperties["stationId"] = value.StationId;
        await _sender.SendMessageAsync(message, cancellationToken).ConfigureAwait(false);
    }

    public async ValueTask DisposeAsync()
    {
        await _sender.DisposeAsync().ConfigureAwait(false);
        await _client.DisposeAsync().ConfigureAwait(false);
    }
}
