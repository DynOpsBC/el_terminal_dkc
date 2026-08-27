namespace BCWMS.PrintAgent.Core.Reliability;

public static class WriteProgress
{
    public static void WriteAll(int totalBytes, Func<int, int, int> write, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(write);
        if (totalBytes < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(totalBytes));
        }

        var offset = 0;
        while (offset < totalBytes)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var remaining = totalBytes - offset;
            var written = write(offset, remaining);
            if (written <= 0 || written > remaining)
            {
                throw new IOException($"Writer made invalid progress ({written}/{remaining} byte).");
            }

            offset += written;
        }
    }
}
