using BCWMS.PrintAgent.Core.Contracts;
using BCWMS.PrintAgent.Core.Validation;

namespace BCWMS.PrintAgent.Core.Configuration;

public static class CloudEntityNames
{
    public const string PrintJobsQueue = "print-jobs-queue";
    public const string PrinterStatusQueue = "printer-status-queue";
    public const string PrintJobsContainer = "print-jobs";
}

public enum LabelTransport
{
    WindowsRaw
}

public sealed record AgentSettings
{
    public int SchemaVersion { get; init; } = 1;
    public string AgentId { get; init; } = Guid.NewGuid().ToString("D");
    public string TenantId { get; init; } = string.Empty;
    public string CompanyId { get; init; } = string.Empty;
    public string StationId { get; init; } = StationIdDefault();
    public string JobsListenConnectionString { get; init; } = string.Empty;
    public string StatusSendConnectionString { get; init; } = string.Empty;
    public string StorageAccount { get; init; } = string.Empty;
    public string BlobEndpoint { get; init; } = string.Empty;
    public string BlobReadSas { get; init; } = string.Empty;
    public DateTimeOffset? BlobSasExpiresAtUtc { get; init; }
    public string LabelPrinterId { get; init; } = string.Empty;
    public string LabelPrinterName { get; init; } = string.Empty;
    public string DocumentPrinterId { get; init; } = string.Empty;
    public string DocumentPrinterName { get; init; } = string.Empty;
    public LabelTransport LabelTransport { get; init; } = LabelTransport.WindowsRaw;
    public PrintFormat LabelFormat { get; init; } = PrintFormat.ZPL;
    public int MaxDeliveryAttempts { get; init; } = 5;
    public int MaxPayloadBytes { get; init; } = 50 * 1024 * 1024;
    public int HeartbeatSeconds { get; init; } = 300;
    public Dictionary<string, string> PrinterIdsByName { get; init; } = new(StringComparer.OrdinalIgnoreCase);

    private static string StationIdDefault()
    {
        try
        {
            return Validation.StationId.Normalize("DEFAULT", "DEFAULT", "DEFAULT", Environment.MachineName);
        }
        catch
        {
            return "DEFAULT.DEFAULT.DEFAULT.STATION";
        }
    }
}

