table 72024 "DOPSWHS Telemetry Buffer"
{
    Caption = 'Advanced WMS Telemetry Buffer';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(10; Category; Text[100])
        {
            Caption = 'Category';
        }
        field(20; Message; Text[2048])
        {
            Caption = 'Message';
        }
        field(30; "Created At"; DateTime)
        {
            Caption = 'Created At';
        }
        field(40; "User Security ID"; Guid)
        {
            Caption = 'User Security ID';
        }
        field(50; "Processed"; Boolean)
        {
            Caption = 'Processed';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Processed; Processed, "Created At")
        {
        }
    }
}

