using System.Globalization;
using System.Text.Json;
using BCWMS.PrintAgent.Core.Validation;

namespace BCWMS.PrintAgent.Core.Configuration;

public sealed record ImportedRuntimeSecrets(
    string StationId,
    string TenantId,
    string CompanyId,
    string JobsListenConnectionString,
    string StatusSendConnectionString,
    string StorageAccount,
    string BlobEndpoint,
    string BlobReadSas,
    DateTimeOffset BlobSasExpiresAtUtc);

public static class RuntimeSecretsParser
{
    private static readonly HashSet<string> AllowedRootProperties = new(StringComparer.Ordinal)
    {
        "schemaVersion",
        "generatedAtUtc",
        "blobSasExpiresAtUtc",
        "stationId",
        "routing",
        "agent"
    };

    public static ImportedRuntimeSecrets Parse(ReadOnlyMemory<byte> utf8Json)
    {
        using var document = JsonDocument.Parse(utf8Json, new JsonDocumentOptions
        {
            AllowTrailingCommas = false,
            CommentHandling = JsonCommentHandling.Disallow,
            MaxDepth = 16
        });
        var root = document.RootElement;
        if (root.ValueKind != JsonValueKind.Object)
        {
            throw new InvalidDataException("print-agent.runtime.secrets.json kökü JSON nesnesi olmalıdır.");
        }

        foreach (var property in root.EnumerateObject())
        {
            if (!AllowedRootProperties.Contains(property.Name))
            {
                var detail = string.Equals(property.Name, "businessCentral", StringComparison.Ordinal)
                    ? "BC credential kapsamı içeriyor"
                    : $"beklenmeyen '{property.Name}' alanı içeriyor";
                throw new InvalidDataException($"Seçilen dosya {detail}; yalnız agent yetkili print-agent.runtime.secrets.json dosyasını seçin.");
            }
        }

        if (GetInt(root, "schemaVersion") != 1)
        {
            throw new InvalidDataException("print-agent.runtime.secrets.json schemaVersion 1 olmalıdır.");
        }

        _ = ParseDate(GetString(root, "generatedAtUtc"), "generatedAtUtc");
        var expiry = ParseDate(GetString(root, "blobSasExpiresAtUtc"), "blobSasExpiresAtUtc");
        var stationId = GetString(root, "stationId");
        try
        {
            StationId.Validate(stationId);
        }
        catch (Exception exception) when (exception is ArgumentException or PermanentJobException)
        {
            throw new InvalidDataException("print-agent.runtime.secrets.json stationId canonical dört segment olmalıdır.", exception);
        }

        var stationSegments = stationId.Split('.');
        var routing = GetObject(root, "routing");
        var tenantId = GetString(routing, "tenantId");
        var companyId = GetString(routing, "companyId");
        if (!string.Equals(tenantId, stationSegments[0], StringComparison.Ordinal) ||
            !string.Equals(companyId, stationSegments[1], StringComparison.Ordinal))
        {
            throw new InvalidDataException("print-agent.runtime.secrets.json routing tenant/company değerleri stationId ile eşleşmiyor.");
        }

        var agent = GetObject(root, "agent");
        var container = GetString(agent, "blobContainerName");
        if (!string.Equals(container, CloudEntityNames.PrintJobsContainer, StringComparison.Ordinal))
        {
            throw new InvalidDataException($"Agent yalnız '{CloudEntityNames.PrintJobsContainer}' container'ını kabul eder.");
        }

        var account = GetString(agent, "blobAccountName");
        return new ImportedRuntimeSecrets(
            stationId,
            tenantId,
            companyId,
            GetString(agent, "printJobsListenConnectionString"),
            GetString(agent, "printerStatusSendConnectionString"),
            account,
            $"https://{account}.blob.core.windows.net",
            GetString(agent, "blobReadSasToken").TrimStart('?'),
            expiry);
    }

    private static DateTimeOffset ParseDate(string text, string name)
    {
        if (!DateTimeOffset.TryParse(text, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var value))
        {
            throw new InvalidDataException($"{name} geçerli ISO-8601 tarih değil.");
        }

        return value.ToUniversalTime();
    }

    private static JsonElement GetObject(JsonElement parent, string name)
    {
        if (!parent.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.Object)
        {
            throw new InvalidDataException($"print-agent.runtime.secrets.json '{name}' nesnesi eksik.");
        }

        return value;
    }

    private static string GetString(JsonElement parent, string name)
    {
        if (!parent.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.String || string.IsNullOrWhiteSpace(value.GetString()))
        {
            throw new InvalidDataException($"print-agent.runtime.secrets.json '{name}' alanı eksik.");
        }

        return value.GetString()!;
    }

    private static int GetInt(JsonElement parent, string name)
    {
        if (!parent.TryGetProperty(name, out var value) || !value.TryGetInt32(out var result))
        {
            throw new InvalidDataException($"print-agent.runtime.secrets.json '{name}' alanı eksik.");
        }

        return result;
    }
}
