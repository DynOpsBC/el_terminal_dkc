using BCWMS.PrintAgent.Core.Configuration;
using BCWMS.PrintAgent.Core.Contracts;
using BCWMS.PrintAgent.Core.Validation;
using BCWMS.PrintAgent.Windows.Cloud;
using BCWMS.PrintAgent.Windows.Infrastructure;

namespace BCWMS.PrintAgent.Windows.Printing;

internal sealed class PrintCoordinator
{
    private readonly AgentSettings _settings;
    private readonly BlobPayloadDownloader? _downloader;
    private readonly AgentLogger _logger;
    private readonly SemaphoreSlim _printGate;

    public PrintCoordinator(AgentSettings settings, BlobPayloadDownloader? downloader, AgentLogger logger, SemaphoreSlim printGate)
    {
        _settings = settings;
        _downloader = downloader;
        _logger = logger;
        _printGate = printGate;
    }

    public async Task PrintAsync(
        PrintJobV1 job,
        Func<CancellationToken, Task> beforePhysicalPrintAsync,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(beforePhysicalPrintAsync);
        ValidateRouting(job);
        var downloader = _downloader ?? throw new InvalidOperationException("Cloud payload downloader is not configured.");
        var path = await downloader.DownloadVerifiedAsync(job, cancellationToken).ConfigureAwait(false);
        try
        {
            _logger.Info($"İş {job.JobId}: {job.Format} -> {job.PrinterName}, {job.Copies} kopya.");
            if (job.Format == PrintFormat.PDF)
            {
                await IsolatedPrintWorker.ValidatePdfAsync(path, cancellationToken).ConfigureAwait(false);
            }

            await _printGate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try
            {
                await beforePhysicalPrintAsync(cancellationToken).ConfigureAwait(false);
                await IsolatedPrintWorker.PrintAsync(path, job.PrinterName, $"BCWMS-{job.JobId}", job.Format, job.Copies, cancellationToken).ConfigureAwait(false);
            }
            finally
            {
                _printGate.Release();
            }
        }
        finally
        {
            BlobPayloadDownloader.DeleteIfExists(path);
        }
    }

    public async Task PrintLabelTestAsync(CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(_settings.LabelPrinterName))
        {
            throw new PermanentJobException("Etiket yazıcısı seçilmedi.");
        }

        var bytes = TestDocumentFactory.CreateRaw(_settings.LabelFormat, _settings.StationId);
        AgentPaths.EnsureCreated();
        var path = Path.Combine(AgentPaths.SpoolDirectory, "local-test-" + Guid.NewGuid().ToString("N") + ".raw");
        try
        {
            await File.WriteAllBytesAsync(path, bytes, cancellationToken).ConfigureAwait(false);
            await _printGate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try
            {
                await IsolatedPrintWorker.PrintAsync(path, _settings.LabelPrinterName, "BCWMS-LOCAL-TEST", _settings.LabelFormat, 1, cancellationToken).ConfigureAwait(false);
            }
            finally
            {
                _printGate.Release();
            }
        }
        finally
        {
            BlobPayloadDownloader.DeleteIfExists(path);
        }
    }

    public async Task PrintDocumentTestAsync(CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(_settings.DocumentPrinterName))
        {
            throw new PermanentJobException("Belge yazıcısı seçilmedi.");
        }

        AgentPaths.EnsureCreated();
        var path = Path.Combine(AgentPaths.SpoolDirectory, "local-test-" + Guid.NewGuid().ToString("N") + ".pdf");
        try
        {
            await File.WriteAllBytesAsync(path, TestDocumentFactory.CreatePdf(_settings.StationId), cancellationToken).ConfigureAwait(false);
            await IsolatedPrintWorker.ValidatePdfAsync(path, cancellationToken).ConfigureAwait(false);
            await _printGate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try
            {
                await IsolatedPrintWorker.PrintAsync(path, _settings.DocumentPrinterName, "BCWMS-LOCAL-TEST", PrintFormat.PDF, 1, cancellationToken).ConfigureAwait(false);
            }
            finally
            {
                _printGate.Release();
            }
        }
        finally
        {
            BlobPayloadDownloader.DeleteIfExists(path);
        }
    }

    private void ValidateRouting(PrintJobV1 job)
    {
        JobRoutingPolicy.Validate(job, _settings);
    }
}
