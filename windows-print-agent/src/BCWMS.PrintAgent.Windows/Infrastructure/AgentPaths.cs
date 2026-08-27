using System.Text.RegularExpressions;

namespace BCWMS.PrintAgent.Windows.Infrastructure;

internal static partial class AgentPaths
{
    private static int _cleanupCompleted;
    public static string DataDirectory { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "DynOps",
        "BCWMS Print Agent");

    public static string ConfigPath => Path.Combine(DataDirectory, "agent.config.dpapi");
    public static string JournalPath => Path.Combine(DataDirectory, "completed-jobs.json");
    public static string StatusOutboxPath => Path.Combine(DataDirectory, "status-outbox.json");
    public static string LogsDirectory => Path.Combine(DataDirectory, "logs");
    public static string SpoolDirectory => Path.Combine(DataDirectory, "spool");

    public static void EnsureCreated()
    {
        Directory.CreateDirectory(DataDirectory);
        Directory.CreateDirectory(LogsDirectory);
        Directory.CreateDirectory(SpoolDirectory);
        if (Interlocked.Exchange(ref _cleanupCompleted, 1) == 0)
        {
            CleanupStaleSpoolFiles();
        }
    }

    private static void CleanupStaleSpoolFiles()
    {
        var cutoff = DateTime.UtcNow.AddHours(-24);
        foreach (var path in Directory.EnumerateFiles(SpoolDirectory, "*", SearchOption.TopDirectoryOnly))
        {
            try
            {
                if (SafeSpoolFileName().IsMatch(Path.GetFileName(path)) && File.GetLastWriteTimeUtc(path) < cutoff)
                {
                    File.Delete(path);
                }
            }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }
    }

    [GeneratedRegex("^(?:(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|local-test-[0-9a-f]{32})\\.(?:pdf|raw)(?:\\.part-[0-9a-f]{32})?|print-helper-[0-9a-f]{32}\\.json(?:\\.result|\\.result\\.tmp-[0-9a-f]{32})?)$", RegexOptions.CultureInvariant)]
    private static partial Regex SafeSpoolFileName();
}
