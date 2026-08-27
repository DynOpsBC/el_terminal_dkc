enum 72203 "DOPSWHS Print Channel"
{
    Extensible = true;

    value(0; PrintNode)
    {
        Caption = 'PrintNode';
    }
    value(1; BCNative)
    {
        Caption = 'Business Central Native';
    }
    value(2; SelfHosted)
    {
        Caption = 'Self-Hosted (Local Agent)';
    }
    value(3; AzureDirect)
    {
        Caption = 'Azure Direct (Blob + Service Bus)';
    }
}
