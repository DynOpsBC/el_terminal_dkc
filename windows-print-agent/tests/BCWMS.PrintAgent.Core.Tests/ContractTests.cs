using System.Text;
using System.Text.Json;
using BCWMS.PrintAgent.Core.Contracts;
using BCWMS.PrintAgent.Core.Validation;
using Xunit;

namespace BCWMS.PrintAgent.Core.Tests;

public sealed class ContractTests
{
    [Fact]
    public void PrintJobV1_GoldenJson_RoundTripsEscPosAndIgnoresFutureField()
    {
        var now = DateTimeOffset.UtcNow;
        var json = $$"""
        {
          "schemaVersion": 1,
          "jobId": "11111111-2222-3333-4444-555555555555",
          "tenantId": "CONTOSO",
          "companyId": "CRONUS",
          "stationId": "CONTOSO.CRONUS.MAIN.PACK01",
          "printerId": "P0123456789ABCDEF",
          "printerName": "EPSON TM-T20III",
          "format": "ESCPOS",
          "copies": 2,
          "blobName": "jobs/CONTOSO.CRONUS.MAIN.PACK01/11111111-2222-3333-4444-555555555555.escpos",
          "payloadSha256": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
          "payloadSize": 42,
          "createdAtUtc": "{{now:O}}",
          "futureCompatibleField": "ignored-in-v1"
        }
        """;

        var job = ContractSerializer.ParsePrintJob(Encoding.UTF8.GetBytes(json));

        Assert.Equal(PrintFormat.ESCPOS, job.Format);
        Assert.Equal(2, job.Copies);
        Assert.Equal("P0123456789ABCDEF", job.PrinterId);
        using var serialized = JsonDocument.Parse(ContractSerializer.Serialize(job));
        Assert.Equal(1, serialized.RootElement.GetProperty("schemaVersion").GetInt32());
        Assert.Equal("ESCPOS", serialized.RootElement.GetProperty("format").GetString());
        Assert.False(serialized.RootElement.TryGetProperty("messageType", out _));
    }

    [Theory]
    [InlineData("CONTOSO.CRONUS.MAIN")]
    [InlineData("CONTOSO..MAIN.PACK01")]
    [InlineData("contoso.CRONUS.MAIN.PACK01")]
    [InlineData("CONTOSO.CRONUS.MAIN.PACK01.EXTRA")]
    public void StationId_RejectsNonCanonicalFourSegmentValues(string value) =>
        Assert.Throws<PermanentJobException>(() => StationId.Validate(value));

    [Fact]
    public void StationId_RejectsSegmentLongerThan32()
    {
        var value = $"CONTOSO.CRONUS.{new string('A', 33)}.PACK01";
        Assert.Throws<PermanentJobException>(() => StationId.Validate(value));
    }

    [Fact]
    public void BlobName_MustMatchStationJobAndFormatExactly()
    {
        var valid = ValidJob() with { BlobName = "jobs/OTHER.CRONUS.MAIN.PACK01/11111111-2222-3333-4444-555555555555.pdf" };
        Assert.Throws<PermanentJobException>(() => PrintJobValidator.Validate(valid));

        var traversal = ValidJob() with { BlobName = "jobs/CONTOSO.CRONUS.MAIN.PACK01/../11111111-2222-3333-4444-555555555555.pdf" };
        Assert.Throws<PermanentJobException>(() => PrintJobValidator.Validate(traversal));
    }

    [Fact]
    public void PrintFormat_RejectsNumericAndNonCanonicalStrings()
    {
        var json = Encoding.UTF8.GetString(ContractSerializer.Serialize(ValidJob()));
        Assert.Throws<PermanentJobException>(() => ContractSerializer.ParsePrintJob(Encoding.UTF8.GetBytes(json.Replace("\"PDF\"", "0", StringComparison.Ordinal))));
        Assert.Throws<PermanentJobException>(() => ContractSerializer.ParsePrintJob(Encoding.UTF8.GetBytes(json.Replace("\"PDF\"", "\"pdf\"", StringComparison.Ordinal))));
    }

    [Fact]
    public void PayloadHash_RequiresCanonicalUppercaseHex() =>
        Assert.Throws<PermanentJobException>(() => PrintJobValidator.Validate(ValidJob() with { PayloadSha256 = new string('a', 64) }));

    [Fact]
    public void PayloadHash_NullIsAPermanentContractFailure()
    {
        var json = Encoding.UTF8.GetString(ContractSerializer.Serialize(ValidJob()));
        var withNullHash = json.Replace($"\"{new string('A', 64)}\"", "null", StringComparison.Ordinal);

        var error = Assert.Throws<PermanentJobException>(() =>
            ContractSerializer.ParsePrintJob(Encoding.UTF8.GetBytes(withNullHash)));

        Assert.Contains("payloadSha256", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void PrintWorkerProtocol_RoundTripsAndHasHardTimeouts()
    {
        var request = new PrintWorkerRequest
        {
            Mode = PrintWorkerMode.Print,
            PayloadPath = @"C:\\spool\\job.raw",
            PrinterName = "Zebra ZD220",
            DocumentName = "BCWMS-test",
            Format = PrintFormat.ZPL,
            Copies = 2
        };
        PrintWorkerPolicy.Validate(request);
        var roundTrip = JsonSerializer.Deserialize<PrintWorkerRequest>(ContractSerializer.Serialize(request), ContractSerializer.Options);
        Assert.Equal(request, roundTrip);
        Assert.Equal(TimeSpan.FromSeconds(60), PrintWorkerPolicy.PdfValidationTimeout);
        Assert.Equal(TimeSpan.FromMinutes(30), PrintWorkerPolicy.PhysicalPrintTimeout);
    }

    [Fact]
    public async Task HashVerifier_RejectsMismatch()
    {
        var directory = Path.Combine(Path.GetTempPath(), "bcwms-hash-test-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        var path = Path.Combine(directory, "payload.bin");
        try
        {
            await File.WriteAllBytesAsync(path, "hello"u8.ToArray());
            await Assert.ThrowsAsync<PermanentJobException>(() => HashVerifier.VerifyFileAsync(path, new string('0', 64), CancellationToken.None));
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    internal static PrintJobV1 ValidJob() => new()
    {
        SchemaVersion = 1,
        JobId = "11111111-2222-3333-4444-555555555555",
        TenantId = "CONTOSO",
        CompanyId = "CRONUS",
        StationId = "CONTOSO.CRONUS.MAIN.PACK01",
        PrinterId = "P0123456789ABCDEF",
        PrinterName = "Microsoft Print to PDF",
        Format = PrintFormat.PDF,
        Copies = 1,
        BlobName = "jobs/CONTOSO.CRONUS.MAIN.PACK01/11111111-2222-3333-4444-555555555555.pdf",
        PayloadSha256 = new string('A', 64),
        PayloadSize = 123,
        CreatedAtUtc = DateTimeOffset.UtcNow
    };
}
