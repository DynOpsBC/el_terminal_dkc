using System.Text.Json;
using System.Text.Json.Serialization;

namespace BCWMS.PrintAgent.Core.Contracts;

public static class ContractV1
{
    public const int SchemaVersion = 1;
    public const string PrinterSnapshot = "PrinterSnapshot";
    public const string Heartbeat = "Heartbeat";
    public const string JobResult = "JobResult";
}

[JsonConverter(typeof(StrictPrintFormatJsonConverter))]
public enum PrintFormat
{
    PDF,
    ZPL,
    ESCPOS,
    RAW
}

public sealed class StrictPrintFormatJsonConverter : JsonConverter<PrintFormat>
{
    public override PrintFormat Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        if (reader.TokenType != JsonTokenType.String)
        {
            throw new JsonException("format must be one of the exact strings PDF, ZPL, ESCPOS, or RAW.");
        }

        return reader.GetString() switch
        {
            "PDF" => PrintFormat.PDF,
            "ZPL" => PrintFormat.ZPL,
            "ESCPOS" => PrintFormat.ESCPOS,
            "RAW" => PrintFormat.RAW,
            _ => throw new JsonException("format must be one of the exact strings PDF, ZPL, ESCPOS, or RAW.")
        };
    }

    public override void Write(Utf8JsonWriter writer, PrintFormat value, JsonSerializerOptions options)
    {
        if (!Enum.IsDefined(value))
        {
            throw new JsonException($"Undefined print format value '{value}'.");
        }

        writer.WriteStringValue(value.ToString());
    }
}

public sealed record PrintJobV1
{
    public required int SchemaVersion { get; init; }
    public required string JobId { get; init; }
    public required string TenantId { get; init; }
    public required string CompanyId { get; init; }
    public required string StationId { get; init; }
    public required string PrinterId { get; init; }
    public required string PrinterName { get; init; }
    public required PrintFormat Format { get; init; }
    public required int Copies { get; init; }
    public required string BlobName { get; init; }
    public required string PayloadSha256 { get; init; }
    public required long PayloadSize { get; init; }
    public required DateTimeOffset CreatedAtUtc { get; init; }
}

public abstract record StatusMessageV1
{
    public int SchemaVersion { get; init; } = ContractV1.SchemaVersion;
    public abstract string MessageType { get; }
    public required string MessageId { get; init; }
    public required string TenantId { get; init; }
    public required string CompanyId { get; init; }
    public required string StationId { get; init; }
    public required string AgentId { get; init; }
    public required DateTimeOffset SentAtUtc { get; init; }
    public required string AgentVersion { get; init; }
}

public sealed record PrinterSnapshotV1 : StatusMessageV1
{
    public override string MessageType => ContractV1.PrinterSnapshot;
    public required IReadOnlyList<PrinterSnapshotItemV1> Printers { get; init; }
    public PrinterSelectionV1? Selection { get; init; }
}

public sealed record PrinterSnapshotItemV1
{
    public required string PrinterId { get; init; }
    public required string PrinterName { get; init; }
    public required PrintFormat Format { get; init; }
    public required string Status { get; init; }
    public required bool IsDefault { get; init; }
}

public sealed record PrinterSelectionV1
{
    public required string LabelPrinterId { get; init; }
    public required string DocumentPrinterId { get; init; }
    public required string LabelTransport { get; init; }
}

public sealed record HeartbeatV1 : StatusMessageV1
{
    public override string MessageType => ContractV1.Heartbeat;
    public required string Status { get; init; }
    public string? LastJobId { get; init; }
}

public sealed record JobResultV1 : StatusMessageV1
{
    public override string MessageType => ContractV1.JobResult;
    public required string JobId { get; init; }
    public required string PrinterId { get; init; }
    public required string PrinterName { get; init; }
    public required PrintFormat Format { get; init; }
    public required bool Success { get; init; }
    public required string Message { get; init; }
    public required DateTimeOffset CompletedAtUtc { get; init; }
    public required int Attempt { get; init; }
}