public static class AgentSettingsValidator
{
    public static IReadOnlyList<string> Validate(AgentSettings settings)
    {
        var errors = new List<string>();
        if (settings.SchemaVersion != 1)
        {
            errors.Add("Ayar şeması sürümü 1 olmalıdır.");
        }

        if (!Guid.TryParseExact(settings.AgentId, "D", out var agentId) || agentId == Guid.Empty)
        {
            errors.Add("Agent ID geçerli bir GUID olmalıdır.");
        }

        Try(() => Validation.StationId.Validate(settings.StationId), errors);
        Require(settings.TenantId, 128, "Tenant ID", errors);
        Require(settings.CompanyId, 128, "Company ID", errors);
        var stationSegments = settings.StationId.Split('.');
        if (stationSegments.Length != 4 || stationSegments.Any(string.IsNullOrWhiteSpace))
        {
            errors.Add("Station ID tam dört segment olmalıdır: TENANT.COMPANY.WAREHOUSE.STATION.");
        }
        else if (!string.Equals(settings.TenantId, stationSegments[0], StringComparison.Ordinal) ||
                 !string.Equals(settings.CompanyId, stationSegments[1], StringComparison.Ordinal))
        {
            errors.Add("Tenant ID ve Company ID, Station ID'nin ilk iki segmentiyle eşleşmelidir.");
        }
        var jobsBus = ValidateServiceBusConnection(
            settings.JobsListenConnectionString,
            "İş kuyruğu bağlantısı",
            CloudEntityNames.PrintJobsQueue,
            "agent-listen-jobs",
            errors);
        var statusBus = ValidateServiceBusConnection(
            settings.StatusSendConnectionString,
            "Durum kuyruğu bağlantısı",
            CloudEntityNames.PrinterStatusQueue,
            "agent-send-status",
            errors);
        if (jobsBus is not null && statusBus is not null &&
            !string.Equals(jobsBus.Value.Endpoint, statusBus.Value.Endpoint, StringComparison.OrdinalIgnoreCase))
        {
            errors.Add("İş ve durum kuyrukları aynı Service Bus namespace endpoint'ini kullanmalıdır.");
        }
        ValidateStorage(settings, errors);
        if (settings.BlobSasExpiresAtUtc is not { } expiry)
        {
            errors.Add("Blob SAS bitiş zamanı zorunludur; print-agent.runtime.secrets.json içe aktarılmalıdır.");
        }
        else if (expiry <= DateTimeOffset.UtcNow)
        {
            errors.Add("Blob SAS süresi dolmuş; print-agent.runtime.secrets.json yeniden üretilmelidir.");
        }

        if (string.IsNullOrWhiteSpace(settings.LabelPrinterName) && string.IsNullOrWhiteSpace(settings.DocumentPrinterName))
        {
            errors.Add("En az bir etiket veya belge yazıcısı seçilmelidir.");
        }

        ValidateSelectedPrinter(settings.LabelPrinterId, settings.LabelPrinterName, "Etiket", errors);
        ValidateSelectedPrinter(settings.DocumentPrinterId, settings.DocumentPrinterName, "Belge", errors);
        ValidateSelectedMapping(settings.PrinterIdsByName, settings.LabelPrinterId, settings.LabelPrinterName, "Etiket", errors);
        ValidateSelectedMapping(settings.PrinterIdsByName, settings.DocumentPrinterId, settings.DocumentPrinterName, "Belge", errors);
        if (!string.IsNullOrWhiteSpace(settings.LabelPrinterName) &&
            string.Equals(settings.LabelPrinterName, settings.DocumentPrinterName, StringComparison.OrdinalIgnoreCase))
        {
            errors.Add("Etiket ve belge için farklı Windows yazıcı kuyrukları seçilmelidir.");
        }

        if (settings.LabelTransport != LabelTransport.WindowsRaw)
        {
            errors.Add("v1 agent yalnız WindowsRaw etiket transport destekler.");
        }

        if (settings.LabelFormat == PrintFormat.PDF)
        {
            errors.Add("Etiket formatı ZPL, ESCPOS veya RAW olmalıdır.");
        }

        if (settings.MaxDeliveryAttempts is < 1 or > 10)
        {
            errors.Add("Maksimum deneme sayısı 1..10 arasında olmalıdır.");
        }

        if (settings.MaxPayloadBytes is < 1024 or > 50 * 1024 * 1024)
        {
            errors.Add("Maksimum dosya boyutu 1 KB..50 MB arasında olmalıdır.");
        }

        if (settings.HeartbeatSeconds is < 30 or > 3600)
        {
            errors.Add("Heartbeat aralığı 30..3600 saniye arasında olmalıdır.");
        }

        foreach (var pair in settings.PrinterIdsByName)
        {
            if (string.IsNullOrWhiteSpace(pair.Key) || !PrinterIdentity.IsValid(pair.Value))
            {
                errors.Add("Yazıcı kimlik eşlemesi geçersiz.");
                break;
            }
        }

        if (settings.PrinterIdsByName.Count > 256)
        {
            errors.Add("Yazıcı kimlik eşlemesi en fazla 256 kayıt içerebilir.");
        }

        if (settings.PrinterIdsByName.Values.Distinct(StringComparer.Ordinal).Count() != settings.PrinterIdsByName.Count)
        {
            errors.Add("Aynı logical Printer ID birden fazla Windows yazıcısına atanamaz.");
        }

        return errors;
    }

