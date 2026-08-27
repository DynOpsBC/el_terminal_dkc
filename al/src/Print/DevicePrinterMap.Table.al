table 72288 "DOPSWHS Device Printer Map"
{
    Caption = 'DOPSWHS Device Printer Map';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Device ID"; Code[50])
        {
            Caption = 'Device ID';
            DataClassification = CustomerContent;
            ToolTip = 'Logical device or user identifier. Empty for tenant-wide defaults.';
        }
        field(2; Usage; Enum "DOPSWHS IWX Report Usage")
        {
            Caption = 'Usage';
            DataClassification = CustomerContent;
        }
        field(3; "Printer Code"; Code[20])
        {
            Caption = 'Printer Code';
            DataClassification = CustomerContent;
            TableRelation = "DOPSWHS Printer"."Code" where(Active = const(true));
        }
        field(4; Copies; Integer)
        {
            Caption = 'Copies';
            DataClassification = CustomerContent;
            InitValue = 1;
            MinValue = 0;
            MaxValue = 10;
            ToolTip = 'Number of copies used by this mapping. Set to 0 to use the printer default.';
        }
        field(5; Description; Text[100])
        {
            Caption = 'Description';
            FieldClass = FlowField;
            CalcFormula = lookup("DOPSWHS Printer".Description where("Code" = field("Printer Code")));
            Editable = false;
        }
        field(6; "Station ID"; Code[128])
        {
            Caption = 'Station ID';
            FieldClass = FlowField;
            CalcFormula = lookup("DOPSWHS Printer"."Station ID" where("Code" = field("Printer Code")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Device ID", Usage) { Clustered = true; }
        key(Printer; "Printer Code") { }
    }
}
