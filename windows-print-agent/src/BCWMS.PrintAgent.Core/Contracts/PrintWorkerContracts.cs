namespace BCWMS.PrintAgent.Core.Contracts;

public enum PrintWorkerMode
{
    DiscoverPrinters,
    ValidatePdf,
    Print
}

public enum PrintWorkerFailureKind
{
    None,
    Permanent,
    Transient
}

public sealed record PrintWorkerRequest
{
    public int SchemaVersion { get; init; } = 1;
    public required PrintWorkerMode Mode { get; init; }
    public string PayloadPath { get; init; } = string.Empty;
    public string PrinterName { get; init; } = string.Empty;
    public string DocumentName { get; init; } = string.Empty;
    public PrintFormat Format { get; init; } = PrintFormat.PDF;
    public int Copies { get; init; } = 1;
}

public sealed record PrintWorkerResponse
{
    public int SchemaVersion { get; init; } = 1;
    public required bool Success { get; init; }
    public required PrintWorkerFailureKind FailureKind { get; init; }
    public required string Message { get; init; }
    public IReadOnlyList<PrintWorkerPrinter> Printers { get; init; } = [];
}

public sealed record PrintWorkerPrinter(string Name, string Status, bool IsDefault, bool IsOffline);

public static class PrintWorkerPolicy
{
    public static TimeSpan PdfValidationTimeout { get; } = TimeSpan.FromSeconds(60);
    public static TimeSpan PhysicalPrintTimeout { get; } = TimeSpan.FromMinutes(30);
    public static TimeSpan PrinterDiscoveryTimeout { get; } = TimeSpan.FromSeconds(15);

    public static void Validate(PrintWorkerRequest request)
    {
        if (request.SchemaVersion != 1 || !Enum.IsDefined(request.Mode))
        {
            throw new ArgumentException("Print worker request schema/mode is invalid.");
        }

        if (request.Mode == PrintWorkerMode.DiscoverPrinters)
        {
            return;
        }

        if (string.IsNullOrWhiteSpace(request.PayloadPath))
        {
            throw new ArgumentException("Print worker payload path is required.");
        }

        if (request.Mode == PrintWorkerMode.ValidatePdf)
        {
            if (request.Format != PrintFormat.PDF)
            {
                throw new ArgumentException("ValidatePdf mode requires PDF format.");
            }

            return;
        }

        if (request.Mode != PrintWorkerMode.Print ||
            string.IsNullOrWhiteSpace(request.PrinterName) || request.PrinterName.Length > 260 ||
            string.IsNullOrWhiteSpace(request.DocumentName) || request.DocumentName.Length > 260 ||
            request.Copies is < 1 or > 10 || !Enum.IsDefined(request.Format))
        {
            throw new ArgumentException("Physical print worker request is invalid.");
        }
    }
}
