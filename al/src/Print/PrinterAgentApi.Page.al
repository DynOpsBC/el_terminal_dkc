page 72371 "DOPSWHS Printer Agent API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'printerAgent';
    EntitySetName = 'printerAgents';
    SourceTable = "DOPSWHS Printer";
    ODataKeyFields = "Code";
    DelayedInsert = true;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(code; Rec."Code") { Caption = 'code'; }
                field(active; Rec.Active) { Caption = 'active'; }
                field(lastSeenAt; Rec."Last Seen At") { Caption = 'lastSeenAt'; }
                field(lastAgentId; Rec."Last Agent ID") { Caption = 'lastAgentId'; }
            }
        }
    }

    [ServiceEnabled]
    procedure heartbeat(agentId: Code[50]): Boolean
    begin
        if agentId = '' then
            exit(false);
        if not Rec.Active then
            exit(false);
        if (Rec."Last Seen At" <> 0DT) and
           (Rec."Last Seen At" > CurrentDateTime() - (60 * 1000)) and
           (Rec."Last Agent ID" = agentId)
        then
            exit(true);
        Rec."Last Seen At" := CurrentDateTime();
        Rec."Last Agent ID" := agentId;
        Rec.Modify(true);
        exit(true);
    end;
}
