using BCWMS.PrintAgent.Core.Configuration;
using BCWMS.PrintAgent.Core.Contracts;
using BCWMS.PrintAgent.Core.Validation;
using System.Text;
using Xunit;

namespace BCWMS.PrintAgent.Core.Tests;

public sealed class ConfigurationTests
{
    private const string Key = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

    [Fact]
    public void StoredPolicyReadSas_IsAccepted()
    {
        var settings = ValidSettings() with { BlobReadSas = "sv=2023-11-03&sr=c&si=agent-read&sig=abc" };
        Assert.Empty(AgentSettingsValidator.Validate(settings));
    }

    [Fact]
    public void WriteCapableSas_IsRejected()
    {
        var settings = ValidSettings() with { BlobReadSas = "sv=2023-11-03&sr=c&sp=rw&sig=abc" };
        Assert.Contains(AgentSettingsValidator.Validate(settings), error => error.Contains("yalnız 'r'", StringComparison.Ordinal));
    }

    [Fact]
    public void ReadOnlyAccountSas_IsRejected()
    {
        var settings = ValidSettings() with { BlobReadSas = "sv=2023-11-03&ss=b&srt=sco&sp=r&sig=abc" };
        Assert.Contains(AgentSettingsValidator.Validate(settings), error => error.Contains("account SAS", StringComparison.Ordinal));
    }

    [Theory]
    [InlineData("P0123456789ABCDEF", true)]
    [InlineData("P0123456789ABCDE", false)]
    [InlineData("p0123456789ABCDEF", false)]
    [InlineData("P0123456789ABCDEG", false)]
    public void PrinterIdentity_HonorsBcCode20SafeShape(string value, bool expected) =>
        Assert.Equal(expected, PrinterIdentity.IsValid(value));

    [Fact]
    public void ServiceBusPolicyAndEntityMustBeExact()
    {
        var wrong = ValidSettings() with
        {
            JobsListenConnectionString = $"Endpoint=sb://bcwms01.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey={Key};EntityPath=print-jobs-queue"
        };
        Assert.Contains(AgentSettingsValidator.Validate(wrong), error => error.Contains("agent-listen-jobs", StringComparison.Ordinal));
    }

    [Fact]
    public void Routing_RejectsLabelFormatDifferentFromConfiguredFormat()
    {
        var settings = ValidSettings() with { LabelFormat = PrintFormat.ZPL };
        var job = ContractTests.ValidJob() with
        {
            Format = PrintFormat.ESCPOS,
            PrinterName = settings.LabelPrinterName,
            PrinterId = settings.LabelPrinterId,
            BlobName = "jobs/CONTOSO.CRONUS.MAIN.PACK01/11111111-2222-3333-4444-555555555555.escpos"
        };

        Assert.Throws<PermanentJobException>(() => JobRoutingPolicy.Validate(job, settings));
    }

    [Theory]
    [InlineData(283.4645669, 425.1968504, 394, 591, false)] // 100 x 150 mm
    [InlineData(595.2755906, 841.8897638, 827, 1169, false)] // A4
    [InlineData(841.8897638, 595.2755906, 1169, 827, true)]  // A4 landscape
    public void PdfGeometry_PropagatesMediaBoxSize(
        double widthPoints,
        double heightPoints,
        int expectedOrientedWidth,
        int expectedOrientedHeight,
        bool expectedLandscape)
    {
        var geometry = PdfPageGeometry.FromPoints(widthPoints, heightPoints);
        Assert.Equal(expectedOrientedWidth, geometry.OrientedWidthHundredthsInch);
        Assert.Equal(expectedOrientedHeight, geometry.OrientedHeightHundredthsInch);
        Assert.Equal(expectedLandscape, geometry.Landscape);
    }

    [Fact]
    public void PdfRenderBudget_RejectsOversizedPageAndTotalWork()
    {
        var a4 = PdfPageGeometry.FromPoints(595.2755906, 841.8897638);
        var huge = PdfPageGeometry.FromPoints(2_000, 2_000);
        Assert.Throws<PermanentJobException>(() => PdfRenderBudget.Validate([huge], 300, 25_000_000, 500_000_000));
        Assert.Throws<PermanentJobException>(() => PdfRenderBudget.Validate(Enumerable.Repeat(a4, 60), 300, 25_000_000, 500_000_000));
        PdfRenderBudget.Validate([a4], 300, 25_000_000, 500_000_000);
    }

