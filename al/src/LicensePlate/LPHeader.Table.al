table 72010 "DOPSWHS LP Header"
{
    Caption = 'DOPSWHS LP Header';
    DataClassification = CustomerContent;
    LookupPageId = "DOPSWHS LP List";
    DrillDownPageId = "DOPSWHS LP List";

    fields
    {
        field(1; "No."; Code[20]) { Caption = 'No.'; DataClassification = CustomerContent; }
        field(10; "Location Code"; Code[10]) { Caption = 'Location Code'; DataClassification = CustomerContent; TableRelation = Location; }
        field(20; "Bin Code"; Code[20]) { Caption = 'Bin Code'; DataClassification = CustomerContent; TableRelation = Bin.Code where("Location Code" = field("Location Code")); }
        field(30; Status; Enum "DOPSWHS LP Status") { Caption = 'Status'; DataClassification = CustomerContent; }
        field(40; "Parent LP No."; Code[20]) { Caption = 'Parent LP No.'; DataClassification = CustomerContent; TableRelation = "DOPSWHS LP Header"; ValidateTableRelation = true; }
        field(50; "LP Template Code"; Code[20]) { Caption = 'LP Template Code'; DataClassification = CustomerContent; TableRelation = "DOPSWHS LP Template"; }
        field(60; SSCC; Code[18]) { Caption = 'SSCC'; DataClassification = CustomerContent; }
        field(70; "Assigned Document Type"; Enum "DOPSWHS Assigned Doc Type") { Caption = 'Assigned Document Type'; DataClassification = CustomerContent; }
        field(71; "Assigned Document No."; Code[20]) { Caption = 'Assigned Document No.'; DataClassification = CustomerContent; }
        field(80; "Built By User"; Code[50]) { Caption = 'Built By User'; DataClassification = CustomerContent; Editable = false; }
        field(81; "Built DateTime"; DateTime) { Caption = 'Built DateTime'; DataClassification = CustomerContent; Editable = false; }
        field(82; "Last Modified DateTime"; DateTime) { Caption = 'Last Modified DateTime'; DataClassification = CustomerContent; Editable = false; }
        field(90; "Weight kg"; Decimal)
        {
            Caption = 'Weight kg';
            FieldClass = FlowField;
            CalcFormula = sum("DOPSWHS LP Line"."Line Weight kg" where("LP No." = field("No.")));
            Editable = false;
        }
        field(100; "Length cm"; Decimal) { Caption = 'Length cm'; DataClassification = CustomerContent; }
        field(101; "Width cm"; Decimal) { Caption = 'Width cm'; DataClassification = CustomerContent; }
        field(102; "Height cm"; Decimal) { Caption = 'Height cm'; DataClassification = CustomerContent; }
        field(110; Notes; Text[250]) { Caption = 'Notes'; DataClassification = CustomerContent; }
        field(120; "Line Count"; Integer)
        {
            Caption = 'Line Count';
            FieldClass = FlowField;
            CalcFormula = count("DOPSWHS LP Line" where("LP No." = field("No.")));
            Editable = false;
        }
        field(121; "Total Quantity"; Decimal)
        {
            Caption = 'Total Quantity';
            FieldClass = FlowField;
            CalcFormula = sum("DOPSWHS LP Line".Quantity where("LP No." = field("No.")));
            Editable = false;
        }
        field(130; "Unit Type"; Enum "DOPSWHS LP Unit Type")
        {
            Caption = 'Unit Type';
            DataClassification = CustomerContent;
            Editable = false;
            ToolTip = 'Snapshot of the LP template unit type at creation time.';
        }
        field(140; "Hierarchy Label Print Count"; Integer)
        {
            Caption = 'Hierarchy Label Print Count';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(141; "Hierarchy Label Printed At"; DateTime)
        {
            Caption = 'Hierarchy Label Printed At';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(142; "Hierarchy Reprint Reason"; Text[100])
        {
            Caption = 'Hierarchy Reprint Reason';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }

    keys
    {
        key(PK; "No.") { Clustered = true; }
        key(StatusLocation; Status, "Location Code") { }
        key(Parent; "Parent LP No.") { }
        key(SSCCKey; SSCC) { }
        key(AssignedDoc; "Assigned Document Type", "Assigned Document No.") { }
    }

    trigger OnInsert()
    var
        ExistingLP: Record "DOPSWHS LP Header";
        LPSeriesSetup: Codeunit "DOPSWHS LP Series Setup";
        NoSeries: Codeunit "No. Series";
        Telemetry: Codeunit "DOPSWHS Telemetry";
        LPNoSeriesCode: Code[20];
        Attempts: Integer;
    begin
        if "No." = '' then begin
            LPNoSeriesCode := LPSeriesSetup.EnsureLpNoSeries();
            // A restored/copied company can contain LP records that are ahead
            // of the number series. Consume numbers until an unused LP is found.
            repeat
                "No." := NoSeries.GetNextNo(LPNoSeriesCode);
                Attempts += 1;
                if Attempts > 10000 then
                    Error(
                        '%1 numara serisinde kullanılabilir LP numarası bulunamadı. Numara serisinin son kullanılan değerini kontrol edin.',
                        LPNoSeriesCode);
            until not ExistingLP.Get("No.");
        end;
        "Built By User" := CopyStr(UserId(), 1, MaxStrLen("Built By User"));
        "Built DateTime" := CurrentDateTime();
        Telemetry.LogInfo('LP.Created', "No.");
    end;

    trigger OnModify()
    begin
        "Last Modified DateTime" := CurrentDateTime();
    end;

    trigger OnDelete()
    var
        LPLine: Record "DOPSWHS LP Line";
    begin
        if not (Status in [Status::Open, Status::Unbuilt]) then
            Error('Yalnız açık veya bozulmuş LP silinebilir.');

        LPLine.SetRange("LP No.", "No.");
        if not LPLine.IsEmpty() then
            Error('%1 LP numarasının satırları bulunduğu için silinemez.', "No.");
    end;
}
