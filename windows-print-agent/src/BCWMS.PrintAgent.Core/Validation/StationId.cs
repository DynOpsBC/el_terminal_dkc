using System.Text;
using System.Text.RegularExpressions;

namespace BCWMS.PrintAgent.Core.Validation;

public static partial class StationId
{
    public static string Normalize(params string?[] segments)
    {
        var normalized = segments.Select(NormalizeSegment).ToArray();

        var value = string.Join('.', normalized);
        Validate(value);
        return value;
    }

    public static string NormalizeValue(string value) => Normalize(value.Split('.', StringSplitOptions.None));

    public static void Validate(string? value)
    {
        var segments = value?.Split('.', StringSplitOptions.None) ?? [];
        if (string.IsNullOrWhiteSpace(value) ||
            value.Length > 128 ||
            segments.Length != 4 ||
            segments.Any(static segment => segment.Length is < 1 or > 32) ||
            !CanonicalRegex().IsMatch(value))
        {
            throw new PermanentJobException("stationId must have exactly four 1..32 character segments (TENANT.COMPANY.WAREHOUSE.STATION), max 128 total, using A-Z, 0-9, underscore or hyphen.");
        }
    }

    private static string NormalizeSegment(string? input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            return string.Empty;
        }

        var decomposed = input.Trim().ToUpperInvariant().Normalize(NormalizationForm.FormD);
        var output = new StringBuilder(decomposed.Length);
        var previousSeparator = false;
        foreach (var character in decomposed)
        {
            var mapped = character is >= 'A' and <= 'Z' or >= '0' and <= '9' or '_' or '-'
                ? character
                : '-';
            if (mapped == '-' && previousSeparator)
            {
                continue;
            }

            output.Append(mapped);
            previousSeparator = mapped == '-';
        }

        return output.ToString().Trim('-');
    }

    [GeneratedRegex("^[A-Z0-9][A-Z0-9_-]*(?:\\.[A-Z0-9][A-Z0-9_-]*){3}$", RegexOptions.CultureInvariant)]
    private static partial Regex CanonicalRegex();
}
