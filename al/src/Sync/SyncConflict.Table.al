table 72019 "DOPSWHS Sync Conflict Buffer"
{
    Caption = 'DOPSWHS Sync Conflict Buffer';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'Entry No.'; AutoIncrement = true; DataClassification = SystemMetadata; }
        field(10; "Device ID"; Code[50]) { Caption = 'Device ID'; DataClassification = EndUserPseudonymousIdentifiers; }
        field(20; "Op Type"; Text[50]) { Caption = 'Op Type'; DataClassification = CustomerContent; }
        field(30; "Doc No."; Code[20]) { Caption = 'Doc No.'; DataClassification = CustomerContent; }
        field(40; ETag; Text[100]) { Caption = 'ETag'; DataClassification = SystemMetadata; }
        field(50; "Client Payload"; Blob) { Caption = 'Client Payload'; DataClassification = CustomerContent; }
        field(60; "Server Snapshot"; Blob) { Caption = 'Server Snapshot'; DataClassification = CustomerContent; }
        field(70; Status; Enum "DOPSWHS Sync Conflict Status") { Caption = 'Status'; DataClassification = CustomerContent; }
        field(80; "Created DateTime"; DateTime) { Caption = 'Created DateTime'; DataClassification = SystemMetadata; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(StatusCreated; Status, "Created DateTime") { }
    }
}
