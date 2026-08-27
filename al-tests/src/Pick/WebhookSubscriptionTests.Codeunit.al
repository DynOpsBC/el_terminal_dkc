codeunit 72124 "DOPSWHS Webhook Tests"
{
    Subtype = Test;

    [Test]
    procedure SetupWizardCreatesSubscriptionsAndAuditRows()
    var
        WebhookMgmt: Codeunit "DOPSWHS Webhook Mgmt";
        Audit: Record "DOPSWHS Webhook Audit";
        Assert: Codeunit Assert;
    begin
        WebhookMgmt.SubscribeWebhooks('https://example.test/api/webhook');
        Audit.SetRange(Resource, 'picks');
        Assert.IsTrue(Audit.FindFirst(), 'Pick subscription audit row must exist.');
        WebhookMgmt.LogWebhookEvent('picks', 'pick.reassigned', CreateGuid(), 'https://example.test/api/webhook', 200, 'hash');
        Audit.SetRange("Event Type", 'pick.reassigned');
        Assert.IsTrue(Audit.FindFirst(), 'Webhook event audit row must be written.');
    end;
}
