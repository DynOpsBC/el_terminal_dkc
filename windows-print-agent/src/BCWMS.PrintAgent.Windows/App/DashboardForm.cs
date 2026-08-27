using System.Drawing;
using BCWMS.PrintAgent.Core.Configuration;
using BCWMS.PrintAgent.Core.Contracts;
using BCWMS.PrintAgent.Windows.Printing;
using BCWMS.PrintAgent.Windows.Configuration;

namespace BCWMS.PrintAgent.Windows.App;

internal sealed class DashboardForm : Form
{
    private readonly AgentController _controller;
    private readonly CancellationTokenSource _lifetime = new();
    private readonly Label _statusLabel = new();
    private readonly Label _stationHeader = new();
    private readonly TextBox _station = new();
    private readonly TextBox _agentId = new();
    private readonly ComboBox _labelPrinter = new();
    private readonly ComboBox _documentPrinter = new();
    private readonly TextBox _labelPrinterId = new() { ReadOnly = true };
    private readonly TextBox _documentPrinterId = new() { ReadOnly = true };
    private readonly ComboBox _labelFormat = new();
    private readonly TextBox _jobsConnection = SecretTextBox();
    private readonly TextBox _statusConnection = SecretTextBox();
    private readonly TextBox _storageAccount = new();
    private readonly TextBox _blobEndpoint = new();
    private readonly TextBox _blobSas = SecretTextBox();
    private readonly Label _sasExpiry = new();
    private readonly RichTextBox _logs = new();
    private readonly TabControl _tabs = new();
    private readonly List<Button> _actionButtons = [];
    private IReadOnlyList<DiscoveredPrinter> _printers = [];
    private bool _allowClose;
    private DateTimeOffset? _blobSasExpiry;

    public DashboardForm(AgentController controller)
    {
        _controller = controller;
        Text = "BCWMS Print Agent";
        MinimumSize = new Size(760, 620);
        Size = new Size(900, 720);
        StartPosition = FormStartPosition.CenterScreen;
        Font = new Font("Segoe UI", 9F);
        Icon = SystemIcons.Application;

        BuildLayout();
        LoadSettings(controller.Settings);
        UpdateState();

        _controller.StateChanged += ControllerOnStateChanged;
        _controller.Logger.LineWritten += LoggerOnLineWritten;
        Shown += async (_, _) => await RunUiActionAsync(RefreshPrintersAsync);
        FormClosing += OnFormClosing;
    }

    public void ShowAndActivate(bool showSettings = false)
    {
        if (showSettings)
        {
            _tabs.SelectedIndex = 1;
        }

        Show();
        WindowState = FormWindowState.Normal;
        Activate();
        BringToFront();
    }

    public void CloseForExit()
    {
        _allowClose = true;
        _lifetime.Cancel();
        Close();
    }