    [Fact]
    public void ServiceBusEndpoint_CustomPortIsRejected()
    {
        var settings = ValidSettings() with
        {
            JobsListenConnectionString = $"Endpoint=sb://bcwms01.servicebus.windows.net:123/;SharedAccessKeyName=agent-listen-jobs;SharedAccessKey={Key};EntityPath=print-jobs-queue"
        };
        Assert.NotEmpty(AgentSettingsValidator.Validate(settings));
    }

    [Fact]
    public void RuntimeSecrets_AgentOnlyDocumentIsAccepted()
    {
        var imported = RuntimeSecretsParser.Parse(Encoding.UTF8.GetBytes(ValidRuntimeSecretsJson()));

        Assert.Equal("CONTOSO.CRONUS.MAIN.PACK01", imported.StationId);
        Assert.Equal("CONTOSO", imported.TenantId);
        Assert.Equal("CRONUS", imported.CompanyId);
        Assert.Equal("bcwmsprint01", imported.StorageAccount);
        Assert.Equal("https://bcwmsprint01.blob.core.windows.net", imported.BlobEndpoint);
    }

    [Fact]
    public void RuntimeSecrets_CombinedBcCredentialDocumentIsRejected()
    {
        var combined = ValidRuntimeSecretsJson().Replace(
            "\"agent\":",
            "\"businessCentral\":{\"printJobsSendConnectionString\":\"secret\"},\"agent\":",
            StringComparison.Ordinal);

        var exception = Assert.Throws<InvalidDataException>(() =>
            RuntimeSecretsParser.Parse(Encoding.UTF8.GetBytes(combined)));
        Assert.Contains("BC credential", exception.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void RuntimeSecrets_InvalidStationIsReportedAsInvalidData()
    {
        var invalid = ValidRuntimeSecretsJson().Replace(
            "CONTOSO.CRONUS.MAIN.PACK01",
            "CONTOSO.CRONUS.ONLYTHREE",
            StringComparison.Ordinal);

        var exception = Assert.Throws<InvalidDataException>(() =>
            RuntimeSecretsParser.Parse(Encoding.UTF8.GetBytes(invalid)));
        Assert.Contains("stationId", exception.Message, StringComparison.Ordinal);
    }

    private static string ValidRuntimeSecretsJson() => $$"""
        {
          "schemaVersion": 1,
          "generatedAtUtc": "{{DateTimeOffset.UtcNow:O}}",
          "blobSasExpiresAtUtc": "{{DateTimeOffset.UtcNow.AddDays(7):O}}",
          "stationId": "CONTOSO.CRONUS.MAIN.PACK01",
          "routing": {
            "deploymentScope": "single-bc-environment-company",
            "tenantId": "CONTOSO",
            "companyId": "CRONUS",
            "warehouseId": "MAIN",
            "stationCode": "PACK01"
          },
          "agent": {
            "printJobsListenConnectionString": "jobs-secret",
            "printerStatusSendConnectionString": "status-secret",
            "blobAccountName": "bcwmsprint01",
            "blobContainerName": "print-jobs",
            "blobReadSasToken": "sv=2023-11-03&sr=c&si=agent-read&sig=abc"
          }
        }
        """;

    private static AgentSettings ValidSettings() => new()
    {
        AgentId = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        TenantId = "CONTOSO",
        CompanyId = "CRONUS",
        StationId = "CONTOSO.CRONUS.MAIN.PACK01",
        JobsListenConnectionString = $"Endpoint=sb://bcwms01.servicebus.windows.net/;SharedAccessKeyName=agent-listen-jobs;SharedAccessKey={Key};EntityPath=print-jobs-queue",
        StatusSendConnectionString = $"Endpoint=sb://bcwms01.servicebus.windows.net/;SharedAccessKeyName=agent-send-status;SharedAccessKey={Key};EntityPath=printer-status-queue",
        StorageAccount = "bcwmsprint01",
        BlobEndpoint = "https://bcwmsprint01.blob.core.windows.net",
        BlobReadSas = "sv=2023-11-03&sr=c&si=agent-read&sig=abc",
        BlobSasExpiresAtUtc = DateTimeOffset.UtcNow.AddDays(7),
        LabelPrinterId = "P0123456789ABCDEF",
        LabelPrinterName = "Zebra ZD220",
        PrinterIdsByName = new Dictionary<string, string> { ["Zebra ZD220"] = "P0123456789ABCDEF" }
    };
}
