table 72022 "DOPSWHS Print Job Queue"
{
    Caption = 'DOPSWHS Print Job Queue';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Job ID"; Integer) { Caption = 'Job ID'; DataClassification = CustomerContent; AutoIncrement = true; }
        field(2; "Source Doc"; Code[50]) { Caption = 'Source Doc'; DataClassification = CustomerContent; }
        field(3; "Report ID"; Integer) { Caption = 'Report ID'; DataClassification = CustomerContent; }
        field(4; "Printer ID"; Code[50]) { Caption = 'Printer ID'; DataClassification = CustomerContent; }
        field(5; Status; Option) { Caption = 'Status'; DataClassification = CustomerContent; OptionMembers = Queued,Sent,Failed,Dispatched; OptionCaption = 'Queued,Sent,Failed,Dispatched'; }
        field(6; ZPL; Blob) { Caption = 'Payload'; DataClassification = CustomerContent; }
        field(7; Created; DateTime) { Caption = 'Created'; DataClassification = CustomerContent; }
        field(8; Sent; DateTime) { Caption = 'Sent'; DataClassification = CustomerContent; }
        field(10; Channel; Enum "DOPSWHS Print Channel") { Caption = 'Channel'; DataClassification = CustomerContent; }
        field(11; "Format"; Enum "DOPSWHS Print Format") { Caption = 'Format'; DataClassification = CustomerContent; }
        field(12; Copies; Integer) { Caption = 'Copies'; DataClassification = CustomerContent; InitValue = 1; }
        field(13; "Agent ID"; Code[50]) { Caption = 'Agent ID'; DataClassification = CustomerContent; }
        field(14; "Claimed At"; DateTime) { Caption = 'Claimed At'; DataClassification = CustomerContent; }
        field(15; "Last Error"; Text[250]) { Caption = 'Last Error'; DataClassification = CustomerContent; }
        field(16; "Retry Count"; Integer) { Caption = 'Retry Count'; DataClassification = CustomerContent; }
        field(17; "Payload Size"; Integer) { Caption = 'Payload Size'; DataClassification = CustomerContent; }
        field(18; "Correlation ID"; Text[100]) { Caption = 'Correlation ID'; DataClassification = SystemMetadata; }
        field(19; "Cloud Job ID"; Guid) { Caption = 'Cloud Job ID'; DataClassification = SystemMetadata; }
        field(20; "Station ID"; Code[128]) { Caption = 'Station ID'; DataClassification = CustomerContent; }
        field(21; "Blob Name"; Text[250]) { Caption = 'Blob Name'; DataClassification = SystemMetadata; }
        field(22; "Payload SHA256"; Text[64]) { Caption = 'Payload SHA-256'; DataClassification = SystemMetadata; }
        field(23; "Dispatched At"; DateTime) { Caption = 'Dispatched At'; DataClassification = SystemMetadata; }
        field(24; "Completed At"; DateTime) { Caption = 'Completed At'; DataClassification = SystemMetadata; }
        field(25; "Next Retry At"; DateTime) { Caption = 'Next Retry At'; DataClassification = SystemMetadata; }
    }

    keys
    {
        key(PK; "Job ID") { Clustered = true; }
        key(Pull; Channel, Status, "Printer ID") { }
        key(Correlation; "Correlation ID", "Printer ID") { }
        key(CloudJob; "Cloud Job ID") { }
        key(DirectDispatch; Channel, Status, "Dispatched At", "Next Retry At") { }
    }
}
