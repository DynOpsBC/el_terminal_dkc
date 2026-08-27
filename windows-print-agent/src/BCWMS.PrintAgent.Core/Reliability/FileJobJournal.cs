using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using BCWMS.PrintAgent.Core.Contracts;

namespace BCWMS.PrintAgent.Core.Reliability;

public enum JournalMatch
{
    Missing,
    InProgress,
    Completed,
    Conflict
}

public enum JournalState
{
    InProgress,
    Completed
}

public sealed record JournalEntry(
    string JobId,
    string Fingerprint,
    JournalState State,
    DateTimeOffset StartedAtUtc,
    DateTimeOffset? CompletedAtUtc);

internal sealed record JournalDocument
{
    public int SchemaVersion { get; init; } = 2;
    public List<JournalEntry> Entries { get; init; } = [];
}

public sealed class FileJobJournal
{
    private const int MaximumEntries = 10_000;
    private static readonly TimeSpan Retention = TimeSpan.FromDays(90);
    private readonly string _path;
    private readonly string _backupPath;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private Dictionary<string, JournalEntry>? _entries;

    public FileJobJournal(string path)
    {
        _path = path ?? throw new ArgumentNullException(nameof(path));
        _backupPath = path + ".bak";
    }

    public async Task<JournalMatch> CheckAsync(PrintJobV1 job, CancellationToken cancellationToken)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await EnsureLoadedAsync(cancellationToken).ConfigureAwait(false);
            if (!_entries!.TryGetValue(job.JobId, out var entry))
            {
                return JournalMatch.Missing;
            }

            if (!string.Equals(entry.Fingerprint, CreateFingerprint(job), StringComparison.Ordinal))
            {
                return JournalMatch.Conflict;
            }

            return entry.State == JournalState.Completed ? JournalMatch.Completed : JournalMatch.InProgress;
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task RecordInProgressAsync(PrintJobV1 job, DateTimeOffset startedAtUtc, CancellationToken cancellationToken)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await EnsureLoadedAsync(cancellationToken).ConfigureAwait(false);
            var fingerprint = CreateFingerprint(job);
            if (_entries!.TryGetValue(job.JobId, out var existing))
            {
                if (!string.Equals(existing.Fingerprint, fingerprint, StringComparison.Ordinal))
                {
                    throw new InvalidOperationException("JobId already exists with a different immutable fingerprint.");
                }

                return;
            }

            var beforeMutation = new Dictionary<string, JournalEntry>(_entries, StringComparer.OrdinalIgnoreCase);
            try
            {
                Prune(startedAtUtc, reserveForNewEntry: true);
                if (_entries.Count >= MaximumEntries)
                {
                    throw new InvalidOperationException("Print journal reached its 10,000 entry safety limit; unresolved intents are never pruned automatically.");
                }

                _entries[job.JobId] = new JournalEntry(job.JobId, fingerprint, JournalState.InProgress, startedAtUtc, null);
                await PersistAsync(cancellationToken).ConfigureAwait(false);
            }
            catch
            {
                _entries = beforeMutation;
                throw;
            }
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task RecordCompletedAsync(PrintJobV1 job, DateTimeOffset completedAtUtc, CancellationToken cancellationToken)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await EnsureLoadedAsync(cancellationToken).ConfigureAwait(false);
            var fingerprint = CreateFingerprint(job);
            if (!_entries!.TryGetValue(job.JobId, out var existing) ||
                !string.Equals(existing.Fingerprint, fingerprint, StringComparison.Ordinal))
            {
                throw new InvalidOperationException("A matching durable InProgress intent is required before recording print completion.");
            }

            if (existing.State == JournalState.Completed)
            {
                return;
            }

            var beforeMutation = new Dictionary<string, JournalEntry>(_entries, StringComparer.OrdinalIgnoreCase);
            _entries[job.JobId] = existing with { State = JournalState.Completed, CompletedAtUtc = completedAtUtc };
            Prune(completedAtUtc, reserveForNewEntry: false);
            try
            {
                await PersistAsync(cancellationToken).ConfigureAwait(false);
            }
            catch
            {
                _entries = beforeMutation;
                throw;
            }
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task<IReadOnlyList<JournalEntry>> GetInProgressAsync(CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await EnsureLoadedAsync(cancellationToken).ConfigureAwait(false);
            return _entries!.Values
                .Where(static entry => entry.State == JournalState.InProgress)
                .OrderBy(static entry => entry.StartedAtUtc)
                .ToArray();
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task MarkInProgressCompletedAsync(string jobId, DateTimeOffset completedAtUtc, CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await EnsureLoadedAsync(cancellationToken).ConfigureAwait(false);
            if (!_entries!.TryGetValue(jobId, out var entry) || entry.State != JournalState.InProgress)
            {
                throw new InvalidOperationException("The selected JobId is not an unresolved InProgress print intent.");
            }

            var beforeMutation = new Dictionary<string, JournalEntry>(_entries, StringComparer.OrdinalIgnoreCase);
            _entries[jobId] = entry with { State = JournalState.Completed, CompletedAtUtc = completedAtUtc };
            try
            {
                await PersistAsync(cancellationToken).ConfigureAwait(false);
            }
            catch
            {
                _entries = beforeMutation;
                throw;
            }
        }
        finally
        {
            _gate.Release();
        }
    }

