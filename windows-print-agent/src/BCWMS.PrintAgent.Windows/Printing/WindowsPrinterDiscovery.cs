using System.Drawing.Printing;
using System.Management;

namespace BCWMS.PrintAgent.Windows.Printing;

internal sealed record DiscoveredPrinter(string Name, string Status, bool IsDefault, bool IsOffline);

internal sealed class WindowsPrinterDiscovery
{
    public async Task<IReadOnlyList<DiscoveredPrinter>> DiscoverAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            return await IsolatedPrintWorker.DiscoverPrintersAsync(cancellationToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception)
        {
            // Snapshot publication must not stop queue consumption because WMI
            // or a third-party printer driver is unhealthy. Selected mappings
            // are still emitted as Offline and the next refresh retries.
            return [];
        }
    }

    internal static IReadOnlyList<DiscoveredPrinter> DiscoverInProcess(CancellationToken cancellationToken)
    {
        var defaultName = new PrinterSettings().PrinterName;
        var statuses = GetWmiStatuses();
        var result = new List<DiscoveredPrinter>();
        foreach (string name in PrinterSettings.InstalledPrinters)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var status = statuses.TryGetValue(name, out var item)
                ? item
                : (Status: "Installed", IsOffline: false);
            result.Add(new DiscoveredPrinter(
                name,
                status.Status,
                string.Equals(name, defaultName, StringComparison.OrdinalIgnoreCase),
                status.IsOffline));
        }

        return result.OrderBy(static printer => printer.Name, StringComparer.CurrentCultureIgnoreCase).ToArray();
    }

    private static Dictionary<string, (string Status, bool IsOffline)> GetWmiStatuses()
    {
        var output = new Dictionary<string, (string, bool)>(StringComparer.OrdinalIgnoreCase);
        try
        {
            using var searcher = new ManagementObjectSearcher("SELECT Name, WorkOffline, PrinterStatus FROM Win32_Printer");
            searcher.Options.Timeout = TimeSpan.FromSeconds(5);
            using var collection = searcher.Get();
            foreach (ManagementObject printer in collection)
            {
                using (printer)
                {
                    var name = printer["Name"]?.ToString();
                    if (string.IsNullOrWhiteSpace(name))
                    {
                        continue;
                    }

                    var offline = printer["WorkOffline"] is bool value && value;
                    var code = Convert.ToUInt16(printer["PrinterStatus"] ?? (ushort)0, System.Globalization.CultureInfo.InvariantCulture);
                    var status = offline
                        ? "Offline"
                        : code switch
                        {
                            3 => "Online",
                            4 => "Printing",
                            5 => "Warmup",
                            6 => "Stopped",
                            7 => "Offline",
                            _ => "Unknown"
                        };
                    output[name] = (status, offline || code is 6 or 7);
                }
            }
        }
        catch (ManagementException) { }
        catch (UnauthorizedAccessException) { }

        return output;
    }
}
