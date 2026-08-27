using System.Globalization;
using System.Text;
using BCWMS.PrintAgent.Core.Contracts;

namespace BCWMS.PrintAgent.Windows.Printing;

internal static class TestDocumentFactory
{
    public static byte[] CreateZpl(string stationId) => Encoding.ASCII.GetBytes(
        $"^XA^CI28^PW600^LL320^FO30,30^A0N,36,36^FDBCWMS PRINT TEST^FS^FO30,85^A0N,24,24^FDStation: {Ascii(stationId)}^FS^FO30,125^A0N,24,24^FD{DateTimeOffset.Now:yyyy-MM-dd HH:mm:ss}^FS^FO30,180^GB540,2,2^FS^FO30,210^A0N,26,26^FDOK^FS^XZ");

    public static byte[] CreateRaw(PrintFormat format, string stationId)
    {
        if (format == PrintFormat.ZPL)
        {
            return CreateZpl(stationId);
        }

        var text = Encoding.ASCII.GetBytes($"BCWMS PRINT TEST\nStation: {Ascii(stationId)}\n{DateTimeOffset.Now:yyyy-MM-dd HH:mm:ss}\n\n");
        if (format == PrintFormat.ESCPOS)
        {
            return new byte[] { 0x1B, 0x40 }
                .Concat(text)
                .Concat(new byte[] { 0x0A, 0x0A, 0x1D, 0x56, 0x41, 0x00 })
                .ToArray();
        }

        return text.Concat(new byte[] { 0x0C }).ToArray();
    }

    public static byte[] CreatePdf(string stationId)
    {
        var text = $"BCWMS PRINT TEST  Station: {EscapePdf(stationId)}  {DateTimeOffset.Now:yyyy-MM-dd HH:mm:ss}";
        var stream = $"BT /F1 18 Tf 50 760 Td ({text}) Tj ET";
        var objects = new[]
        {
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
            "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
            $"<< /Length {Encoding.ASCII.GetByteCount(stream).ToString(CultureInfo.InvariantCulture)} >>\nstream\n{stream}\nendstream"
        };

        using var output = new MemoryStream();
        Write(output, "%PDF-1.4\n%BCWMS\n");
        var offsets = new List<long> { 0 };
        for (var index = 0; index < objects.Length; index++)
        {
            offsets.Add(output.Position);
            Write(output, $"{index + 1} 0 obj\n{objects[index]}\nendobj\n");
        }

        var xref = output.Position;
        Write(output, $"xref\n0 {objects.Length + 1}\n0000000000 65535 f \n");
        foreach (var offset in offsets.Skip(1))
        {
            Write(output, $"{offset:0000000000} 00000 n \n");
        }

        Write(output, $"trailer\n<< /Size {objects.Length + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n");
        return output.ToArray();
    }

    private static string Ascii(string value) => string.Concat(value.Select(static character => character <= 0x7f ? character : '-'));
    private static string EscapePdf(string value) => Ascii(value).Replace("\\", "\\\\", StringComparison.Ordinal).Replace("(", "\\(", StringComparison.Ordinal).Replace(")", "\\)", StringComparison.Ordinal);
    private static void Write(Stream stream, string value) => stream.Write(Encoding.ASCII.GetBytes(value));
}
