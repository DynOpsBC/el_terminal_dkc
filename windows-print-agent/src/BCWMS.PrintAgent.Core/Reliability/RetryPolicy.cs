namespace BCWMS.PrintAgent.Core.Reliability;

public enum RetryAction
{
    Abandon,
    DeadLetter
}

public static class RetryPolicy
{
    private static readonly TimeSpan[] Backoff =
    [
        TimeSpan.FromSeconds(5),
        TimeSpan.FromSeconds(15),
        TimeSpan.FromSeconds(45),
        TimeSpan.FromSeconds(120)
    ];

    public static RetryAction Decide(int deliveryCount, int maxDeliveryAttempts, bool permanentFailure)
    {
        if (deliveryCount < 1)
        {
            throw new ArgumentOutOfRangeException(nameof(deliveryCount));
        }

        if (maxDeliveryAttempts is < 1 or > 10)
        {
            throw new ArgumentOutOfRangeException(nameof(maxDeliveryAttempts));
        }

        return permanentFailure || deliveryCount >= maxDeliveryAttempts
            ? RetryAction.DeadLetter
            : RetryAction.Abandon;
    }

    public static TimeSpan GetAbandonDelay(int deliveryCount)
    {
        if (deliveryCount < 1)
        {
            throw new ArgumentOutOfRangeException(nameof(deliveryCount));
        }

        return Backoff[Math.Min(deliveryCount - 1, Backoff.Length - 1)];
    }
}
