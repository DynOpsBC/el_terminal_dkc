using System.Text.Json;
using BCWMS.PrintAgent.Core.Contracts;
using BCWMS.PrintAgent.Core.Reliability;
using Xunit;

namespace BCWMS.PrintAgent.Core.Tests;

public sealed class ReliabilityTests
{
    [Fact]
    public void RetryPolicy_AbandonsUntilBoundaryThenDeadLetters()
    {
        Assert.Equal(RetryAction.Abandon, RetryPolicy.Decide(1, 5, permanentFailure: false));
        Assert.Equal(RetryAction.Abandon, RetryPolicy.Decide(4, 5, permanentFailure: false));
        Assert.Equal(RetryAction.DeadLetter, RetryPolicy.Decide(5, 5, permanentFailure: false));
        Assert.Equal(RetryAction.DeadLetter, RetryPolicy.Decide(1, 5, permanentFailure: true));
    }

    [Fact]
    public async Task Journal_DetectsCompletedAndConflictingJobId()
    {
        var directory = NewTemporaryDirectory();
        try
        {
            var path = Path.Combine(directory, "journal.json");
            var journal = new FileJobJournal(path);
            var job = ContractTests.ValidJob();
            Assert.Equal(JournalMatch.Missing, await journal.CheckAsync(job, CancellationToken.None));
            await journal.RecordInProgressAsync(job, DateTimeOffset.UtcNow, CancellationToken.None);
            Assert.Equal(JournalMatch.InProgress, await journal.CheckAsync(job, CancellationToken.None));
            await journal.RecordCompletedAsync(job, DateTimeOffset.UtcNow, CancellationToken.None);
            Assert.Equal(JournalMatch.Completed, await journal.CheckAsync(job, CancellationToken.None));
            Assert.Equal(JournalMatch.Conflict, await journal.CheckAsync(job with { PayloadSha256 = new string('B', 64) }, CancellationToken.None));

            var reloaded = new FileJobJournal(path);
            Assert.Equal(JournalMatch.Completed, await reloaded.CheckAsync(job, CancellationToken.None));
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    [Fact]
    public async Task Journal_InProgressSurvivesRestartAndPreventsAutomaticReprint()
    {
        var directory = NewTemporaryDirectory();
        try
        {
            var path = Path.Combine(directory, "journal.json");
            var job = ContractTests.ValidJob();
            await new FileJobJournal(path).RecordInProgressAsync(job, DateTimeOffset.UtcNow, CancellationToken.None);

            var reloaded = new FileJobJournal(path);
            Assert.Equal(JournalMatch.InProgress, await reloaded.CheckAsync(job, CancellationToken.None));
            Assert.Equal(JournalMatch.Conflict, await reloaded.CheckAsync(job with { Copies = 2 }, CancellationToken.None));
            Assert.Single(await reloaded.GetInProgressAsync());
            await reloaded.MarkInProgressCompletedAsync(job.JobId, DateTimeOffset.UtcNow);
            Assert.Empty(await reloaded.GetInProgressAsync());
            Assert.Equal(JournalMatch.Completed, await reloaded.CheckAsync(job, CancellationToken.None));
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    [Fact]
    public async Task Journal_FailedIntentPersistenceRollsBackInMemoryState()
    {
        var directory = NewTemporaryDirectory();
        try
        {
            var blockedParent = Path.Combine(directory, "not-a-directory");
            await File.WriteAllTextAsync(blockedParent, "block directory creation");
            var journal = new FileJobJournal(Path.Combine(blockedParent, "journal.json"));
            var job = ContractTests.ValidJob();

            await Assert.ThrowsAnyAsync<IOException>(() =>
                journal.RecordInProgressAsync(job, DateTimeOffset.UtcNow, CancellationToken.None));
            Assert.Equal(JournalMatch.Missing, await journal.CheckAsync(job, CancellationToken.None));
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    [Fact]
    public async Task Journal_FailedOperatorReconciliationRollsBackInMemoryState()
    {
        var directory = NewTemporaryDirectory();
        var movedDirectory = directory + "-moved";
        try
        {
            var path = Path.Combine(directory, "journal.json");
            var journal = new FileJobJournal(path);
            var job = ContractTests.ValidJob();
            await journal.RecordInProgressAsync(job, DateTimeOffset.UtcNow, CancellationToken.None);

            Directory.Move(directory, movedDirectory);
            await File.WriteAllTextAsync(directory, "block directory recreation");

            await Assert.ThrowsAnyAsync<IOException>(() =>
                journal.MarkInProgressCompletedAsync(job.JobId, DateTimeOffset.UtcNow));
            Assert.Equal(JournalMatch.InProgress, await journal.CheckAsync(job, CancellationToken.None));
        }
        finally
        {
            if (File.Exists(directory))
            {
                File.Delete(directory);
            }

            if (Directory.Exists(movedDirectory))
            {
                Directory.Delete(movedDirectory, recursive: true);
            }
        }
    }

    [Fact]
    public void WriteProgress_ContinuesAcrossShortWritesAndRejectsZeroProgress()
    {
        var calls = new List<(int Offset, int Count)>();
        WriteProgress.WriteAll(10, (offset, count) =>
        {
            calls.Add((offset, count));
            return Math.Min(3, count);
        });

        Assert.Equal([(0, 10), (3, 7), (6, 4), (9, 1)], calls);
        Assert.Throws<IOException>(() => WriteProgress.WriteAll(10, static (_, _) => 0));
    }

    [Fact]
    public void RetryPolicy_UsesBoundedExponentialBackoff()
    {
        Assert.Equal(TimeSpan.FromSeconds(5), RetryPolicy.GetAbandonDelay(1));
        Assert.Equal(TimeSpan.FromSeconds(15), RetryPolicy.GetAbandonDelay(2));
        Assert.Equal(TimeSpan.FromSeconds(45), RetryPolicy.GetAbandonDelay(3));
        Assert.Equal(TimeSpan.FromSeconds(120), RetryPolicy.GetAbandonDelay(4));
        Assert.Equal(TimeSpan.FromSeconds(120), RetryPolicy.GetAbandonDelay(20));
    }

    [Fact]
    public async Task Journal_CorruptPrimaryWithoutBackup_FailsClosed()
    {
        var directory = NewTemporaryDirectory();
        try
        {
            var path = Path.Combine(directory, "journal.json");
            await File.WriteAllTextAsync(path, "{ definitely-not-json");
            var journal = new FileJobJournal(path);
            await Assert.ThrowsAsync<InvalidDataException>(() => journal.CheckAsync(ContractTests.ValidJob(), CancellationToken.None));
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    [Fact]
    public async Task Journal_MissingPrimaryNeverLoadsPotentiallyStaleBackup()
    {
        var directory = NewTemporaryDirectory();
        try
        {
            var path = Path.Combine(directory, "journal.json");
            var first = ContractTests.ValidJob();
            var secondId = "22222222-2222-3333-4444-555555555555";
            var second = first with
            {
                JobId = secondId,
                BlobName = $"jobs/{first.StationId}/{secondId}.pdf"
            };
            var journal = new FileJobJournal(path);
            await journal.RecordInProgressAsync(first, DateTimeOffset.UtcNow, CancellationToken.None);
            await journal.RecordCompletedAsync(first, DateTimeOffset.UtcNow, CancellationToken.None);
            await journal.RecordInProgressAsync(second, DateTimeOffset.UtcNow, CancellationToken.None);
            Assert.True(File.Exists(path + ".bak"));
            File.Delete(path);

            await Assert.ThrowsAsync<InvalidDataException>(() =>
                new FileJobJournal(path).CheckAsync(second, CancellationToken.None));
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    [Fact]
    public async Task Journal_CompletionAtCapacityIsNeverPruned()
    {
        var directory = NewTemporaryDirectory();
        try
        {
            var path = Path.Combine(directory, "journal.json");
            var current = ContractTests.ValidJob();
            var now = DateTimeOffset.UtcNow;
            var entries = Enumerable.Range(0, 9_999)
                .Select(_ => new JournalEntry(
                    Guid.NewGuid().ToString("D"),
                    new string('F', 64),
                    JournalState.InProgress,
                    now,
                    null))
                .Append(new JournalEntry(
                    current.JobId,
                    FileJobJournal.CreateFingerprint(current),
                    JournalState.InProgress,
                    now,
                    null))
                .ToArray();
            await File.WriteAllBytesAsync(path, ContractSerializer.Serialize(new { schemaVersion = 2, entries }));

            await new FileJobJournal(path).RecordCompletedAsync(current, now, CancellationToken.None);

            var reloaded = new FileJobJournal(path);
            Assert.Equal(JournalMatch.Completed, await reloaded.CheckAsync(current, CancellationToken.None));
            using var persisted = JsonDocument.Parse(await File.ReadAllBytesAsync(path));
            Assert.Equal(10_000, persisted.RootElement.GetProperty("entries").GetArrayLength());
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    [Fact]
    public async Task StatusOutbox_PersistsAndDeletesOnlyAfterSuccessfulSend()
    {
        var directory = NewTemporaryDirectory();
        try
        {
            var path = Path.Combine(directory, "outbox.json");
            var outbox = new FileStatusOutbox(path);
            var result = NewResult();
            await outbox.EnqueueAsync(result, CancellationToken.None);
            Assert.Equal(1, await new FileStatusOutbox(path).CountAsync());

            await Assert.ThrowsAsync<IOException>(() => outbox.DrainAsync((_, _) => throw new IOException("offline"), CancellationToken.None));
            Assert.Equal(1, await new FileStatusOutbox(path).CountAsync());

            var sent = new List<string>();
            await outbox.DrainAsync((message, _) => { sent.Add(message.JobId); return Task.CompletedTask; }, CancellationToken.None);
            Assert.Single(sent);
            Assert.Equal(0, await new FileStatusOutbox(path).CountAsync());
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    [Fact]
    public async Task StatusOutbox_NeverDowngradesAcceptedPrintToFailure()
    {
        var directory = NewTemporaryDirectory();
        try
        {
            var path = Path.Combine(directory, "outbox.json");
            var outbox = new FileStatusOutbox(path);
            var accepted = NewResult();
            await outbox.EnqueueAsync(accepted, CancellationToken.None);
            await outbox.EnqueueAsync(
                accepted with
                {
                    Success = false,
                    Message = "CompleteMessageAsync failed after spool acceptance",
                    Attempt = 5
                },
                CancellationToken.None);

            var sent = new List<JobResultV1>();
            await new FileStatusOutbox(path).DrainAsync(
                (message, _) =>
                {
                    sent.Add(message);
                    return Task.CompletedTask;
                },
                CancellationToken.None);

            var result = Assert.Single(sent);
            Assert.True(result.Success);
            Assert.Equal("accepted", result.Message);
            Assert.Equal(1, result.Attempt);
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    [Fact]
    public async Task StatusOutbox_FailedEnqueuePersistenceRollsBackInMemoryState()
    {
        var directory = NewTemporaryDirectory();
        try
        {
            var blockedParent = Path.Combine(directory, "not-a-directory");
            await File.WriteAllTextAsync(blockedParent, "block directory creation");
            var outbox = new FileStatusOutbox(Path.Combine(blockedParent, "outbox.json"));

            await Assert.ThrowsAnyAsync<IOException>(() =>
                outbox.EnqueueAsync(NewResult(), CancellationToken.None));
            Assert.Equal(0, await outbox.CountAsync());
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    [Fact]
    public async Task StatusOutbox_FailedDrainPersistenceRetainsInMemoryResult()
    {
        var directory = NewTemporaryDirectory();
        var movedDirectory = directory + "-moved";
        try
        {
            var outbox = new FileStatusOutbox(Path.Combine(directory, "outbox.json"));
            await outbox.EnqueueAsync(NewResult(), CancellationToken.None);

            Directory.Move(directory, movedDirectory);
            await File.WriteAllTextAsync(directory, "block directory recreation");
            var sendCount = 0;
            await Assert.ThrowsAnyAsync<IOException>(() => outbox.DrainAsync(
                (_, _) =>
                {
                    sendCount++;
                    return Task.CompletedTask;
                },
                CancellationToken.None));

            Assert.Equal(1, sendCount);
            Assert.Equal(1, await outbox.CountAsync());
        }
        finally
        {
            if (File.Exists(directory))
            {
                File.Delete(directory);
            }

            if (Directory.Exists(movedDirectory))
            {
                Directory.Delete(movedDirectory, recursive: true);
            }
        }
    }

    [Fact]
    public async Task StatusOutbox_CorruptPrimaryDoesNotSilentlyLoadStaleBackup()
    {
        var directory = NewTemporaryDirectory();
        try
        {
            var path = Path.Combine(directory, "outbox.json");
            var outbox = new FileStatusOutbox(path);
            await outbox.EnqueueAsync(NewResult(), CancellationToken.None);
            await outbox.EnqueueAsync(NewResult() with
            {
                JobId = "22222222-2222-3333-4444-555555555555",
                MessageId = "bbbbbbbb-bbbb-cccc-dddd-eeeeeeeeeeee"
            }, CancellationToken.None);
            Assert.True(File.Exists(path + ".bak"));
            await File.WriteAllTextAsync(path, "{ corrupt-primary");

            await Assert.ThrowsAsync<InvalidDataException>(() =>
                new FileStatusOutbox(path).CountAsync());
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    [Fact]
    public async Task StatusOutbox_MissingPrimaryNeverLoadsPotentiallyStaleBackup()
    {
        var directory = NewTemporaryDirectory();
        try
        {
            var path = Path.Combine(directory, "outbox.json");
            var outbox = new FileStatusOutbox(path);
            await outbox.EnqueueAsync(NewResult(), CancellationToken.None);
            await outbox.EnqueueAsync(NewResult() with
            {
                JobId = "22222222-2222-3333-4444-555555555555",
                MessageId = "bbbbbbbb-bbbb-cccc-dddd-eeeeeeeeeeee"
            }, CancellationToken.None);
            Assert.True(File.Exists(path + ".bak"));
            File.Delete(path);

            await Assert.ThrowsAsync<InvalidDataException>(() =>
                new FileStatusOutbox(path).CountAsync());
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    private static JobResultV1 NewResult() => new()
    {
        MessageId = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        TenantId = "CONTOSO",
        CompanyId = "CRONUS",
        StationId = "CONTOSO.CRONUS.MAIN.PACK01",
        AgentId = "11111111-2222-3333-4444-555555555555",
        SentAtUtc = DateTimeOffset.UtcNow,
        AgentVersion = "1.0.0",
        JobId = "11111111-2222-3333-4444-555555555555",
        PrinterId = "P0123456789ABCDEF",
        PrinterName = "Zebra ZD220",
        Format = PrintFormat.ZPL,
        Success = true,
        Message = "accepted",
        CompletedAtUtc = DateTimeOffset.UtcNow,
        Attempt = 1
    };

    private static string NewTemporaryDirectory()
    {
        var path = Path.Combine(Path.GetTempPath(), "bcwms-core-test-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(path);
        return path;
    }
}
