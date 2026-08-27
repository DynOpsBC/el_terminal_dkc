codeunit 72052 "DOPSWHS PrintNode Client"
{
    Access = Public;

    procedure SendPrintJob(var Queue: Record "DOPSWHS Print Job Queue"; Copies: Integer)
    var
        Client: HttpClient;
        Content: HttpContent;
        Response: HttpResponseMessage;
        ContentHeaders: HttpHeaders;
        ClientHeaders: HttpHeaders;
        Telemetry: Codeunit "DOPSWHS Telemetry";
        Base64: Codeunit "Base64 Convert";
        InStream: InStream;
        PayloadObject: JsonObject;
        ApiKey: Text;
        Payload: Text;
        ContentB64: Text;
        ContentType: Text;
    begin
        ApiKey := GetApiKey();
        if ApiKey = '' then begin
            Telemetry.LogInfo('PrintNode.MissingApiKey', 'PrintNode API key is not configured. Print job remains queued.');
            Log(Queue."Job ID", 'Queued', 'Missing PrintNode API key.');
            exit;
        end;
        Queue.CalcFields(ZPL);
        if Queue.ZPL.HasValue() then begin
            Queue.ZPL.CreateInStream(InStream);
            ContentB64 := Base64.ToBase64(InStream);
        end;
        if Queue."Format" = Queue."Format"::PDF then
            ContentType := 'pdf_base64'
        else
            ContentType := 'raw_base64';
        PayloadObject.Add('printerId', Queue."Printer ID");
        PayloadObject.Add('title', Queue."Source Doc");
        PayloadObject.Add('contentType', ContentType);
        PayloadObject.Add('content', ContentB64);
        PayloadObject.Add('source', 'BCWMSApp');
        PayloadObject.Add('qty', Copies);
        PayloadObject.WriteTo(Payload);
        Content.WriteFrom(Payload);
        Content.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');
        ClientHeaders := Client.DefaultRequestHeaders();
        ClientHeaders.Add('Authorization', 'Basic ' + ApiKey);
        Client.Post('https://api.printnode.com/printjobs', Content, Response);
        if Response.IsSuccessStatusCode() then begin
            Queue.Status := Queue.Status::Sent;
            Queue.Sent := CurrentDateTime();
            Queue.Modify(true);
            Log(Queue."Job ID", 'Sent', 'PrintNode accepted job.');
        end else begin
            Queue.Status := Queue.Status::Failed;
            Queue."Last Error" := CopyStr(Format(Response.HttpStatusCode()), 1, MaxStrLen(Queue."Last Error"));
            Queue."Retry Count" += 1;
            Queue.Modify(true);
            Log(Queue."Job ID", 'Failed', Queue."Last Error");
        end;
    end;

    local procedure GetApiKey(): Text
    var
        ApiKey: Text;
    begin
        if IsolatedStorage.Get('DOPSWHS.PrintNode.ApiKey', DataScope::Company, ApiKey) then
            exit(ApiKey);
        exit('');
    end;

    local procedure Log(JobId: Integer; EventType: Text[100]; Message: Text[250])
    var
        LogEntry: Record "DOPSWHS Print Job Log";
    begin
        LogEntry.Init();
        LogEntry."Job ID" := JobId;
        LogEntry.EventType := EventType;
        LogEntry.Message := Message;
        LogEntry.DateTime := CurrentDateTime();
        LogEntry.Insert(true);
    end;
}
