using BCWMS.PrintAgent.Core.Reliability;

namespace BCWMS.PrintAgent.Windows.App;

internal sealed class OutcomeReviewForm : Form
{
    private readonly AgentController _controller;
    private readonly ListBox _jobs = new() { Dock = DockStyle.Fill };
    private readonly Button _markCompleted = new() { Text = "Kağıt çıktı: Completed işaretle", AutoSize = true };

    public OutcomeReviewForm(AgentController controller, IReadOnlyList<JournalEntry> entries)
    {
        _controller = controller;
        Text = "Belirsiz Baskı Sonuçları";
        Size = new Size(760, 420);
        StartPosition = FormStartPosition.CenterParent;
        var info = new Label
        {
            Dock = DockStyle.Top,
            AutoSize = true,
            MaximumSize = new Size(720, 0),
            Padding = new Padding(8),
            Text = "Bu işlerde durable intent yazıldı fakat tamamlanma kanıtı yok. Önce fiziksel yazıcı/kuyruğu kontrol edin. " +
                   "Kağıt çıktıysa seçili işi Completed işaretleyin. Çıkmadıysa bu kaydı silmeyin; BC'den mutlaka YENİ JobId ile manuel tekrar gönderin."
        };
        foreach (var entry in entries)
        {
            _jobs.Items.Add(new Choice(entry));
        }
        if (_jobs.Items.Count > 0) { _jobs.SelectedIndex = 0; }

        var buttons = new FlowLayoutPanel { Dock = DockStyle.Bottom, AutoSize = true, Padding = new Padding(8) };
        _markCompleted.Click += async (_, _) => await MarkCompletedAsync();
        buttons.Controls.Add(_markCompleted);
        buttons.Controls.Add(new Button { Text = "Kapat", AutoSize = true, DialogResult = DialogResult.Cancel });
        Controls.Add(_jobs);
        Controls.Add(info);
        Controls.Add(buttons);
        CancelButton = buttons.Controls.OfType<Button>().Last();
    }

    private async Task MarkCompletedAsync()
    {
        if (_jobs.SelectedItem is not Choice choice) { return; }
        if (MessageBox.Show(this,
                $"{choice.Entry.JobId} işinin fiziksel olarak çıktığını doğruladınız mı? Bu işlem otomatik yeniden baskıyı kalıcı olarak engeller.",
                "Fiziksel Çıktı Onayı", MessageBoxButtons.YesNo, MessageBoxIcon.Warning) != DialogResult.Yes)
        {
            return;
        }

        _markCompleted.Enabled = false;
        try
        {
            await _controller.MarkUncertainPrintAsCompletedAsync(choice.Entry.JobId);
            _jobs.Items.Remove(choice);
        }
        finally
        {
            _markCompleted.Enabled = true;
        }
    }

    private sealed record Choice(JournalEntry Entry)
    {
        public override string ToString() => $"{Entry.StartedAtUtc.LocalDateTime:g}  {Entry.JobId}";
    }
}
