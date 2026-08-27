table 72023 "DOPSWHS Print Job Log"
{
    Caption = 'DOPSWHS Print Job Log';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'Entry No.'; DataClassification = CustomerContent; AutoIncrement = true; }
        field(2; "Job ID"; Integer) { Caption = 'Job ID'; DataClassification = CustomerContent; TableRelation = "DOPSWHS Print Job Queue"; }
        field(3; EventType; Text[100]) { Caption = 'Event'; DataClassification = CustomerContent; }
        field(4; Message; Text[250]) { Caption = 'Message'; DataClassification = CustomerContent; }
        field(5; DateTime; DateTime) { Caption = 'DateTime'; DataClassification = CustomerContent; }
    }

    keys { key(PK; "Entry No.") { Clustered = true; } key(Job; "Job ID") { } }
}