    private static void ValidateStorage(AgentSettings settings, List<string> errors)
    {
        if (string.IsNullOrWhiteSpace(settings.StorageAccount) ||
            settings.StorageAccount.Length is < 3 or > 24 ||
            !settings.StorageAccount.All(static character =>
                character is >= 'a' and <= 'z' or >= '0' and <= '9'))
        {
            errors.Add("Storage Account yalnız küçük harf/rakam içeren 3..24 karakter olmalıdır.");
        }

        if (!Uri.TryCreate(settings.BlobEndpoint, UriKind.Absolute, out var endpoint) ||
            endpoint.Scheme != Uri.UriSchemeHttps ||
            endpoint.UserInfo.Length != 0 ||
            endpoint.Query.Length != 0 ||
            endpoint.Fragment.Length != 0 ||
            endpoint.AbsolutePath.Trim('/').Length != 0)
        {
            errors.Add("Blob endpoint yalnız kök HTTPS adresi olmalıdır.");
        }
        else if (!string.Equals(endpoint.Host, settings.StorageAccount + ".blob.core.windows.net", StringComparison.OrdinalIgnoreCase))
        {
            errors.Add("Blob endpoint, allowlist Storage Account adıyla eşleşmelidir.");
        }

        var sas = settings.BlobReadSas.Trim().TrimStart('?');
        var hasStoredPolicy = TryGetSasValue(sas, "si", out var policy) &&
                              string.Equals(policy, "agent-read", StringComparison.Ordinal);
        var hasPermissions = TryGetSasValue(sas, "sp", out var permissions);
        var isContainerScope = TryGetSasValue(sas, "sr", out var resourceScope) &&
                               string.Equals(resourceScope, "c", StringComparison.Ordinal);
        var isAccountSas = HasSasValue(sas, "ss") || HasSasValue(sas, "srt");
        if (!HasSasValue(sas, "sig") || !isContainerScope || isAccountSas ||
            (!hasStoredPolicy && (!hasPermissions || !permissions.Contains('r'))))
        {
            errors.Add("Blob SAS container scope sr=c, sig ve si=agent-read veya yalnız sp=r içermeli; account SAS ss/srt kabul edilmez.");
        }
        else if (hasPermissions && permissions.Any(static permission => permission != 'r'))
        {
            errors.Add("Agent Blob SAS yalnız 'r' okuma yetkisine sahip olmalıdır.");
        }
    }

    private static void ValidateSelectedPrinter(string id, string name, string label, List<string> errors)
    {
        if (string.IsNullOrWhiteSpace(id) && string.IsNullOrWhiteSpace(name))
        {
            return;
        }

        if (string.IsNullOrWhiteSpace(name) || name.Length > 260 || !PrinterIdentity.IsValid(id))
        {
            errors.Add($"{label} yazıcısı adı/ID eşleşmesi geçersiz.");
        }
    }

