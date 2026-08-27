using BCWMS.PrintAgent.Core.Configuration;
using BCWMS.PrintAgent.Core.Contracts;

namespace BCWMS.PrintAgent.Core.Validation;

public static class JobRoutingPolicy
{
    public static void Validate(PrintJobV1 job, AgentSettings settings)
    {
        if (!string.Equals(job.TenantId, settings.TenantId, StringComparison.Ordinal) ||
            !string.Equals(job.CompanyId, settings.CompanyId, StringComparison.Ordinal) ||
            !string.Equals(job.StationId, settings.StationId, StringComparison.Ordinal))
        {
            throw new PermanentJobException("Job tenant/company/station does not match the local allowlist.");
        }

        var pdf = job.Format == PrintFormat.PDF;
        if (!pdf && job.Format != settings.LabelFormat)
        {
            throw new PermanentJobException($"Job label format {job.Format} does not match configured format {settings.LabelFormat}.");
        }

        var expectedId = pdf ? settings.DocumentPrinterId : settings.LabelPrinterId;
        var expectedName = pdf ? settings.DocumentPrinterName : settings.LabelPrinterName;
        if (string.IsNullOrWhiteSpace(expectedId) || string.IsNullOrWhiteSpace(expectedName))
        {
            throw new PermanentJobException(pdf ? "Document printer is not configured." : "Label printer is not configured.");
        }

        if (!string.Equals(job.PrinterId, expectedId, StringComparison.Ordinal) ||
            !string.Equals(job.PrinterName, expectedName, StringComparison.OrdinalIgnoreCase))
        {
            throw new PermanentJobException("Job printerId/printerName does not match the local printer allowlist.");
        }
    }
}
