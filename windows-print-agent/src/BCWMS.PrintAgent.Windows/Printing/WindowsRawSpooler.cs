using System.ComponentModel;
using System.Runtime.ExceptionServices;
using System.Runtime.InteropServices;
using BCWMS.PrintAgent.Core.Reliability;
using BCWMS.PrintAgent.Core.Validation;

namespace BCWMS.PrintAgent.Windows.Printing;

internal static partial class WindowsRawSpooler
{
    public static Task PrintAsync(string printerName, string documentName, ReadOnlyMemory<byte> payload, int copies, CancellationToken cancellationToken) =>
        Task.Run(() => Print(printerName, documentName, payload, copies, cancellationToken), cancellationToken);

    private static void Print(string printerName, string documentName, ReadOnlyMemory<byte> payload, int copies, CancellationToken cancellationToken)
    {
        if (!OpenPrinter(printerName, out var printerHandle, 0) || printerHandle == 0)
        {
            var errorCode = Marshal.GetLastWin32Error();
            var message = $"Windows yazıcısı açılamadı: {printerName} ({new Win32Exception(errorCode).Message}).";
            if (errorCode == 1801) // ERROR_INVALID_PRINTER_NAME
            {
                throw new PermanentJobException(message);
            }

            throw new TransientJobException(message);
        }

        try
        {
            for (var copy = 1; copy <= copies; copy++)
            {
                cancellationToken.ThrowIfCancellationRequested();
                PrintOne(printerHandle, $"{documentName} [{copy}/{copies}]", payload.Span, cancellationToken);
            }
        }
        finally
        {
            ClosePrinter(printerHandle);
        }
    }

    private static unsafe void PrintOne(nint printerHandle, string documentName, ReadOnlySpan<byte> payload, CancellationToken cancellationToken)
    {
        var documentNamePointer = Marshal.StringToHGlobalUni(documentName);
        var dataTypePointer = Marshal.StringToHGlobalUni("RAW");
        var info = new DocInfo1 { DocumentName = documentNamePointer, DataType = dataTypePointer };
        int documentId;
        try
        {
            documentId = StartDocPrinter(printerHandle, 1, (nint)(&info));
        }
        finally
        {
            Marshal.FreeHGlobal(documentNamePointer);
            Marshal.FreeHGlobal(dataTypePointer);
        }

        if (documentId == 0)
        {
            throw SpoolerFailure("StartDocPrinter");
        }

        var pageStarted = false;
        Exception? failure = null;
        try
        {
            if (!StartPagePrinter(printerHandle))
            {
                throw SpoolerFailure("StartPagePrinter");
            }

            pageStarted = true;
            var payloadLength = payload.Length;
            fixed (byte* pointer = payload)
            {
                var baseAddress = (nint)pointer;
                WriteProgress.WriteAll(payloadLength, (offset, count) =>
                {
                    if (!WritePrinter(printerHandle, baseAddress + offset, count, out var written))
                    {
                        throw SpoolerFailure($"WritePrinter ({offset}/{payloadLength} byte)");
                    }

                    return written;
                }, cancellationToken);
            }
        }
        catch (Exception ex)
        {
            failure = ex;
        }

        if (pageStarted && !EndPagePrinter(printerHandle) && failure is null)
        {
            failure = SpoolerFailure("EndPagePrinter");
        }

        if (!EndDocPrinter(printerHandle) && failure is null)
        {
            failure = SpoolerFailure("EndDocPrinter");
        }

        if (failure is not null)
        {
            ExceptionDispatchInfo.Capture(failure).Throw();
        }
    }

    private static TransientJobException SpoolerFailure(string operation) =>
        new($"{operation} başarısız: {new Win32Exception(Marshal.GetLastWin32Error()).Message}.");

    [StructLayout(LayoutKind.Sequential)]
    private struct DocInfo1
    {
        public nint DocumentName;
        public nint OutputFile;
        public nint DataType;
    }

    [LibraryImport("winspool.drv", EntryPoint = "OpenPrinterW", SetLastError = true, StringMarshalling = StringMarshalling.Utf16)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool OpenPrinter(string printerName, out nint printerHandle, nint defaults);

    [LibraryImport("winspool.drv", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool ClosePrinter(nint printerHandle);

    [LibraryImport("winspool.drv", EntryPoint = "StartDocPrinterW", SetLastError = true)]
    private static partial int StartDocPrinter(nint printerHandle, int level, nint documentInfo);

    [LibraryImport("winspool.drv", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool EndDocPrinter(nint printerHandle);

    [LibraryImport("winspool.drv", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool StartPagePrinter(nint printerHandle);

    [LibraryImport("winspool.drv", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool EndPagePrinter(nint printerHandle);

    [LibraryImport("winspool.drv", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool WritePrinter(nint printerHandle, nint bytes, int count, out int written);
}
