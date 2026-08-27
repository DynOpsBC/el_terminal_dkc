table 72280 "DOPSWHS Demo E2E Cue"
{
    // Singleton cue table for the Demo E2E Results page factbox. Each FlowField counts a
    // status slice of the result table so the operator sees pass/fail totals at a glance.
    Caption = 'Demo E2E Cue';
    DataClassification = SystemMetadata;
    Access = Public;

    fields
    {
        field(1; "Primary Key"; Code[10]) { Caption = 'Primary Key'; }
        field(10; "Total"; Integer)
        {
            FieldClass = FlowField;
            CalcFormula = count("DOPSWHS Demo E2E Result");
            Editable = false;
        }
        field(20; "Passed"; Integer)
        {
            FieldClass = FlowField;
            CalcFormula = count("DOPSWHS Demo E2E Result" where(Status = const(Passed)));
            Editable = false;
        }
        field(30; "Failed"; Integer)
        {
            FieldClass = FlowField;
            CalcFormula = count("DOPSWHS Demo E2E Result" where(Status = const(Failed)));
            Editable = false;
        }
        field(40; "Running"; Integer)
        {
            FieldClass = FlowField;
            CalcFormula = count("DOPSWHS Demo E2E Result" where(Status = const(Running)));
            Editable = false;
        }
        field(50; "Not Run"; Integer)
        {
            FieldClass = FlowField;
            CalcFormula = count("DOPSWHS Demo E2E Result" where(Status = const("Not Run")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }
}
