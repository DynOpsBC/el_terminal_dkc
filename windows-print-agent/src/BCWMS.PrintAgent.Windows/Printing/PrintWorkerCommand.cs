using System.Text.Json;
using BCWMS.PrintAgent.Core.Contracts;
using BCWMS.PrintAgent.Core.Validation;
using BCWMS.PrintAgent.Windows.Infrastructure;

namespace BCWMS.PrintAgent.Windows.Printing;

internal static class PrintWorkerCommand
{
    public const string Switch = "--print-helper";
    private const int MaximumProtocolBytes = 64 * 1024;

    public static bool TryExecute(string[] args, out int exitCode)
    {
        exitCode = 0;
        if (args.Length == 0 || !string.Equals(args[0], Switch, StringComparison.Ordinal))
        {
            return false;
        }

        if (args.Length != 2)
        {
            exitCode = 2;
            return true;
        }

        exitCode = Execute(args[1]);
        return true;
    }

    private static int Execute(string requestPath)
    {
        PrintWorkerResponse response;
        string? safeRequestPath = null;
        try
        {
            AgentPaths.EnsureCreated();
            safeRequestPath = ValidateProtocolPath(requestPath);
            var bytes = File.ReadAllBytes(safeRequestPath);
            if (bytes.Length is <= 0 or > MaximumProtocolBytes)
            {
                throw new InvalidDataException("Print helper request exceeds its protocol size limit.");
            }

            var request = JsonSerializer.Deserialize<PrintWorkerRequest>(bytes, ContractSerializer.Options)
                ?? throw new InvalidDataException("Print helper request is JSON null.");
            PrintWorkerPolicy.Validate(request);
            if (request.Mode == PrintWorkerMode.DiscoverPrinters)
            {
                var printers = WindowsPrinterDiscovery.DiscoverInProcess(CancellationToken.None)
                    .Select(static printer => new PrintWorkerPrinter(printer.Name, printer.Status, printer.IsDefault, printer.IsOffline))
                    .ToArray();
                response = new PrintWorkerResponse
                {
                    Success = true,
                    FailureKind = PrintWorkerFailureKind.None,
                    Message = "Printer discovery completed.",
                    Printers = printers
                };
            }
            else
            {
                var payloadPath = ValidatePayloadPath(request.PayloadPath, request.Format);
                if (request.Mode == PrintWorkerMode.ValidatePdf)
                {
                    PdfiumPrintBackend.ValidateAsync(payloadPath, CancellationToken.None).GetAwaiter().GetResult();
                }
                else if (request.Format == PrintFormat.PDF)
                {
                    PdfiumPrintBackend.PrintAsync(request.PrinterName, request.DocumentName, payloadPath, request.Copies, CancellationToken.None).GetAwaiter().GetResult();
                }
                else
                {
                    var payload = File.ReadAllBytes(payloadPath);
                    WindowsRawSpooler.PrintAsync(request.PrinterName, request.DocumentName, payload, request.Copies, CancellationToken.None).GetAwaiter().GetResult();
                }

                response = new PrintWorkerResponse { Success = true, FailureKind = PrintWorkerFailureKind.None, Message = "Spool accepted." };
            }
        }
        catch (PermanentJobException ex)
        {
            response = Failure(PrintWorkerFailureKind.Permanent, ex.Message);
        }
        catch (Exception ex)
        {
            response = Failure(PrintWorkerFailureKind.Transient, ex.Message);
        }

        if (safeRequestPath is null)
        {
            return 3;
        }

        try
        {
            var responsePath = safeRequestPath + ".result";
            var temporary = responsePath + ".tmp-" + Guid.NewGuid().ToString("N");
            File.WriteAllBytes(temporary, ContractSerializer.Serialize(response));
            File.Move(temporary, responsePath, overwrite: true);
            return response.Success ? 0 : 1;
        }
        catch
        {
            return 4;
        }
    }

    private static PrintWorkerResponse Failure(PrintWorkerFailureKind kind, string message) => new()
    {
        Success = false,
        FailureKind = kind,
        Message = message.Length <= 500 ? message : message[..500]
    };

    private static string ValidateProtocolPath(string path)
    {
        var fullPath = ValidateInsideSpool(path);
        var name = Path.GetFileName(fullPath);
        if (!name.StartsWith("print-helper-", StringComparison.Ordinal) || !name.EndsWith(".json", StringComparison.Ordinal) ||
            !Guid.TryParseExact(name[13..^5], "N", out _))
        {
            throw new InvalidDataException("Print helper request filename is invalid.");
        }

        return fullPath;
    }

    private static string ValidatePayloadPath(string path, PrintFormat format)
    {
        var fullPath = ValidateInsideSpool(path);
        var expectedExtension = format == PrintFormat.PDF ? ".pdf" : ".raw";
        if (!string.Equals(Path.GetExtension(fullPath), expectedExtension, StringComparison.OrdinalIgnoreCase) || !File.Exists(fullPath))
        {
            throw new InvalidDataException("Print helper payload path/extension is invalid.");
        }

        return fullPath;
    }

    private static string ValidateInsideSpool(string path)
    {
        var root = Path.GetFullPath(AgentPaths.SpoolDirectory) + Path.DirectorySeparatorChar;
        var fullPath = Path.GetFullPath(path);
        if (!fullPath.StartsWith(root, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException("Print helper paths must remain inside the agent spool directory.");
        }

        return fullPath;
    }
}
