table 72000 "DOPSWHS Setup"
{
    Caption = 'Advanced WMS Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            InitValue = '';
            DataClassification = SystemMetadata;
        }
        field(10; "LP No. Series"; Code[20])
        {
            Caption = 'LP No. Series';
            TableRelation = "No. Series";
        }
        field(20; "SSCC No. Series"; Code[20])
        {
            Caption = 'SSCC No. Series';
            TableRelation = "No. Series";
        }
        field(30; "GS1 Company Prefix"; Code[12])
        {
            Caption = 'GS1 Company Prefix';
        }
        field(40; "Default Location Code"; Code[10])
        {
            Caption = 'Default Location Code';
            TableRelation = Location;
        }
        field(50; "Print Channel"; Enum "DOPSWHS Print Channel")
        {
            Caption = 'Print Channel';
        }
        field(60; "PrintNode API Key Set"; Boolean)
        {
            Caption = 'PrintNode API Key Set';
            Editable = false;
        }
        field(70; "Max LP Nesting Depth"; Integer)
        {
            Caption = 'Max LP Nesting Depth';
            InitValue = 3;
            DataClassification = CustomerContent;
        }
        field(80; "Webhook Endpoint"; Text[250])
        {
            Caption = 'Webhook Endpoint';
            DataClassification = CustomerContent;
            ExtendedDatatype = URL;
        }
        field(90; "Count Sheet No. Series"; Code[20])
        {
            Caption = 'Count Sheet No. Series';
            TableRelation = "No. Series";
            DataClassification = CustomerContent;
        }
        field(100; "License Tier"; Option)
        {
            Caption = 'License Tier';
            OptionMembers = Essentials,Advanced,Enterprise;
            OptionCaption = 'Essentials,Advanced,Enterprise';
            DataClassification = CustomerContent;
        }
        field(110; "Device Limit"; Integer)
        {
            Caption = 'Device Limit';
            InitValue = 10;
            DataClassification = CustomerContent;
        }
        field(120; "WI Migration Complete"; Boolean)
        {
            Caption = 'WI Migration Complete';
            DataClassification = CustomerContent;
        }
        field(130; "Print Relay URL"; Text[250])
        {
            Caption = 'Print Relay URL';
            DataClassification = CustomerContent;
            ExtendedDatatype = URL;
            ToolTip = 'Base URL of the print-relay Azure Function used by the self-hosted local agent.';
        }
        field(140; "Print Token TTL Hours"; Integer)
        {
            Caption = 'Print Token TTL Hours';
            DataClassification = CustomerContent;
            InitValue = 8760;
            ToolTip = 'Lifetime in hours of agent tokens. Zero disables rotation.';
        }
        field(150; "License Service URL"; Text[250])
        {
            Caption = 'License Service URL';
            DataClassification = CustomerContent;
            ExtendedDatatype = URL;
            ToolTip = 'Base URL of the DynOps licensing-service Azure Function (e.g. https://bcwms-licensing-func.azurewebsites.net).';
        }
        field(160; "License Key"; Text[2048])
        {
            Caption = 'License Key (JWT)';
            DataClassification = CustomerContent;
            ToolTip = 'RS256 JWT issued by DynOps licensing-service. Pasted from the customer portal.';
        }
        field(170; "License Status"; Enum "DOPSWHS License Status")
        {
            Caption = 'License Status';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(180; "License Last Verified At"; DateTime)
        {
            Caption = 'License Last Verified At';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(190; "License Expires At"; DateTime)
        {
            Caption = 'License Expires At';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(200; "License Seats"; Integer)
        {
            Caption = 'License Seats';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(210; "License Email"; Text[100])
        {
            Caption = 'License Email';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(220; "License Status Message"; Text[250])
        {
            Caption = 'License Status Message';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(230; "Show SO Shipment Mobile"; Boolean)
        {
            // Müşteri toplantısı kararı: sipariş bazlı (Sales Order) sevkiyat
            // terminalde opsiyonel olsun. Varsayılan açık — kapatınca el
            // terminali sadece Warehouse Shipment belgelerini gösterir.
            Caption = 'Show SO Shipment on Mobile';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(240; "Lot No. Series"; Code[20])
        {
            // Otomatik Lot numarası üretimi (mal kabulde lot boş bırakılırsa).
            Caption = 'Lot No. Series';
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
        }
        field(250; "Serial No. Series"; Code[20])
        {
            // Otomatik Seri numarası üretimi (mal kabulde seri boş bırakılırsa).
            Caption = 'Serial No. Series';
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
        }
        field(260; "Azure SB Namespace"; Text[50])
        {
            Caption = 'Service Bus Namespace';
            DataClassification = CustomerContent;
            ToolTip = 'Azure Service Bus namespace name only, without protocol or DNS suffix.';

            trigger OnValidate()
            begin
                "Azure SB Namespace" := LowerCase(DelChr("Azure SB Namespace", '=', ' '));
            end;
        }
        field(270; "Azure Print Jobs Queue"; Text[260])
        {
            Caption = 'Print Jobs Queue';
            DataClassification = CustomerContent;
            InitValue = 'print-jobs-queue';

            trigger OnValidate()
            begin
                "Azure Print Jobs Queue" := LowerCase(DelChr("Azure Print Jobs Queue", '=', ' '));
            end;
        }
        field(280; "Azure Printer Status Queue"; Text[260])
        {
            Caption = 'Printer Status Queue';
            DataClassification = CustomerContent;
            InitValue = 'printer-status-queue';

            trigger OnValidate()
            begin
                "Azure Printer Status Queue" := LowerCase(DelChr("Azure Printer Status Queue", '=', ' '));
            end;
        }
        field(290; "Azure Jobs SAS Policy"; Text[50])
        {
            Caption = 'Jobs Send SAS Policy';
            DataClassification = CustomerContent;
            InitValue = 'bc-send-jobs';
            ToolTip = 'Name of the queue-scoped Service Bus policy with Send permission. The key is stored separately in Isolated Storage.';
        }
        field(300; "Azure Status SAS Policy"; Text[50])
        {
            Caption = 'Status Listen SAS Policy';
            DataClassification = CustomerContent;
            InitValue = 'bc-listen-status';
            ToolTip = 'Name of the queue-scoped Service Bus policy with Listen permission. The key is stored separately in Isolated Storage.';
        }
        field(310; "Azure Storage Account"; Text[24])
        {
            Caption = 'Storage Account';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                "Azure Storage Account" := LowerCase(DelChr("Azure Storage Account", '=', ' '));
            end;
        }
        field(320; "Azure Blob Container"; Text[63])
        {
            Caption = 'Print Blob Container';
            DataClassification = CustomerContent;
            InitValue = 'print-jobs';

            trigger OnValidate()
            begin
                "Azure Blob Container" := LowerCase(DelChr("Azure Blob Container", '=', ' '));
            end;
        }
        field(330; "Azure Blob Endpoint Suffix"; Text[100])
        {
            Caption = 'Blob Endpoint Suffix';
            DataClassification = CustomerContent;
            InitValue = 'blob.core.windows.net';
            ToolTip = 'DNS suffix for Azure Blob Storage. Keep the default for Azure public cloud.';
        }
        field(340; "Azure SB Endpoint Suffix"; Text[100])
        {
            Caption = 'Service Bus Endpoint Suffix';
            DataClassification = CustomerContent;
            InitValue = 'servicebus.windows.net';
            ToolTip = 'DNS suffix for Azure Service Bus. Keep the default for Azure public cloud.';
        }
        field(350; "Azure Dispatch Max Attempts"; Integer)
        {
            Caption = 'Maximum Dispatch Attempts';
            DataClassification = CustomerContent;
            InitValue = 5;
            MinValue = 1;
            MaxValue = 20;
        }
        field(360; "Azure Last Health Check"; DateTime)
        {
            Caption = 'Last Health Check';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(370; "Azure Last Health Result"; Text[250])
        {
            Caption = 'Last Health Result';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(380; "Azure Tenant Route ID"; Code[32])
        {
            Caption = 'Tenant Route ID';
            DataClassification = CustomerContent;
            ToolTip = 'First segment of every canonical station ID. This is a routing identifier, not a credential.';

            trigger OnValidate()
            begin
                "Azure Tenant Route ID" := CopyStr(UpperCase(DelChr("Azure Tenant Route ID", '=', ' ')), 1, MaxStrLen("Azure Tenant Route ID"));
            end;
        }
        field(390; "Azure Company Route ID"; Code[32])
        {
            Caption = 'Company Route ID';
            DataClassification = CustomerContent;
            ToolTip = 'Second segment of every canonical station ID. Use one dedicated Azure deployment/status queue per Business Central company.';

            trigger OnValidate()
            begin
                "Azure Company Route ID" := CopyStr(UpperCase(DelChr("Azure Company Route ID", '=', ' ')), 1, MaxStrLen("Azure Company Route ID"));
            end;
        }
        field(400; "Azure Blob SAS Expires At"; DateTime)
        {
            Caption = 'Blob Upload SAS Expires At';
            DataClassification = SystemMetadata;
            Editable = false;
            ToolTip = 'UTC expiration of the Blob create/write SAS. Regenerate and re-import credentials before this time.';
        }
        field(410; "Azure Expiry Warning At"; DateTime)
        {
            Caption = 'Blob SAS Expiry Warning At';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(420; "Hierarchical LP Enabled"; Boolean)
        {
            Caption = 'Hierarchical LP Enabled';
            DataClassification = CustomerContent;
            InitValue = false;
            ToolTip = 'Enables the DKC product-box-pallet LP workflow for this Business Central company. Keep disabled in BADE companies.';

            trigger OnValidate()
            begin
                if "Hierarchical LP Enabled" then begin
                    TestField("GS1 Company Prefix");
                    if "Max LP Nesting Depth" < 2 then
                        Error('Hierarchical LP requires Max LP Nesting Depth to be at least 2.');
                end;
            end;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    var
        ExistingSetup: Record "DOPSWHS Setup";
    begin
        "Primary Key" := '';
        if ExistingSetup.Get('') then
            Error('Only one Advanced WMS Setup row is allowed.');
        ApplyAzureDefaults();
    end;

    procedure ApplyAzureDefaults()
    begin
        if "Azure Print Jobs Queue" = '' then
            "Azure Print Jobs Queue" := 'print-jobs-queue';
        if "Azure Printer Status Queue" = '' then
            "Azure Printer Status Queue" := 'printer-status-queue';
        if "Azure Jobs SAS Policy" = '' then
            "Azure Jobs SAS Policy" := 'bc-send-jobs';
        if "Azure Status SAS Policy" = '' then
            "Azure Status SAS Policy" := 'bc-listen-status';
        if "Azure Blob Container" = '' then
            "Azure Blob Container" := 'print-jobs';
        if "Azure Blob Endpoint Suffix" = '' then
            "Azure Blob Endpoint Suffix" := 'blob.core.windows.net';
        if "Azure SB Endpoint Suffix" = '' then
            "Azure SB Endpoint Suffix" := 'servicebus.windows.net';
        if "Azure Dispatch Max Attempts" <= 0 then
            "Azure Dispatch Max Attempts" := 5;
    end;
}
