using System.Text.Json;
using System.Text.Json.Serialization;
using BCWMS.PrintAgent.Core.Validation;

namespace BCWMS.PrintAgent.Core.Contracts;

public static class ContractSerializer
{
    public static JsonSerializerOptions Options { get; } = CreateOptions();

    public static PrintJobV1 ParsePrintJob(ReadOnlyMemory<byte> utf8Json)
    {
        if (utf8Json.IsEmpty)
        {
            throw new PermanentJobException("Message body is empty.");
        }

        PrintJobV1 job;
        try
        {
            job = JsonSerializer.Deserialize<PrintJobV1>(utf8Json.Span, Options)
                ?? throw new PermanentJobException("Message body is JSON null.");
        }
        catch (JsonException ex)
        {
            throw new PermanentJobException($"PrintJob schema is invalid: {ex.Message}", ex);
        }

        PrintJobValidator.Validate(job);
        return job;
    }

    public static byte[] Serialize<T>(T value) => JsonSerializer.SerializeToUtf8Bytes(value, Options);

    private static JsonSerializerOptions CreateOptions() => new(JsonSerializerDefaults.Web)
    {
        PropertyNameCaseInsensitive = false,
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Skip,
        NumberHandling = JsonNumberHandling.Strict,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        WriteIndented = false
    };
}
