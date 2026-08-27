using System.Drawing;
using BCWMS.PrintAgent.Windows.Infrastructure;

namespace BCWMS.PrintAgent.Windows.App;

internal sealed class TrayApplicationContext : ApplicationContext
{
    private readonly AgentController _controller;
    private readonly NotifyIcon _trayIcon;
    private readonly Control _dispatcher = new();
    private DashboardForm? _dashboard;
    private bool _exiting;

    public TrayApplicationContext()
    {
        var logger = new AgentLogger();
        _controller = new AgentController(logger);
        var menu = new ContextMenuStrip();
        menu.Items.Add("Yönetim Panelini Aç", null, (_, _) => ShowDashboard());
        menu.Items.Add("Yazıcıları Buluta Eşitle", null, async (_, _) => await SyncAsync());
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Çıkış", null, async (_, _) => await ExitAsync());
        _trayIcon = new NotifyIcon
        {
            Icon = SystemIcons.Application,
            Text = "BCWMS Print Agent",
            ContextMenuStrip = menu,
            Visible = true
        };
        _trayIcon.DoubleClick += (_, _) => ShowDashboard();
        _dispatcher.CreateControl();
        _controller.StateChanged += (_, _) => PostToUi(UpdateTrayText);
        Application.Idle += OnFirstApplicationIdle;
    }

    private async void OnFirstApplicationIdle(object? sender, EventArgs e)
    {
        Application.Idle -= OnFirstApplicationIdle;
        await InitializeAsync();
    }

    private async Task InitializeAsync()
    {
        await _controller.InitializeAsync();
        UpdateTrayText();
        if (_controller.State is AgentState.NotConfigured or AgentState.Error)
        {
            ShowDashboard(showSettings: true);
        }
        else
        {
            _trayIcon.ShowBalloonTip(2500, "BCWMS Print Agent", "Azure yazdırma kuyruğu dinleniyor.", ToolTipIcon.Info);
        }
    }

    private void ShowDashboard(bool showSettings = false)
    {
        _dashboard ??= new DashboardForm(_controller);
        _dashboard.ShowAndActivate(showSettings);
    }

    private async Task SyncAsync()
    {
        try
        {
            await _controller.SyncSnapshotAsync();
            _trayIcon.ShowBalloonTip(2000, "BCWMS Print Agent", "Yazıcılar buluta eşitlendi.", ToolTipIcon.Info);
        }
        catch (Exception ex)
        {
            _controller.Logger.Error("Tepsi eşitleme işlemi başarısız", ex);
            _trayIcon.ShowBalloonTip(3000, "BCWMS Print Agent", ex.Message, ToolTipIcon.Error);
        }
    }

    private void UpdateTrayText()
    {
        var text = $"BCWMS Print Agent - {_controller.StateMessage}";
        _trayIcon.Text = text.Length <= 63 ? text : text[..63];
    }

    private void PostToUi(Action action)
    {
        if (_dispatcher.IsDisposed)
        {
            return;
        }

        if (_dispatcher.InvokeRequired)
        {
            try { _dispatcher.BeginInvoke(action); } catch (InvalidOperationException) { }
        }
        else
        {
            action();
        }
    }

    private async Task ExitAsync()
    {
        if (_exiting)
        {
            return;
        }

        _exiting = true;
        _trayIcon.Visible = false;
        _dashboard?.CloseForExit();
        try
        {
            await _controller.DisposeAsync();
        }
        catch (Exception ex)
        {
            _controller.Logger.Error("Agent kapanışı tamamlanamadı", ex);
            MessageBox.Show(ex.Message, "BCWMS Print Agent - Kapanış Hatası", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally
        {
            _trayIcon.Dispose();
            _dispatcher.Dispose();
            ExitThread();
        }
    }
}
