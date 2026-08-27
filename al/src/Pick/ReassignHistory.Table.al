table 72021 "DOPSWHS Pick Reassign Hist"
{
    Caption = 'DOPSWHS Pick Reassign Hist';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'Entry No.'; AutoIncrement = true; DataClassification = SystemMetadata; }
        field(10; "Pick No."; Code[20]) { Caption = 'Pick No.'; DataClassification = CustomerContent; TableRelation = "Warehouse Activity Header"."No." where(Type = const(Pick)); }
        field(20; "From User"; Code[50]) { Caption = 'From User'; DataClassification = EndUserIdentifiableInformation; }
        field(30; "To User"; Code[50]) { Caption = 'To User'; DataClassification = EndUserIdentifiableInformation; }
        field(40; "Reassigned By"; Code[50]) { Caption = 'Reassigned By'; DataClassification = EndUserIdentifiableInformation; }
        field(50; DateTime; DateTime) { Caption = 'DateTime'; DataClassification = SystemMetadata; }
        field(60; Reason; Text[250]) { Caption = 'Reason'; DataClassification = CustomerContent; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(Pick; "Pick No.", DateTime) { }
    }
}
