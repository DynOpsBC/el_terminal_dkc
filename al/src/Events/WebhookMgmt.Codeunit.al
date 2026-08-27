codeunit 72053 "DOPSWHS Webhook Mgmt"
{
    Access = Public;

    procedure SubscribeWebhooks(Endpoint: Text[250])
    var
        License: Codeunit "DOPSWHS License Mgmt";
        SubscriptionId: Guid;
    begin
        License.GuardFeature(Enum::"DOPSWHS License Feature"::WebhookPublish);

        if Endpoint = '' then
            Endpoint := 'https://placeholder.invalid/api/webhook';

        SubscriptionId := CreateGuid();
        LogWebhookEvent('picks', 'subscribe', SubscriptionId, Endpoint, 202, '');
        LogWebhookEvent('licensePlates', 'subscribe', SubscriptionId, Endpoint, 202, '');
        LogWebhookEvent('shipments', 'subscribe', SubscriptionId, Endpoint, 202, '');
    end;

    procedure LogWebhookEvent(Resource: Text[100]; EventType: Text[50]; SubscriptionId: Guid; Endpoint: Text[250]; HttpStatus: Integer; PayloadHash: Text[128])
    var
        Audit: Record "DOPSWHS Webhook Audit";
    begin
        Audit.Init();
        Audit.Resource := Resource;
        Audit."Event Type" := EventType;
        Audit."Subscription ID" := SubscriptionId;
        Audit.Endpoint := Endpoint;
        Audit."Sent DateTime" := CurrentDateTime();
        Audit."HTTP Status" := HttpStatus;
        Audit."Payload Hash" := PayloadHash;
        Audit.Insert(true);
    end;

    [BusinessEvent(false)]
    procedure OnPickReassigned(PickNo: Code[20]; FromUserId: Code[50]; ToUserId: Code[50])
    begin
    end;
}
