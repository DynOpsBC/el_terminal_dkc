namespace BCWMS.PrintAgent.Core.Validation;

public readonly record struct PdfPageGeometry(
    int OrientedWidthHundredthsInch,
    int OrientedHeightHundredthsInch,
    int PortraitWidthHundredthsInch,
    int PortraitHeightHundredthsInch,
    bool Landscape)
{
    private const double PointsPerInch = 72d;
    private const double HundredthsPerInch = 100d;
    private const double MillimetersPerInch = 25.4d;
    private const double MinimumMillimeters = 10d;
    private const double MaximumMillimeters = 2_000d;

    public static PdfPageGeometry FromPoints(double widthPoints, double heightPoints)
    {
        ValidateDimension(widthPoints, nameof(widthPoints));
        ValidateDimension(heightPoints, nameof(heightPoints));
        var width = checked((int)Math.Round(widthPoints / PointsPerInch * HundredthsPerInch, MidpointRounding.AwayFromZero));
        var height = checked((int)Math.Round(heightPoints / PointsPerInch * HundredthsPerInch, MidpointRounding.AwayFromZero));
        return new PdfPageGeometry(width, height, Math.Min(width, height), Math.Max(width, height), width > height);
    }

    private static void ValidateDimension(double points, string name)
    {
        var millimeters = points / PointsPerInch * MillimetersPerInch;
        if (!double.IsFinite(points) || millimeters is < MinimumMillimeters or > MaximumMillimeters)
        {
            throw new PermanentJobException($"PDF page {name} must be between {MinimumMillimeters:0} and {MaximumMillimeters:0} mm.");
        }
    }
}
