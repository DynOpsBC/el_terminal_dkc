table 72020 "DOPSWHS Webhook Audit"
{
    Caption = 'DOPSWHS Webhook Audit';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'Entry No.'; AutoIncrement = true; DataClassification = SystemMetadata; }
        field(10; Resource; Text[100]) { Caption = 'Resource'; DataClassification = CustomerContent; }
        field(20; "Event Type"; Text[50]) { Caption = 'Event Type'; DataClassification = CustomerContent; }
        field(30; "Subscription ID"; Guid) { Caption = 'Subscription ID'; DataClassification = SystemMetadata; }
        field(40; Endpoint; Text[250]) { Caption = 'Endpoint'; DataClassification = CustomerContent; ExtendedDatatype = URL; }
        field(50; "Sent DateTime"; DateTime) { Caption = 'Sent DateTime'; DataClassification = SystemMetadata; }
        field(60; "HTTP Status"; Integer) { Caption = 'HTTP Status'; DataClassification = SystemMetadata; }
        field(70; "Payload Hash"; Text[128]) { Caption = 'Payload Hash'; DataClassification = SystemMetadata; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(ResourceEvent; Resource, "Event Type", "Sent DateTime") { }
    }
}