    private static void ValidateSelectedMapping(
        IReadOnlyDictionary<string, string> mappings,
        string id,
        string name,
        string label,
        List<string> errors)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            return;
        }

        if (!mappings.TryGetValue(name, out var mappedId) || !string.Equals(mappedId, id, StringComparison.Ordinal))
        {
            errors.Add($"{label} yazıcısının kalıcı ID eşlemesi bulunamadı veya seçimle uyuşmuyor.");
        }
    }

    private static (string Endpoint, string KeyName)? ValidateServiceBusConnection(
        string value,
        string label,
        string expectedEntityPath,
        string expectedKeyName,
        List<string> errors)
    {
        var parts = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var part in value.Split(';', StringSplitOptions.RemoveEmptyEntries))
        {
            var separator = part.IndexOf('=');
            if (separator <= 0)
            {
                errors.Add($"{label} malformed connection-string segment contains no key/value separator.");
                return null;
            }

            var name = part[..separator].Trim();
            if (!parts.TryAdd(name, part[(separator + 1)..].Trim()))
            {
                errors.Add($"{label} aynı anahtarı birden fazla içeremez: {name}.");
                return null;
            }
        }

        if (!parts.TryGetValue("Endpoint", out var endpoint) ||
            !Uri.TryCreate(endpoint, UriKind.Absolute, out var endpointUri) ||
            endpointUri.Scheme != "sb" ||
            endpointUri.UserInfo.Length != 0 || endpointUri.Query.Length != 0 || endpointUri.Fragment.Length != 0 ||
            endpointUri.AbsolutePath != "/" || !endpointUri.IsDefaultPort || !IsValidServiceBusHost(endpointUri.Host) ||
            !parts.TryGetValue("SharedAccessKeyName", out var keyName) ||
            !parts.TryGetValue("SharedAccessKey", out var key) || string.IsNullOrWhiteSpace(key) ||
            !parts.TryGetValue("EntityPath", out var entityPath))
        {
            errors.Add($"{label} geçerli bir Azure Service Bus SAS bağlantı dizesi olmalıdır.");
            return null;
        }

        var allowedParts = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "Endpoint", "SharedAccessKeyName", "SharedAccessKey", "EntityPath"
        };
        if (parts.Keys.Any(keyNamePart => !allowedParts.Contains(keyNamePart)))
        {
            errors.Add($"{label} bilinmeyen bağlantı dizesi alanı içeremez.");
            return null;
        }

        Span<byte> decodedKey = stackalloc byte[64];
        if (!Convert.TryFromBase64String(key, decodedKey, out var decodedLength) || decodedLength != 32)
        {
            errors.Add($"{label} SharedAccessKey geçerli 32-byte Base64 anahtar olmalıdır.");
        }

        if (!string.Equals(keyName, expectedKeyName, StringComparison.Ordinal) ||
            !string.Equals(entityPath, expectedEntityPath, StringComparison.Ordinal))
        {
            errors.Add($"{label}, EntityPath={expectedEntityPath} ve SharedAccessKeyName={expectedKeyName} kullanmalıdır.");
        }

        return (endpointUri.GetLeftPart(UriPartial.Authority).TrimEnd('/'), keyName);
    }

    private static bool IsValidServiceBusHost(string host)
    {
        const string suffix = ".servicebus.windows.net";
        if (!host.EndsWith(suffix, StringComparison.Ordinal) || host.Length <= suffix.Length)
        {
            return false;
        }

        var name = host[..^suffix.Length];
        return name.Length is >= 6 and <= 50 &&
               name[0] is >= 'a' and <= 'z' or >= '0' and <= '9' &&
               name[^1] is >= 'a' and <= 'z' or >= '0' and <= '9' &&
               name.All(static character => character is >= 'a' and <= 'z' or >= '0' and <= '9' or '-');
    }

    private static bool HasSasValue(string sas, string key) => TryGetSasValue(sas, key, out var value) && value.Length > 0;

    private static bool TryGetSasValue(string sas, string key, out string value)
    {
        foreach (var part in sas.Split('&', StringSplitOptions.RemoveEmptyEntries))
        {
            var separator = part.IndexOf('=');
            if (separator > 0 && string.Equals(Uri.UnescapeDataString(part[..separator]), key, StringComparison.OrdinalIgnoreCase))
            {
                value = Uri.UnescapeDataString(part[(separator + 1)..]);
                return true;
            }
        }

        value = string.Empty;
        return false;
    }

    private static void Require(string value, int maxLength, string label, List<string> errors)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > maxLength || value.Any(char.IsControl))
        {
            errors.Add($"{label} zorunludur ve en fazla {maxLength} karakter olabilir.");
        }
    }

    private static void Try(Action action, List<string> errors, string? prefix = null)
    {
        try
        {
            action();
        }
        catch (Exception ex) when (ex is ArgumentException or FormatException or PermanentJobException)
        {
            errors.Add(prefix is null ? ex.Message : $"{prefix}: {ex.Message}");
        }
    }
}

public static class PrinterIdentity
{
    public static string Create() => "P" + Guid.NewGuid().ToString("N")[..16].ToUpperInvariant();

    public static bool IsValid(string? value) =>
        value is { Length: 17 } && value[0] == 'P' && value[1..].All(static character =>
            character is >= '0' and <= '9' or >= 'A' and <= 'F');

    public static Dictionary<string, string> EnsureMappings(
        IReadOnlyDictionary<string, string> current,
        IEnumerable<string> printerNames)
    {
        var output = new Dictionary<string, string>(current, StringComparer.OrdinalIgnoreCase);
        foreach (var name in printerNames.Where(static name => !string.IsNullOrWhiteSpace(name)))
        {
            if (!output.TryGetValue(name, out var id) || !IsValid(id))
            {
                output[name] = Create();
            }
        }

        return output;
    }
}
