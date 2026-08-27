namespace BCWMS.PrintAgent.Windows.App;

internal sealed record PrinterChoice(string Name, string Status, bool IsDefault)
{
    public override string ToString() => $"{Name} — {Status}{(IsDefault ? " (Varsayılan)" : string.Empty)}";
}
