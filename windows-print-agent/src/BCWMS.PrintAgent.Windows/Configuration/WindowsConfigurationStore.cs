using System.Security.Cryptography;
using System.Text;
using BCWMS.PrintAgent.Core.Configuration;
using BCWMS.PrintAgent.Core.Contracts;

namespace BCWMS.PrintAgent.Windows.Configuration;

internal sealed class WindowsConfigurationStore
{
    private static readonly byte[] Magic = "BCWMSCFG1\0"u8.ToArray();
    private static readonly byte[] Entropy = SHA256.HashData(Encoding.UTF8.GetBytes("DynOps.BCWMS.PrintAgent.Settings.v1"));
    private readonly string _path;

    public WindowsConfigurationStore(string path) => _path = path;

    public async Task<AgentSettings?> LoadAsync(CancellationToken cancellationToken = default)
    {
        if (!File.Exists(_path))
        {
            return null;
        }

        var file = await File.ReadAllBytesAsync(_path, cancellationToken).ConfigureAwait(false);
        if (file.Length <= Magic.Length || !file.AsSpan(0, Magic.Length).SequenceEqual(Magic))
        {
            throw new InvalidDataException("Agent ayar dosyası başlığı geçersiz.");
        }

        byte[] clear;
        try
        {
            clear = ProtectedData.Unprotect(file[Magic.Length..], Entropy, DataProtectionScope.CurrentUser);
        }
        catch (CryptographicException ex)
        {
            throw new InvalidDataException("Ayarlar bu Windows kullanıcısı tarafından çözülemiyor. Ayarları yeniden girin.", ex);
        }

        try
        {
            return System.Text.Json.JsonSerializer.Deserialize<AgentSettings>(clear, ContractSerializer.Options)
                ?? throw new InvalidDataException("Agent ayar dosyası boş.");
        }
        catch (System.Text.Json.JsonException ex)
        {
            throw new InvalidDataException("Agent ayar dosyası şeması geçersiz.", ex);
        }
        finally
        {
            CryptographicOperations.ZeroMemory(clear);
        }
    }

    public async Task SaveAsync(AgentSettings settings, CancellationToken cancellationToken = default)
    {
        var errors = AgentSettingsValidator.Validate(settings);
        if (errors.Count > 0)
        {
            throw new ArgumentException(string.Join(Environment.NewLine, errors));
        }

        var clear = ContractSerializer.Serialize(settings);
        byte[] encrypted;
        try
        {
            encrypted = ProtectedData.Protect(clear, Entropy, DataProtectionScope.CurrentUser);
        }
        finally
        {
            CryptographicOperations.ZeroMemory(clear);
        }

        var data = new byte[Magic.Length + encrypted.Length];
        Magic.CopyTo(data, 0);
        encrypted.CopyTo(data, Magic.Length);
        CryptographicOperations.ZeroMemory(encrypted);

        var directory = Path.GetDirectoryName(_path) ?? throw new InvalidOperationException("Ayar yolu geçersiz.");
        Directory.CreateDirectory(directory);
        var temporary = _path + ".tmp-" + Guid.NewGuid().ToString("N");
        try
        {
            await using (var stream = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None, 4096, FileOptions.Asynchronous | FileOptions.WriteThrough))
            {
                await stream.WriteAsync(data, cancellationToken).ConfigureAwait(false);
                await stream.FlushAsync(cancellationToken).ConfigureAwait(false);
                stream.Flush(flushToDisk: true);
            }

            File.Move(temporary, _path, overwrite: true);
        }
        finally
        {
            CryptographicOperations.ZeroMemory(data);
            if (File.Exists(temporary))
            {
                File.Delete(temporary);
            }
        }
    }
}
