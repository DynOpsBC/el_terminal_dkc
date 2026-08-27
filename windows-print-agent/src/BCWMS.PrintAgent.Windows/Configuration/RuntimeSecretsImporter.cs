using BCWMS.PrintAgent.Core.Configuration;

namespace BCWMS.PrintAgent.Windows.Configuration;

internal static class RuntimeSecretsImporter
{
    public static async Task<ImportedRuntimeSecrets> ImportAsync(string path, CancellationToken cancellationToken)
    {
        var file = new FileInfo(path);
        if (!file.Exists || file.Length is <= 0 or > 1024 * 1024)
        {
            throw new InvalidDataException("print-agent.runtime.secrets.json 1 byte..1 MiB arasında olmalıdır.");
        }

        var bytes = await File.ReadAllBytesAsync(path, cancellationToken).ConfigureAwait(false);
        return RuntimeSecretsParser.Parse(bytes);
    }
}