    public static string CreateFingerprint(PrintJobV1 job)
    {
        var canonical = string.Join('\n',
            job.JobId,
            job.TenantId,
            job.CompanyId,
            job.StationId,
            job.PrinterId,
            job.PrinterName.ToUpperInvariant(),
            job.Format.ToString(),
            job.Copies.ToString(CultureInfo.InvariantCulture),
            job.BlobName,
            job.PayloadSha256.ToUpperInvariant(),
            job.PayloadSize.ToString(CultureInfo.InvariantCulture),
            job.CreatedAtUtc.ToUniversalTime().ToString("O", CultureInfo.InvariantCulture));
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonical)));
    }

    private async Task EnsureLoadedAsync(CancellationToken cancellationToken)
    {
        if (_entries is not null)
        {
            return;
        }

        var primaryExists = File.Exists(_path);
        var backupExists = File.Exists(_backupPath);
        JournalDocument? document;
        if (primaryExists)
        {
            document = await TryReadAsync(_path, cancellationToken).ConfigureAwait(false);
            if (document is null)
            {
                throw new InvalidDataException("Primary print journal is unreadable; refusing to use a potentially stale backup or print duplicates.");
            }
        }
        else if (backupExists)
        {
            throw new InvalidDataException("Primary print journal is missing while a potentially stale backup exists; manual review is required before printing.");
        }
        else
        {
            document = null;
        }

        document ??= new JournalDocument();
        if (document.SchemaVersion != 2)
        {
            throw new InvalidDataException($"Unsupported print journal schema '{document.SchemaVersion}'. Manual review is required before migration.");
        }

        try
        {
            _entries = document.Entries.ToDictionary(static entry => entry.JobId, StringComparer.OrdinalIgnoreCase);
        }
        catch (ArgumentException ex)
        {
            throw new InvalidDataException("Print journal contains duplicate JobId entries.", ex);
        }
    }

    private static async Task<JournalDocument?> TryReadAsync(string path, CancellationToken cancellationToken)
    {
        if (!File.Exists(path))
        {
            return null;
        }

        try
        {
            await using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, FileOptions.Asynchronous | FileOptions.SequentialScan);
            return await JsonSerializer.DeserializeAsync<JournalDocument>(stream, ContractSerializer.Options, cancellationToken).ConfigureAwait(false)
                ?? throw new InvalidDataException("Print journal contains JSON null.");
        }
        catch (Exception ex) when (ex is JsonException or IOException or UnauthorizedAccessException)
        {
            return null;
        }
    }

    private void Prune(DateTimeOffset now, bool reserveForNewEntry)
    {
        var entries = _entries ?? throw new InvalidOperationException("Print journal is not loaded.");
        var cutoff = now - Retention;
        foreach (var key in entries.Where(pair =>
                         pair.Value.State == JournalState.Completed && pair.Value.CompletedAtUtc < cutoff)
                     .Select(static pair => pair.Key)
                     .ToArray())
        {
            entries.Remove(key);
        }

        var maximumExistingEntries = reserveForNewEntry ? MaximumEntries - 1 : MaximumEntries;
        var completedToRemove = Math.Max(0, entries.Count - maximumExistingEntries);
        foreach (var key in entries.Values
                     .Where(static entry => entry.State == JournalState.Completed)
                     .OrderBy(static entry => entry.CompletedAtUtc)
                     .Take(completedToRemove)
                     .Select(static entry => entry.JobId)
                     .ToArray())
        {
            entries.Remove(key);
        }
    }

    private async Task PersistAsync(CancellationToken cancellationToken)
    {
        var directory = Path.GetDirectoryName(_path);
        if (string.IsNullOrWhiteSpace(directory))
        {
            throw new InvalidOperationException("Print journal path must have a parent directory.");
        }

        Directory.CreateDirectory(directory);
        var temporaryPath = _path + ".tmp-" + Guid.NewGuid().ToString("N");
        try
        {
            await using (var stream = new FileStream(temporaryPath, FileMode.CreateNew, FileAccess.Write, FileShare.None, 4096, FileOptions.Asynchronous | FileOptions.WriteThrough))
            {
                var document = new JournalDocument { Entries = _entries!.Values.OrderBy(static entry => entry.StartedAtUtc).ToList() };
                await JsonSerializer.SerializeAsync(stream, document, ContractSerializer.Options, cancellationToken).ConfigureAwait(false);
                await stream.FlushAsync(cancellationToken).ConfigureAwait(false);
                stream.Flush(flushToDisk: true);
            }

            if (File.Exists(_path))
            {
                File.Copy(_path, _backupPath, overwrite: true);
            }

            File.Move(temporaryPath, _path, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporaryPath))
            {
                File.Delete(temporaryPath);
            }
        }
    }
}
