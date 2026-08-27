using System.Text.RegularExpressions;
using BCWMS.PrintAgent.Core.Contracts;

namespace BCWMS.PrintAgent.Core.Validation;

public static partial class PrintJobValidator
{
    public static void Validate(PrintJobV1 job)
    {
        if (job.SchemaVersion != ContractV1.SchemaVersion)
        {
            throw new PermanentJobException($"Unsupported schemaVersion '{job.SchemaVersion}'. Expected 1.");
        }

        RequireBounded(job.JobId, nameof(job.JobId), 1, 128);
        if (!Guid.TryParseExact(job.JobId, "D", out var jobGuid) ||
            jobGuid == Guid.Empty ||
            !string.Equals(job.JobId, jobGuid.ToString("D"), StringComparison.Ordinal))
        {
            throw new PermanentJobException("jobId must be a non-empty canonical lowercase GUID in D format.");
        }

        RequireBounded(job.TenantId, nameof(job.TenantId), 1, 128);
        RequireBounded(job.CompanyId, nameof(job.CompanyId), 1, 128);
        RequireBounded(job.PrinterId, nameof(job.PrinterId), 1, 20);
        if (!PrinterIdRegex().IsMatch(job.PrinterId))
        {
            throw new PermanentJobException("printerId must be exactly P followed by 16 uppercase hexadecimal characters.");
        }
        RequireBounded(job.PrinterName, nameof(job.PrinterName), 1, 260);
        StationId.Validate(job.StationId);

        if (!Enum.IsDefined(job.Format))
        {
            throw new PermanentJobException("format must be PDF, ZPL, ESCPOS, or RAW.");
        }

        if (job.PayloadSha256 is null || !Sha256Regex().IsMatch(job.PayloadSha256))
        {
            throw new PermanentJobException("payloadSha256 must be exactly 64 hexadecimal characters.");
        }

        if (job.Copies is < 1 or > 10)
        {
            throw new PermanentJobException("copies must be between 1 and 10.");
        }

        if (job.PayloadSize <= 0)
        {
            throw new PermanentJobException("payloadSize must be greater than zero.");
        }

        RequireBounded(job.BlobName, nameof(job.BlobName), 1, 1024);
        if (job.BlobName.StartsWith("/", StringComparison.Ordinal) ||
            job.BlobName.Contains("\\", StringComparison.Ordinal) ||
            job.BlobName.Split('/').Any(static segment => segment is "." or ".."))
        {
            throw new PermanentJobException("blobName must be a relative blob name without traversal segments or backslashes.");
        }

        var extension = job.Format.ToString().ToLowerInvariant();
        var expectedBlobName = $"jobs/{job.StationId}/{job.JobId}.{extension}";
        if (!string.Equals(job.BlobName, expectedBlobName, StringComparison.Ordinal))
        {
            throw new PermanentJobException($"blobName must be exactly '{expectedBlobName}'.");
        }

        var now = DateTimeOffset.UtcNow;
        if (job.CreatedAtUtc == default || job.CreatedAtUtc > now.AddMinutes(5) || job.CreatedAtUtc < now.AddDays(-30))
        {
            throw new PermanentJobException("createdAtUtc is outside the accepted -30 day/+5 minute window.");
        }
    }

    private static void RequireBounded(string? value, string name, int min, int max)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length < min || value.Length > max || value.Any(char.IsControl))
        {
            throw new PermanentJobException($"{name} must contain {min}..{max} printable characters.");
        }
    }

    [GeneratedRegex("^[0-9A-F]{64}$", RegexOptions.CultureInvariant)]
    private static partial Regex Sha256Regex();

    [GeneratedRegex("^P[0-9A-F]{16}$", RegexOptions.CultureInvariant)]
    private static partial Regex PrinterIdRegex();
}
