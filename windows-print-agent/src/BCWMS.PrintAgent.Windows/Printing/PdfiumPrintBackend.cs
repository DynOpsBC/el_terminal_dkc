using System.Drawing;
using System.Drawing.Printing;
using System.Runtime.InteropServices;
using BCWMS.PrintAgent.Core.Validation;
using PdfiumViewer;

namespace BCWMS.PrintAgent.Windows.Printing;

internal static class PdfiumPrintBackend
{
    private const int MaximumPageCount = 200;
    private const int RenderDpi = 300;
    private const long MaximumRenderPixelsPerPage = 25_000_000;
    private const long MaximumTotalRenderPixels = 500_000_000;

    public static Task ValidateAsync(string pdfPath, CancellationToken cancellationToken) =>
        Task.Run(() =>
        {
            try
            {
                cancellationToken.ThrowIfCancellationRequested();
                using var document = PdfDocument.Load(pdfPath);
                _ = ValidateDocument(document);
            }
            catch (PermanentJobException)
            {
                throw;
            }
            catch (Exception ex) when (ex is DllNotFoundException or EntryPointNotFoundException or BadImageFormatException)
            {
                throw new PermanentJobException("Pdfium native x64 bileşeni yüklenemedi; kurulum paketini onarın.", ex);
            }
            catch (Exception ex) when (string.Equals(ex.GetType().Namespace, "PdfiumViewer", StringComparison.Ordinal))
            {
                throw new PermanentJobException($"PDF dosyası Pdfium tarafından açılamadı: {ex.Message}", ex);
            }
        }, cancellationToken);

    public static Task PrintAsync(string printerName, string documentName, string pdfPath, int copies, CancellationToken cancellationToken) =>
        Task.Run(() => Print(printerName, documentName, pdfPath, copies, cancellationToken), cancellationToken);

    private static void Print(string printerName, string documentName, string pdfPath, int copies, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var settings = new PrinterSettings { PrinterName = printerName, Copies = checked((short)copies) };
        if (!settings.IsValid)
        {
            throw new PermanentJobException($"Windows belge yazıcısı bulunamadı: {printerName}.");
        }

        try
        {
            using var document = PdfDocument.Load(pdfPath);
            var geometries = ValidateDocument(document);
            using var printDocument = new MediaBoxPrintDocument(document, geometries, cancellationToken)
            {
                DocumentName = documentName,
                PrinterSettings = settings,
                PrintController = new StandardPrintController()
            };
            printDocument.Print();
        }
        catch (PermanentJobException)
        {
            throw;
        }
        catch (InvalidPrinterException ex)
        {
            throw new PermanentJobException($"PDF yazıcısı geçersiz: {printerName}.", ex);
        }
        catch (Exception ex) when (ex is DllNotFoundException or EntryPointNotFoundException or BadImageFormatException)
        {
            throw new PermanentJobException("Pdfium native x64 bileşeni yüklenemedi; kurulum paketini onarın.", ex);
        }
        catch (Exception ex) when (string.Equals(ex.GetType().Namespace, "PdfiumViewer", StringComparison.Ordinal))
        {
            throw new PermanentJobException($"PDF dosyası Pdfium tarafından açılamadı: {ex.Message}", ex);
        }
        catch (Exception ex) when (ex is InvalidOperationException or ExternalException or IOException)
        {
            throw new TransientJobException($"PDF Windows kuyruğuna kabul edilmedi: {ex.Message}", ex);
        }
    }

    private static PdfPageGeometry[] ValidateDocument(PdfDocument document)
    {
        if (document.PageCount is < 1 or > MaximumPageCount)
        {
            throw new PermanentJobException($"PDF sayfa sayısı 1..{MaximumPageCount} arasında olmalıdır.");
        }

        var geometries = document.PageSizes
            .Select(static size => PdfPageGeometry.FromPoints(size.Width, size.Height))
            .ToArray();
        PdfRenderBudget.Validate(geometries, RenderDpi, MaximumRenderPixelsPerPage, MaximumTotalRenderPixels);

        return geometries;
    }

    private sealed class MediaBoxPrintDocument : PrintDocument
    {
        private const int PaperToleranceHundredthsInch = 4;
        private readonly PdfDocument _document;
        private readonly IReadOnlyList<PdfPageGeometry> _pages;
        private readonly CancellationToken _cancellationToken;
        private int _currentPage;

