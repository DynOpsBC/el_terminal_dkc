table 72287 "DOPSWHS Printer"
{
    Caption = 'DOPSWHS Printer';
    DataClassification = CustomerContent;
    LookupPageId = "DOPSWHS Printer List";
    DrillDownPageId = "DOPSWHS Printer List";

    fields
    {
        field(1; "Code"; Code[20])
        {
            Caption = 'Code';
            DataClassification = CustomerContent;
            NotBlank = true;
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(3; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
            DataClassification = CustomerContent;
            TableRelation = Location;
        }
        field(4; "Format"; Enum "DOPSWHS Print Format")
        {
            Caption = 'Format';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if ("Format" <> "Format"::PDF) and "Enable BC Reports" then
                    "Enable BC Reports" := false;
            end;
        }
        field(5; "Printer Handle"; Text[260])
        {
            Caption = 'Printer Handle (OS Name)';
            DataClassification = CustomerContent;
            ToolTip = 'Operating-system printer name as seen by the local agent (e.g. ZDesigner-GK420t).';
        }
        field(6; Hostname; Text[100])
        {
            Caption = 'Hostname / IP';
            DataClassification = CustomerContent;
            ToolTip = 'Optional network host of the printer when direct socket 9100 is used.';
        }
        field(7; Port; Integer)
        {
            Caption = 'Port';
            DataClassification = CustomerContent;
            InitValue = 9100;
        }
        field(8; Active; Boolean)
        {
            Caption = 'Active';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(9; "Default Copies"; Integer)
        {
            Caption = 'Default Copies';
            DataClassification = CustomerContent;
            InitValue = 1;
            MinValue = 0;
            MaxValue = 10;
            ToolTip = 'Fallback copy count when neither the request nor a device mapping specifies a positive value.';
        }
        field(10; "Last Seen At"; DateTime)
        {
            Caption = 'Last Seen At';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(11; "Token Hash"; Text[128])
        {
            Caption = 'Token Hash';
            DataClassification = CustomerContent;
            Editable = false;
            ToolTip = 'SHA-256 hash of the agent token. The plain secret is shown only once at generation time.';
        }
        field(12; "Token Issued At"; DateTime)
        {
            Caption = 'Token Issued At';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(13; Comment; Text[250])
        {
            Caption = 'Comment';
            DataClassification = CustomerContent;
        }
        field(14; "Enable BC Reports"; Boolean)
        {
            Caption = 'Enable for BC Reports';
            DataClassification = CustomerContent;
            InitValue = false;
            ToolTip = 'Registers this printer in the standard Business Central printer list. Standard reports are rendered as PDF and routed through the WMS print bridge.';

            trigger OnValidate()
            begin
                if "Enable BC Reports" and ("Format" <> "Format"::PDF) then
                    Error('Only a PDF printer can be enabled for standard Business Central reports.');
            end;
        }
        field(15; "Paper Width (mm)"; Integer)
        {
            Caption = 'Paper Width (mm)';
            DataClassification = CustomerContent;
            MinValue = 0;
            ToolTip = 'Custom paper width in millimetres. Leave width and height at zero to use A4.';
        }
        field(16; "Paper Height (mm)"; Integer)
        {
            Caption = 'Paper Height (mm)';
            DataClassification = CustomerContent;
            MinValue = 0;
            ToolTip = 'Custom paper height in millimetres. Leave width and height at zero to use A4.';
        }
        field(17; "Last Agent ID"; Code[50])
        {
            Caption = 'Last Agent ID';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(18; "Station ID"; Code[128])
        {
            Caption = 'Station ID';
            DataClassification = CustomerContent;
            ToolTip = 'Canonical station that owns this printer. Allowed characters: A-Z, 0-9, period, underscore and hyphen.';

            trigger OnValidate()
            var
                AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
            begin
                "Station ID" := CopyStr(UpperCase(DelChr("Station ID", '=', ' ')), 1, MaxStrLen("Station ID"));
                if "Station ID" <> '' then
                    AzureBridge.ValidateStationId("Station ID");
            end;
        }
        field(19; "Discovered by Agent"; Boolean)
        {
            Caption = 'Discovered by Agent';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(20; "Agent Status"; Option)
        {
            Caption = 'Agent Status';
            DataClassification = SystemMetadata;
            Editable = false;
            OptionMembers = Unknown,Online,Offline,Printing,Error;
            OptionCaption = 'Unknown,Online,Offline,Printing,Error';
        }
        field(21; "Last Status At"; DateTime)
        {
            Caption = 'Last Status At';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(22; "Last Status Message"; Text[250])
        {
            Caption = 'Last Status Message';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(23; "Agent Version"; Text[50])
        {
            Caption = 'Agent Version';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(24; "Agent Default Printer"; Boolean)
        {
            Caption = 'Agent Default Printer';
            DataClassification = SystemMetadata;
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Code") { Clustered = true; }
        key(Location; "Location Code") { }
        key(Station; "Station ID", "Discovered by Agent") { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Code", Description, "Format", "Location Code", "Enable BC Reports") { }
    }

    trigger OnDelete()
    var
        Map: Record "DOPSWHS Device Printer Map";
    begin
        Map.SetRange("Printer Code", "Code");
        Map.DeleteAll(true);
    end;
}