    private void BuildLayout()
    {
        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 3,
            Padding = new Padding(14)
        };
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 64));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 28));

        var header = new Panel { Dock = DockStyle.Fill };
        _stationHeader.Font = new Font(Font, FontStyle.Bold);
        _stationHeader.AutoSize = true;
        _stationHeader.Location = new Point(4, 5);
        _statusLabel.AutoSize = true;
        _statusLabel.Location = new Point(4, 31);
        header.Controls.Add(_stationHeader);
        header.Controls.Add(_statusLabel);

        _tabs.Dock = DockStyle.Fill;
        _tabs.TabPages.Add(BuildPrintersTab());
        _tabs.TabPages.Add(BuildCloudSettingsTab());

        var footer = new Label
        {
            Dock = DockStyle.Fill,
            Text = "Kapatma düğmesi uygulamayı sistem tepsisine küçültür. Çıkış için tepsi menüsünü kullanın.",
            ForeColor = Color.DimGray,
            TextAlign = ContentAlignment.MiddleLeft
        };

        root.Controls.Add(header, 0, 0);
        root.Controls.Add(_tabs, 0, 1);
        root.Controls.Add(footer, 0, 2);
        Controls.Add(root);
    }

    private TabPage BuildPrintersTab()
    {
        var page = new TabPage("Yazıcılar");
        var layout = NewSettingsTable();
        AddRow(layout, 0, "Station ID", _station, "TENANT.COMPANY.WAREHOUSE.STATION (örn. CONTOSO.CRONUS.MAIN.PACK01)");
        AddRow(layout, 1, "Agent ID", _agentId, "Bu kurulum için otomatik ve kalıcı GUID");
        _agentId.ReadOnly = true;

        ConfigurePrinterCombo(_labelPrinter);
        ConfigurePrinterCombo(_documentPrinter);
        _labelPrinter.SelectedIndexChanged += (_, _) => PreviewPrinterIds();
        _documentPrinter.SelectedIndexChanged += (_, _) => PreviewPrinterIds();
        AddRow(layout, 2, "Etiket yazıcısı", _labelPrinter, "ZPL / ESC-POS / RAW işlerinin hedefi");
        AddRow(layout, 3, "Etiket Printer ID", _labelPrinterId, "BC Code[20] güvenli kalıcı logical ID");
        AddRow(layout, 4, "Belge yazıcısı", _documentPrinter, "PDF işlerinin hedefi");
        AddRow(layout, 5, "Belge Printer ID", _documentPrinterId, "BC Code[20] güvenli kalıcı logical ID");

        _labelFormat.DropDownStyle = ComboBoxStyle.DropDownList;
        _labelFormat.Items.AddRange(new object[] { PrintFormat.ZPL, PrintFormat.ESCPOS, PrintFormat.RAW });
        AddRow(layout, 6, "Etiket formatı", _labelFormat, "Business Central yazıcı formatıyla aynı olmalı");

        var buttons = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, WrapContents = true, Padding = new Padding(0, 8, 0, 4) };
        buttons.Controls.Add(ActionButton("Yazıcıları Yenile", async () => await RefreshPrintersAsync()));
        buttons.Controls.Add(ActionButton("Ayarları Kaydet ve Bağlan", SaveAsync, primary: true, width: 190));
        buttons.Controls.Add(ActionButton("Buluta Eşitle", () => _controller.SyncSnapshotAsync(_lifetime.Token)));
        buttons.Controls.Add(ActionButton("Etiket Testi", () => _controller.PrintLabelTestAsync(_lifetime.Token)));
        buttons.Controls.Add(ActionButton("Belge Testi", () => _controller.PrintDocumentTestAsync(_lifetime.Token)));
        buttons.Controls.Add(ActionButton("Belirsiz İşleri İncele", ReviewUncertainPrintsAsync, width: 170));
        layout.Controls.Add(buttons, 0, 7);
        layout.SetColumnSpan(buttons, 3);

        _logs.Dock = DockStyle.Fill;
        _logs.ReadOnly = true;
        _logs.BackColor = Color.FromArgb(24, 24, 24);
        _logs.ForeColor = Color.Gainsboro;
        _logs.Font = new Font("Consolas", 8.5F);
        _logs.WordWrap = false;
        layout.Controls.Add(_logs, 0, 8);
        layout.SetColumnSpan(_logs, 3);
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        page.Controls.Add(layout);
        return page;
    }

    private TabPage BuildCloudSettingsTab()
    {
        var page = new TabPage("Azure Ayarları");
        var layout = NewSettingsTable();
        AddRow(layout, 0, "İş kuyruğu SAS", _jobsConnection, "Yalnız Listen yetkili print-jobs-queue policy bağlantısı");
        AddRow(layout, 1, "Durum kuyruğu SAS", _statusConnection, "Yalnız Send yetkili printer-status-queue policy bağlantısı");
        AddRow(layout, 2, "Storage Account", _storageAccount, "Küçük harf/rakam; allowlist olarak kullanılır");
        AddRow(layout, 3, "Blob endpoint", _blobEndpoint, "https://<account>.blob.core.windows.net");
        AddRow(layout, 4, "Blob salt-okunur SAS", _blobSas, "print-jobs container için si=agent-read veya yalnız sp=r");

        _storageAccount.Leave += (_, _) =>
        {
            if (!string.IsNullOrWhiteSpace(_storageAccount.Text) && string.IsNullOrWhiteSpace(_blobEndpoint.Text))
            {
                _blobEndpoint.Text = $"https://{_storageAccount.Text.Trim()}.blob.core.windows.net";
            }
        };

        var importPanel = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true };
        importPanel.Controls.Add(ActionButton("Print Agent Secrets İçe Aktar", ImportRuntimeSecretsAsync, primary: true, width: 220));
        _sasExpiry.AutoSize = true;
        _sasExpiry.Margin = new Padding(12, 10, 3, 3);
        importPanel.Controls.Add(_sasExpiry);
        layout.Controls.Add(importPanel, 0, 5);
        layout.SetColumnSpan(importPanel, 3);

        var showSecrets = new CheckBox { Text = "Gizli değerleri göster", AutoSize = true, Margin = new Padding(3, 10, 3, 3) };
        showSecrets.CheckedChanged += (_, _) =>
        {
            _jobsConnection.UseSystemPasswordChar = !showSecrets.Checked;
            _statusConnection.UseSystemPasswordChar = !showSecrets.Checked;
            _blobSas.UseSystemPasswordChar = !showSecrets.Checked;
        };
        layout.Controls.Add(showSecrets, 1, 6);

        var info = new Label
        {
            AutoSize = true,
            MaximumSize = new Size(700, 0),
            ForeColor = Color.DimGray,
            Margin = new Padding(3, 20, 3, 3),
            Text = "Kuyruk adları sabittir: print-jobs-queue (session-enabled) ve printer-status-queue (non-session). " +
                   "Container sabittir: print-jobs. Gizli değerlerin tamamı diskte Windows DPAPI CurrentUser ile şifrelenir."
        };
        layout.Controls.Add(info, 0, 7);
        layout.SetColumnSpan(info, 3);
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        page.Controls.Add(layout);
        return page;
    }

    private void LoadSettings(AgentSettings settings)
    {
        _station.Text = settings.StationId;
        _agentId.Text = settings.AgentId;
        _jobsConnection.Text = settings.JobsListenConnectionString;
        _statusConnection.Text = settings.StatusSendConnectionString;
        _storageAccount.Text = settings.StorageAccount;
        _blobEndpoint.Text = settings.BlobEndpoint;
        _blobSas.Text = settings.BlobReadSas;
        _blobSasExpiry = settings.BlobSasExpiresAtUtc;
        UpdateSasExpiry();
        _labelPrinterId.Text = settings.LabelPrinterId;
        _documentPrinterId.Text = settings.DocumentPrinterId;
        _labelFormat.SelectedItem = settings.LabelFormat;
    }

    private async Task RefreshPrintersAsync()
    {
        var labelName = SelectedName(_labelPrinter) ?? _controller.Settings.LabelPrinterName;
        var documentName = SelectedName(_documentPrinter) ?? _controller.Settings.DocumentPrinterName;
        _printers = await _controller.DiscoverPrintersAsync(_lifetime.Token);
        FillPrinterCombo(_labelPrinter, labelName);
        FillPrinterCombo(_documentPrinter, documentName);
        _controller.Logger.Info($"Windows'ta {_printers.Count} yazıcı bulundu.");
    }

    private async Task SaveAsync()
    {
        var current = _controller.Settings;
        var settings = current with
        {
            AgentId = string.IsNullOrWhiteSpace(_agentId.Text) ? Guid.NewGuid().ToString("D") : _agentId.Text,
            StationId = _station.Text,
            JobsListenConnectionString = _jobsConnection.Text.Trim(),
            StatusSendConnectionString = _statusConnection.Text.Trim(),
            StorageAccount = _storageAccount.Text.Trim(),
            BlobEndpoint = _blobEndpoint.Text.Trim(),
            BlobReadSas = _blobSas.Text.Trim(),
            BlobSasExpiresAtUtc = _blobSasExpiry,
            LabelPrinterName = SelectedName(_labelPrinter) ?? string.Empty,
            DocumentPrinterName = SelectedName(_documentPrinter) ?? string.Empty,
            LabelFormat = _labelFormat.SelectedItem is PrintFormat format ? format : PrintFormat.ZPL,
            LabelTransport = LabelTransport.WindowsRaw
        };
        await _controller.SaveAndRestartAsync(settings, _printers, _lifetime.Token);
        LoadSettings(_controller.Settings);
        MessageBox.Show(this, "Ayarlar DPAPI ile korundu ve agent Azure kuyruğunu dinlemeye başladı.", "BCWMS Print Agent", MessageBoxButtons.OK, MessageBoxIcon.Information);
    }

    private async Task ImportRuntimeSecretsAsync()
    {
        using var dialog = new OpenFileDialog
        {
            Title = "print-agent.runtime.secrets.json seçin",
            Filter = "Print Agent secrets (print-agent.runtime.secrets.json)|print-agent.runtime.secrets.json|JSON (*.json)|*.json",
            CheckFileExists = true,
            Multiselect = false
        };
        if (dialog.ShowDialog(this) != DialogResult.OK)
        {
            return;
        }

        var imported = await RuntimeSecretsImporter.ImportAsync(dialog.FileName, _lifetime.Token);
        _station.Text = imported.StationId;
        _jobsConnection.Text = imported.JobsListenConnectionString;
        _statusConnection.Text = imported.StatusSendConnectionString;
        _storageAccount.Text = imported.StorageAccount;
        _blobEndpoint.Text = imported.BlobEndpoint;
        _blobSas.Text = imported.BlobReadSas;
        _blobSasExpiry = imported.BlobSasExpiresAtUtc;
        UpdateSasExpiry();
        MessageBox.Show(this, "Azure runtime ayarları forma aktarıldı. Dosya değiştirilmedi. Yazıcıları seçip 'Ayarları Kaydet ve Bağlan' düğmesine basın.", "BCWMS Print Agent", MessageBoxButtons.OK, MessageBoxIcon.Information);
    }

    private async Task ReviewUncertainPrintsAsync()
    {
        var entries = await _controller.GetUncertainPrintsAsync(_lifetime.Token);
        if (entries.Count == 0)
        {
            MessageBox.Show(this, "İncelenmesi gereken InProgress baskı intent'i yok.", "BCWMS Print Agent", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }

        using var dialog = new OutcomeReviewForm(_controller, entries);
        dialog.ShowDialog(this);
    }

    private void UpdateSasExpiry()
    {
        if (_blobSasExpiry is null)
        {
            _sasExpiry.Text = "SAS bitişi: bilinmiyor";
            _sasExpiry.ForeColor = Color.DimGray;
            return;
        }

        var remaining = _blobSasExpiry.Value - DateTimeOffset.UtcNow;
        _sasExpiry.Text = $"SAS bitişi: {_blobSasExpiry.Value.LocalDateTime:g}";
        _sasExpiry.ForeColor = remaining <= TimeSpan.Zero ? Color.Firebrick : remaining <= TimeSpan.FromDays(7) ? Color.DarkOrange : Color.ForestGreen;
    }

    private Button ActionButton(string text, Func<Task> action, bool primary = false, int width = 135)
    {
        var button = new Button
        {
            Text = text,
            Width = width,
            Height = 36,
            Margin = new Padding(3, 3, 6, 3),
            FlatStyle = FlatStyle.Flat,
            BackColor = primary ? Color.FromArgb(0, 120, 212) : Color.White,
            ForeColor = primary ? Color.White : Color.Black
        };
        button.Click += async (_, _) => await RunUiActionAsync(action);
        _actionButtons.Add(button);
        return button;
    }

    private async Task RunUiActionAsync(Func<Task> action)
    {
        SetBusy(true);
        try
        {
            await action();
        }
        catch (OperationCanceledException) when (_lifetime.IsCancellationRequested) { }
        catch (Exception ex)
        {
            _controller.Logger.Error("İşlem başarısız", ex);
            MessageBox.Show(this, ex.Message, "BCWMS Print Agent", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally
        {
            SetBusy(false);
        }
    }

    private void SetBusy(bool busy)
    {
        UseWaitCursor = busy;
        foreach (var button in _actionButtons)
        {
            button.Enabled = !busy;
        }
    }

    private void UpdateState()
    {
        _stationHeader.Text = $"İstasyon: {_controller.Settings.StationId}";
        _statusLabel.Text = $"Durum: {_controller.StateMessage}";
        _statusLabel.ForeColor = _controller.State switch
        {
            AgentState.Connected => Color.ForestGreen,
            AgentState.Starting or AgentState.Disconnected => Color.DarkOrange,
            AgentState.Error => Color.Firebrick,
            _ => Color.DimGray
        };
    }

    private void ControllerOnStateChanged(object? sender, EventArgs e) => PostToUi(UpdateState);

    private void LoggerOnLineWritten(object? sender, string line) => PostToUi(() =>
    {
        _logs.AppendText(line + Environment.NewLine);
        if (_logs.TextLength > 100_000)
        {
            _logs.Select(0, 20_000);
            _logs.SelectedText = string.Empty;
        }

        _logs.SelectionStart = _logs.TextLength;
        _logs.ScrollToCaret();
    });

    private void PostToUi(Action action)
    {
        if (IsDisposed || Disposing)
        {
            return;
        }

        if (InvokeRequired)
        {
            try { BeginInvoke(action); } catch (InvalidOperationException) { }
        }
        else
        {
            action();
        }
    }

    private void FillPrinterCombo(ComboBox combo, string? selectedName)
    {
        combo.BeginUpdate();
        try
        {
            combo.Items.Clear();
            combo.Items.Add(new PrinterChoice(string.Empty, "Seçilmedi", false));
            foreach (var printer in _printers)
            {
                combo.Items.Add(new PrinterChoice(printer.Name, printer.Status, printer.IsDefault));
            }

            if (!string.IsNullOrWhiteSpace(selectedName) && !_printers.Any(printer => string.Equals(printer.Name, selectedName, StringComparison.OrdinalIgnoreCase)))
            {
                combo.Items.Add(new PrinterChoice(selectedName, "Offline / bulunamadı", false));
            }

            combo.SelectedItem = combo.Items.Cast<PrinterChoice>().FirstOrDefault(choice => string.Equals(choice.Name, selectedName, StringComparison.OrdinalIgnoreCase))
                ?? combo.Items[0];
        }
        finally
        {
            combo.EndUpdate();
        }
    }

    private static string? SelectedName(ComboBox combo) =>
        combo.SelectedItem is PrinterChoice choice && !string.IsNullOrWhiteSpace(choice.Name) ? choice.Name : null;

    private void PreviewPrinterIds()
    {
        _labelPrinterId.Text = PreviewId(SelectedName(_labelPrinter));
        _documentPrinterId.Text = PreviewId(SelectedName(_documentPrinter));
    }

    private string PreviewId(string? name)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            return string.Empty;
        }

        return _controller.Settings.PrinterIdsByName.TryGetValue(name, out var id)
            ? id
            : "(kaydetmede oluşturulacak)";
    }

    private static void ConfigurePrinterCombo(ComboBox combo)
    {
        combo.DropDownStyle = ComboBoxStyle.DropDownList;
        combo.DropDownWidth = 520;
    }

    private static TableLayoutPanel NewSettingsTable()
    {
        var table = new TableLayoutPanel { Dock = DockStyle.Fill, AutoScroll = true, ColumnCount = 3, Padding = new Padding(12) };
        table.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 145));
        table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 58));
        table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 42));
        return table;
    }

    private static void AddRow(TableLayoutPanel table, int row, string label, Control input, string hint)
    {
        table.RowStyles.Add(new RowStyle(SizeType.Absolute, 47));
        table.Controls.Add(new Label { Text = label, AutoSize = true, Anchor = AnchorStyles.Left, Font = new Font(table.Font, FontStyle.Bold) }, 0, row);
        input.Dock = DockStyle.Fill;
        input.Margin = new Padding(3, 7, 8, 7);
        table.Controls.Add(input, 1, row);
        table.Controls.Add(new Label { Text = hint, AutoSize = true, MaximumSize = new Size(300, 0), ForeColor = Color.DimGray, Anchor = AnchorStyles.Left }, 2, row);
    }

    private static TextBox SecretTextBox() => new() { UseSystemPasswordChar = true };

    private void OnFormClosing(object? sender, FormClosingEventArgs e)
    {
        if (_allowClose || e.CloseReason == CloseReason.WindowsShutDown)
        {
            _controller.StateChanged -= ControllerOnStateChanged;
            _controller.Logger.LineWritten -= LoggerOnLineWritten;
            return;
        }

        e.Cancel = true;
        Hide();
    }
}
