namespace BCWMS.PrintAgent.Core.Validation;

public static class PdfRenderBudget
{
    public static void Validate(
        IEnumerable<PdfPageGeometry> pages,
        int dpi,
        long maximumPixelsPerPage,
        long maximumTotalPixels)
    {
        ArgumentNullException.ThrowIfNull(pages);
        if (dpi <= 0 || maximumPixelsPerPage <= 0 || maximumTotalPixels <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(dpi));
        }

        long total = 0;
        foreach (var page in pages)
        {
            var width = checked((long)Math.Ceiling(page.OrientedWidthHundredthsInch / 100d * dpi));
            var height = checked((long)Math.Ceiling(page.OrientedHeightHundredthsInch / 100d * dpi));
            var pixels = checked(width * height);
            if (pixels > maximumPixelsPerPage)
            {
                throw new PermanentJobException($"PDF page render surface exceeds the {maximumPixelsPerPage:N0}-pixel safety limit at {dpi} DPI.");
            }

            total = checked(total + pixels);
            if (total > maximumTotalPixels)
            {
                throw new PermanentJobException($"PDF total render work exceeds the {maximumTotalPixels:N0}-pixel safety limit at {dpi} DPI.");
            }
        }
    }
}
