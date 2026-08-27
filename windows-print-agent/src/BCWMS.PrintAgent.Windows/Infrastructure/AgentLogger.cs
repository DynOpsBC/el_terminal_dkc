using System.Text.RegularExpressions;

namespace BCWMS.PrintAgent.Windows.Infrastructure;

internal sealed partial class AgentLogger
{
    private readonly object _gate = new();
    public event EventHandler<string>? LineWritten;

    public void Info(string message) => Write("INFO", message);
    public void Warning(string message) => Write("WARN", message);
    public void Error(string message, Exception? exception = null) =>
        Write("ERROR", exception is null ? message : $"{message}: {exception.GetType().Name}: {exception.Message}");

    private void Write(string level, string message)
    {
        var clean = Sanitize(message).Replace('\r', ' ').Replace('\n', ' ');
        var line = $"{DateTimeOffset.Now:yyyy-MM-dd HH:mm:ss.fff zzz} [{level}] {clean}";
        try
        {
            lock (_gate)
            {
                AgentPaths.EnsureCreated();
                var path = Path.Combine(AgentPaths.LogsDirectory, $"agent-{DateTime.UtcNow:yyyyMMdd}.log");
                File.AppendAllText(path, line + Environment.NewLine, System.Text.Encoding.UTF8);
                CleanupOldLogs();
            }
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }

        try { LineWritten?.Invoke(this, line); } catch (Exception) { }
    }

    private static string Sanitize(string value)
    {
        value = SharedAccessKeyRegex().Replace(value, "SharedAccessKey=***");
        value = SignatureRegex().Replace(value, "$1***");
        return value.Length <= 2000 ? value : value[..2000] + "…";
    }

    private static void CleanupOldLogs()
    {
        var cutoff = DateTime.UtcNow.AddDays(-14);
        foreach (var path in Directory.EnumerateFiles(AgentPaths.LogsDirectory, "agent-*.log"))
        {
            try
            {
                if (File.GetLastWriteTimeUtc(path) < cutoff)
                {
                    File.Delete(path);
                }
            }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }
    }

    [GeneratedRegex("SharedAccessKey=[^;\\s]+", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex SharedAccessKeyRegex();

    [GeneratedRegex("([?&](?:sig|se|sp|sv|spr)=)[^&\\s]+", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex SignatureRegex();
}
