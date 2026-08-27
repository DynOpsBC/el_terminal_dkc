using BCWMS.PrintAgent.Windows.App;
using BCWMS.PrintAgent.Windows.Printing;
using System.Security.Principal;

namespace BCWMS.PrintAgent.Windows;

internal static class Program
{
    [STAThread]
    private static void Main(string[] args)
    {
        if (PrintWorkerCommand.TryExecute(args, out var workerExitCode))
        {
            Environment.ExitCode = workerExitCode;
            return;
        }

        var userSid = WindowsIdentity.GetCurrent().User?.Value
            ?? throw new InvalidOperationException("Windows kullanıcı SID bilgisi alınamadı.");
        using var mutex = new Mutex(initiallyOwned: true, $"Global\\DynOps.BCWMS.PrintAgent.{userSid}", out var createdNew);
        if (!createdNew)
        {
            MessageBox.Show("BCWMS Print Agent bu Windows kullanıcı profili için zaten çalışıyor.", "BCWMS Print Agent", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }

        ApplicationConfiguration.Initialize();
        Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
        Application.ThreadException += (_, args) =>
            MessageBox.Show(args.Exception.Message, "BCWMS Print Agent - Beklenmeyen Hata", MessageBoxButtons.OK, MessageBoxIcon.Error);
        Application.Run(new TrayApplicationContext());
        GC.KeepAlive(mutex);
    }
}
