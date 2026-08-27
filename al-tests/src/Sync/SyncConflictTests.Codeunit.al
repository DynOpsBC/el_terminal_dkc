codeunit 72139 "DOPSWHS Sync Conflict Tests"
{
    Subtype = Test;

    [Test]
    procedure ETagConflictStoresPayloads()
    var
        Conflict: Record "DOPSWHS Sync Conflict Buffer";
        OutStream: OutStream;
        Assert: Codeunit Assert;
    begin
        Conflict.Init();
        Conflict."Device ID" := 'DEVICE-1';
        Conflict."Op Type" := 'ConfirmPickLine';
        Conflict."Doc No." := 'PICK-T5-CONF';
        Conflict.ETag := 'W/"old"';
        Conflict.Status := Conflict.Status::Pending;
        Conflict."Created DateTime" := CurrentDateTime();
        Conflict."Client Payload".CreateOutStream(OutStream);
        OutStream.WriteText('{"qty":1}');
        Conflict."Server Snapshot".CreateOutStream(OutStream);
        OutStream.WriteText('{"qty":2}');
        Conflict.Insert(true);
        Assert.IsTrue(Conflict."Client Payload".HasValue(), 'Client payload must be stored.');
        Assert.IsTrue(Conflict."Server Snapshot".HasValue(), 'Server snapshot must be stored.');
    end;
}
