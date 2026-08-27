using System.Text.Json;
using BCWMS.PrintAgent.Core.Contracts;

namespace BCWMS.PrintAgent.Core.Reliability;

internal sealed record StatusOutboxDocument
{
    public int SchemaVersion { get; init; } = 1;
    public List<JobResultV1> Messages { get; init; } = [];
}

public sealed class FileStatusOutbox
{
    private const int MaximumEntries = 10_000;
    private readonly string _path;
    private readonly string _backupPath;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private Dictionary<string, JobResultV1>? _messages;

    public FileStatusOutbox(string path)
    {
        _path = path ?? throw new ArgumentNullException(nameof(path));
        _backupPath = path + ".bak";
    }

    public async Task EnqueueAsync(JobResultV1 message, CancellationToken cancellationToken)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await EnsureLoadedAsync(cancellationToken).ConfigureAwait(false);
            if (_messages!.Count >= MaximumEntries && !_messages.ContainsKey(message.JobId))
            {
                throw new InvalidOperationException("Status outbox reached its 10,000 message safety limit.");
            }

            // A physical-print success is monotonic. A later broker settlement
            // error must never downgrade it to failure for the same JobId.
            if (_messages.TryGetValue(message.JobId, out var existing) && existing.Success && !message.Success)
            {
                return;
            }

            var beforeMutation = new Dictionary<string, JobResultV1>(_messages, StringComparer.OrdinalIgnoreCase);
            _messages[message.JobId] = message;
            try
            {
                await PersistAsync(cancellationToken).ConfigureAwait(false);
            }
            catch
            {
                _messages = beforeMutation;
                throw;
            }
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task DrainAsync(Func<JobResultV1, CancellationToken, Task> sender, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(sender);
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await EnsureLoadedAsync(cancellationToken).ConfigureAwait(false);
            foreach (var message in _messages!.Values.OrderBy(static item => item.CompletedAtUtc).ToArray())
            {
                await sender(message, cancellationToken).ConfigureAwait(false);
                var beforeMutation = new Dictionary<string, JobResultV1>(_messages, StringComparer.OrdinalIgnoreCase);
                _messages.Remove(message.JobId);
                try
                {
                    await PersistAsync(cancellationToken).ConfigureAwait(false);
                }
                catch
                {
                    _messages = beforeMutation;
                    throw;
                }
            }
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task<int> CountAsync(CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await EnsureLoadedAsync(cancellationToken).ConfigureAwait(false);
            return _messages!.Count;
        }
        finally
        {
            _gate.Release();
        }
    }

    private async Task EnsureLoadedAsync(CancellationToken cancellationToken)
    {
        if (_messages is not null)
        {
            return;
        }

        var primaryExists = File.Exists(_path);
        var backupExists = File.Exists(_backupPath);
        StatusOutboxDocument? document;
        if (primaryExists)
        {
            document = await TryReadAsync(_path, cancellationToken).ConfigureAwait(false);
            if (document is null)
            {
                throw new InvalidDataException("Primary status outbox is unreadable; refusing to load a potentially stale backup and discard job results.");
            }
        }
        else if (backupExists)
        {
            throw new InvalidDataException("Primary status outbox is missing while a potentially stale backup exists; manual review is required before discarding job results.");
        }
        else
        {
            document = null;
        }

        document ??= new StatusOutboxDocument();
        if (document.SchemaVersion != 1)
        {
            throw new InvalidDataException($"Unsupported status outbox schema '{document.SchemaVersion}'.");
        }

        _messages = document.Messages.ToDictionary(static message => message.JobId, StringComparer.OrdinalIgnoreCase);
    }

    private static async Task<StatusOutboxDocument?> TryReadAsync(string path, CancellationToken cancellationToken)
    {
        if (!File.Exists(path))
        {
            return null;
        }

        try
        {
            await using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, FileOptions.Asynchronous | FileOptions.SequentialScan);
            return await JsonSerializer.DeserializeAsync<StatusOutboxDocument>(stream, ContractSerializer.Options, cancellationToken).ConfigureAwait(false)
                ?? throw new InvalidDataException("Status outbox contains JSON null.");
        }
        catch (Exception ex) when (ex is JsonException or IOException or UnauthorizedAccessException)
        {
            return null;
        }
    }

    private async Task PersistAsync(CancellationToken cancellationToken)
    {
        var directory = Path.GetDirectoryName(_path) ?? throw new InvalidOperationException("Status outbox path must have a parent directory.");
        Directory.CreateDirectory(directory);
        var temporary = _path + ".tmp-" + Guid.NewGuid().ToString("N");
        try
        {
            await using (var stream = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None, 4096, FileOptions.Asynchronous | FileOptions.WriteThrough))
            {
                var document = new StatusOutboxDocument { Messages = _messages!.Values.OrderBy(static item => item.CompletedAtUtc).ToList() };
                await JsonSerializer.SerializeAsync(stream, document, ContractSerializer.Options, cancellationToken).ConfigureAwait(false);
                await stream.FlushAsync(cancellationToken).ConfigureAwait(false);
                stream.Flush(flushToDisk: true);
            }

            if (File.Exists(_path))
            {
                File.Copy(_path, _backupPath, overwrite: true);
            }

            File.Move(temporary, _path, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporary))
            {
                File.Delete(temporary);
            }
        }
    }
}
