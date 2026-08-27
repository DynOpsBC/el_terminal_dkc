using System.Security.Cryptography;

namespace BCWMS.PrintAgent.Core.Validation;

public static class HashVerifier
{
    public static async Task VerifyFileAsync(string path, string expectedLowerHex, CancellationToken cancellationToken)
    {
        await using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 81920, FileOptions.Asynchronous | FileOptions.SequentialScan);
        var hash = await SHA256.HashDataAsync(stream, cancellationToken).ConfigureAwait(false);
        var actual = Convert.ToHexString(hash).ToLowerInvariant();
        if (!CryptographicOperations.FixedTimeEquals(
                System.Text.Encoding.ASCII.GetBytes(actual),
                System.Text.Encoding.ASCII.GetBytes(expectedLowerHex.ToLowerInvariant())))
        {
            throw new PermanentJobException($"SHA-256 mismatch. Expected {expectedLowerHex}, received {actual}.");
        }
    }
}
