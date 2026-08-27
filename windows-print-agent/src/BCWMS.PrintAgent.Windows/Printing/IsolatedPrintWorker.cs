using System.Diagnostics;
using System.Text.Json;
using BCWMS.PrintAgent.Core.Contracts;
using BCWMS.PrintAgent.Core.Validation;
using BCWMS.PrintAgent.Windows.Cloud;
using BCWMS.PrintAgent.Windows.Infrastructure;

namespace BCWMS.PrintAgent.Windows.Printing;

internal static class IsolatedPrintWorker
{
    private const int MaximumProtocolBytes = 64 * 1024;

    public static async Task ValidatePdfAsync(string payloadPath, CancellationToken cancellationToken) => _ = await ExecuteAsync(new PrintWorkerRequest
    {
        Mode = PrintWorkerMode.ValidatePdf,
        PayloadPath = payloadPath,
        Format = PrintFormat.PDF
    }, PrintWorkerPolicy.PdfValidationTimeout, cancellationToken);

    public static async Task PrintAsync(
        string payloadPath,
        string printerName,
        string documentName,
        PrintFormat format,
        int copies,
        CancellationToken cancellationToken) => _ = await ExecuteAsync(new PrintWorkerRequest
        {
            Mode = PrintWorkerMode.Print,
            PayloadPath = payloadPath,
            PrinterName = printerName,
            DocumentName = documentName,
            Format = format,
            Copies = copies
        }, PrintWorkerPolicy.PhysicalPrintTimeout, cancellationToken).ConfigureAwait(false);

    public static async Task<IReadOnlyList<DiscoveredPrinter>> DiscoverPrintersAsync(CancellationToken cancellationToken)
    {
        var response = await ExecuteAsync(new PrintWorkerRequest
        {
            Mode = PrintWorkerMode.DiscoverPrinters
        }, PrintWorkerPolicy.PrinterDiscoveryTimeout, cancellationToken).ConfigureAwait(false);
        return response.Printers
            .Select(static printer => new DiscoveredPrinter(printer.Name, printer.Status, printer.IsDefault, printer.IsOffline))
            .ToArray();
    }

    private static async Task<PrintWorkerResponse> ExecuteAsync(PrintWorkerRequest request, TimeSpan timeout, CancellationToken cancellationToken)
    {
        PrintWorkerPolicy.Validate(request);
        AgentPaths.EnsureCreated();
        var protocolId = Guid.NewGuid().ToString("N");
        var requestPath = Path.Combine(AgentPaths.SpoolDirectory, $"print-helper-{protocolId}.json");
        var responsePath = requestPath + ".result";
        try
        {
            await File.WriteAllBytesAsync(requestPath, ContractSerializer.Serialize(request), cancellationToken).ConfigureAwait(false);
            var executable = Environment.ProcessPath;
            if (string.IsNullOrWhiteSpace(executable))
            {
                throw new AgentConfigurationException("Print helper executable path could not be resolved.");
            }

            using var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = executable,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WorkingDirectory = AppContext.BaseDirectory
                }
            };
            process.StartInfo.ArgumentList.Add(PrintWorkerCommand.Switch);
            process.StartInfo.ArgumentList.Add(requestPath);
            if (!process.Start())
            {
                throw new TransientJobException("Isolated print helper could not be started.");
            }

            using var timeoutCancellation = new CancellationTokenSource(timeout);
            using var linked = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, timeoutCancellation.Token);
            try
            {
                await process.WaitForExitAsync(linked.Token).ConfigureAwait(false);
            }
            catch (OperationCanceledException) when (timeoutCancellation.IsCancellationRequested && !cancellationToken.IsCancellationRequested)
            {
                var terminated = TryKill(process);
                var message = $"Isolated {request.Mode} helper exceeded its {timeout.TotalSeconds:0}-second hard timeout; child termination {(terminated ? "was confirmed" : "could not be confirmed")} .";
                if (request.Mode == PrintWorkerMode.Print)
                {
                    throw new OutcomeUncertainException(message);
                }

                throw new TransientJobException(message);
            }
            catch (OperationCanceledException)
            {
                _ = TryKill(process);
                throw;
            }

            var response = await ReadResponseAsync(responsePath, request.Mode == PrintWorkerMode.Print, cancellationToken).ConfigureAwait(false);
            if (response.Success && process.ExitCode == 0)
            {
                return response;
            }

            if (response.FailureKind == PrintWorkerFailureKind.Permanent)
            {
                throw new PermanentJobException(response.Message);
            }

            throw new TransientJobException(response.Message);
        }
        finally
        {
            BlobPayloadDownloader.DeleteIfExists(requestPath);
            BlobPayloadDownloader.DeleteIfExists(responsePath);
        }
    }

    private static async Task<PrintWorkerResponse> ReadResponseAsync(string path, bool physicalPrintMayHaveStarted, CancellationToken cancellationToken)
    {
        if (!File.Exists(path) || new FileInfo(path).Length is <= 0 or > MaximumProtocolBytes)
        {
            if (physicalPrintMayHaveStarted)
            {
                throw new OutcomeUncertainException("Isolated print helper exited without a valid result; physical outcome is uncertain.");
            }

            throw new TransientJobException("Isolated helper exited without a valid result.");
        }

        var bytes = await File.ReadAllBytesAsync(path, cancellationToken).ConfigureAwait(false);
        var response = JsonSerializer.Deserialize<PrintWorkerResponse>(bytes, ContractSerializer.Options);
        if (response is not null)
        {
            return response;
        }

        if (physicalPrintMayHaveStarted)
        {
            throw new OutcomeUncertainException("Isolated print helper returned JSON null; physical outcome is uncertain.");
        }

        throw new TransientJobException("Isolated helper returned JSON null.");
    }

    private static bool TryKill(Process process)
    {
        try
        {
            if (!process.HasExited)
            {
                process.Kill(entireProcessTree: true);
                return process.WaitForExit(5_000) && process.HasExited;
            }
            return true;
        }
        catch (InvalidOperationException) { return process.HasExited; }
        catch (System.ComponentModel.Win32Exception) { return false; }
    }
}