        public MediaBoxPrintDocument(
            PdfDocument document,
            IReadOnlyList<PdfPageGeometry> pages,
            CancellationToken cancellationToken)
        {
            _document = document;
            _pages = pages;
            _cancellationToken = cancellationToken;
            OriginAtMargins = false;
        }

        protected override void OnBeginPrint(PrintEventArgs e)
        {
            _currentPage = 0;
            base.OnBeginPrint(e);
        }

        protected override void OnQueryPageSettings(QueryPageSettingsEventArgs e)
        {
            _cancellationToken.ThrowIfCancellationRequested();
            if (_currentPage >= _pages.Count)
            {
                base.OnQueryPageSettings(e);
                return;
            }

            var page = _pages[_currentPage];
            e.PageSettings.PaperSize = ResolvePaperSize(PrinterSettings, page);
            e.PageSettings.Landscape = page.Landscape;
            e.PageSettings.Margins = new Margins(0, 0, 0, 0);
            base.OnQueryPageSettings(e);
        }

        protected override void OnPrintPage(PrintPageEventArgs e)
        {
            _cancellationToken.ThrowIfCancellationRequested();
            var page = _pages[_currentPage];
            if (Math.Abs(e.PageBounds.Width - page.OrientedWidthHundredthsInch) > PaperToleranceHundredthsInch ||
                Math.Abs(e.PageBounds.Height - page.OrientedHeightHundredthsInch) > PaperToleranceHundredthsInch)
            {
                throw new PermanentJobException(
                    $"Yazıcı PDF MediaBox boyutunu kabul etmedi. İstenen {page.OrientedWidthHundredthsInch / 100d:0.00}x{page.OrientedHeightHundredthsInch / 100d:0.00} inç, " +
                    $"sürücü {e.PageBounds.Width / 100d:0.00}x{e.PageBounds.Height / 100d:0.00} inç döndürdü. Yazıcı sürücüsünde bu kağıt boyutunu tanımlayın.");
            }

            var pixelWidth = checked((int)Math.Ceiling(page.OrientedWidthHundredthsInch / 100d * RenderDpi));
            var pixelHeight = checked((int)Math.Ceiling(page.OrientedHeightHundredthsInch / 100d * RenderDpi));
            using var image = _document.Render(
                _currentPage,
                pixelWidth,
                pixelHeight,
                RenderDpi,
                RenderDpi,
                PdfRenderFlags.ForPrinting | PdfRenderFlags.Annotations);

            var graphics = e.Graphics ?? throw new TransientJobException("Windows print controller did not provide a Graphics surface.");
            var previousUnit = graphics.PageUnit;
            try
            {
                graphics.PageUnit = GraphicsUnit.Display;
                graphics.DrawImage(
                    image,
                    new RectangleF(
                        -e.PageSettings.HardMarginX,
                        -e.PageSettings.HardMarginY,
                        page.OrientedWidthHundredthsInch,
                        page.OrientedHeightHundredthsInch));
            }
            finally
            {
                graphics.PageUnit = previousUnit;
            }

            _currentPage++;
            e.HasMorePages = _currentPage < _pages.Count;
            base.OnPrintPage(e);
        }

        private static PaperSize ResolvePaperSize(PrinterSettings settings, PdfPageGeometry page)
        {
            foreach (PaperSize supported in settings.PaperSizes)
            {
                var supportedWidth = Math.Min(supported.Width, supported.Height);
                var supportedHeight = Math.Max(supported.Width, supported.Height);
                if (Math.Abs(supportedWidth - page.PortraitWidthHundredthsInch) <= PaperToleranceHundredthsInch &&
                    Math.Abs(supportedHeight - page.PortraitHeightHundredthsInch) <= PaperToleranceHundredthsInch)
                {
                    return supported;
                }
            }

            var widthMillimeters = page.PortraitWidthHundredthsInch * 0.254d;
            var heightMillimeters = page.PortraitHeightHundredthsInch * 0.254d;
            return new PaperSize(
                $"BCWMS PDF {widthMillimeters:0.##}x{heightMillimeters:0.##}mm",
                page.PortraitWidthHundredthsInch,
                page.PortraitHeightHundredthsInch);
        }
    }
}
