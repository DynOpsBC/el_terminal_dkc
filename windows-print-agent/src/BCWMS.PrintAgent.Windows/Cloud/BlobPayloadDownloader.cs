using System.Security.Cryptography;
using Azure;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using BCWMS.PrintAgent.Core.Configuration;
using BCWMS.PrintAgent.Core.Contracts;
using BCWMS.PrintAgent.Core.Validation;
using BCWMS.PrintAgent.Windows.Infrastructure;

namespace BCWMS.PrintAgent.Windows.Cloud;

internal sealed class BlobPayloadDownloader
{
    private readonly AgentSettings _settings;
    private readonly AgentLogger _logger;
    private readonly BlobContainerClient _container;

    public BlobPayloadDownloader(AgentSettings settings, AgentLogger logger)
    {
        _settings = settings;
        _logger = logger;
        var endpoint = settings.BlobEndpoint.TrimEnd('/');
        var sas = settings.BlobReadSas.Trim().TrimStart('?');
        var containerUri = new Uri($"{endpoint}/{CloudEntityNames.PrintJobsContainer}?{sas}");
        _container = new BlobContainerClient(containerUri, new BlobClientOptions
        {
            Retry =
            {
                Mode = Azure.Core.RetryMode.Exponential,
                MaxRetries = 3,
                Delay = TimeSpan.FromSeconds(1),
                MaxDelay = TimeSpan.FromSeconds(8),
                NetworkTimeout = TimeSpan.FromSeconds(30)
            }
        });
    }

    public async Task<string> DownloadVerifiedAsync(PrintJobV1 job, CancellationToken cancellationToken)
    {
        if (_settings.BlobSasExpiresAtUtc is not { } expiry || expiry <= DateTimeOffset.UtcNow)
        {
            throw new AgentConfigurationException("Blob read SAS is missing or expired. Import a renewed print-agent.runtime.secrets.json and restart the agent.");
        }

        if (job.PayloadSize > _settings.MaxPayloadBytes)
        {
            throw new PermanentJobException($"Payload {job.PayloadSize} byte; agent sınırı {_settings.MaxPayloadBytes} byte.");
        }

        AgentPaths.EnsureCreated();
        var extension = job.Format == PrintFormat.PDF ? ".pdf" : ".raw";
        var target = Path.Combine(AgentPaths.SpoolDirectory, job.JobId + extension);
        var temporary = target + ".part-" + Guid.NewGuid().ToString("N");
        try
        {
            var blob = _container.GetBlobClient(job.BlobName);
            Response<BlobDownloadStreamingResult> response;
            try
            {
                response = await blob.DownloadStreamingAsync(cancellationToken: cancellationToken).ConfigureAwait(false);
            }
            catch (RequestFailedException ex) when (ex.Status is 400 or 401 or 403)
            {
                throw new AgentConfigurationException($"Blob read credential was rejected ({ex.Status}, {ex.ErrorCode}); agent configuration must be renewed.", ex);
            }
            catch (RequestFailedException ex)
            {
                throw new TransientJobException($"Blob indirilemedi ({ex.Status}, {ex.ErrorCode}).", ex);
            }

            await using var input = response.Value.Content;
            await using var output = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None, 81920, FileOptions.Asynchronous | FileOptions.SequentialScan);
            using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
            var buffer = new byte[81920];
            long total = 0;
            while (true)
            {
                var read = await input.ReadAsync(buffer, cancellationToken).ConfigureAwait(false);
                if (read == 0)
                {
                    break;
                }

                total += read;
                if (total > job.PayloadSize || total > _settings.MaxPayloadBytes)
                {
                    throw new PermanentJobException("Blob, bildirilen veya izin verilen payload boyutunu aştı.");
                }

                hash.AppendData(buffer, 0, read);
                await output.WriteAsync(buffer.AsMemory(0, read), cancellationToken).ConfigureAwait(false);
            }

            await output.FlushAsync(cancellationToken).ConfigureAwait(false);
            if (total != job.PayloadSize)
            {
                throw new PermanentJobException($"Payload boyutu uyuşmuyor. Beklenen {job.PayloadSize}, gelen {total} byte.");
            }

            var actualHash = Convert.ToHexString(hash.GetHashAndReset());
            if (!CryptographicOperations.FixedTimeEquals(
                    System.Text.Encoding.ASCII.GetBytes(actualHash),
                    System.Text.Encoding.ASCII.GetBytes(job.PayloadSha256.ToUpperInvariant())))
            {
                throw new PermanentJobException($"Payload SHA-256 uyuşmuyor. Beklenen {job.PayloadSha256}, gelen {actualHash}.");
            }

            output.Close();
            if (job.Format == PrintFormat.PDF)
            {
                await VerifyPdfHeaderAsync(temporary, cancellationToken).ConfigureAwait(false);
            }

            File.Move(temporary, target, overwrite: true);
            _logger.Info($"İş {job.JobId}: {total} byte blob doğrulandı.");
            return target;
        }
        catch
        {
            DeleteIfExists(temporary);
            DeleteIfExists(target);
            throw;
        }
    }

    private static async Task VerifyPdfHeaderAsync(string path, CancellationToken cancellationToken)
    {
        var header = new byte[5];
        await using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 5, FileOptions.Asynchronous);
        try
        {
            await stream.ReadExactlyAsync(header, cancellationToken).ConfigureAwait(false);
        }
        catch (EndOfStreamException ex)
        {
            throw new PermanentJobException("PDF payload is shorter than its required header.", ex);
        }

        if (!header.AsSpan().SequenceEqual("%PDF-"u8))
        {
            throw new PermanentJobException("PDF payload geçerli %PDF- başlığı taşımıyor.");
        }
    }

    public static void DeleteIfExists(string? path)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return;
        }

        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }
}
