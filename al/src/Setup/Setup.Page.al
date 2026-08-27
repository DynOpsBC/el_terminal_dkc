page 72061 "DOPSWHS Setup"
{
    Caption = 'Advanced WMS Setup';
    PageType = Card;
    SourceTable = "DOPSWHS Setup";
    ApplicationArea = All;
    UsageCategory = Administration;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                field("LP No. Series"; Rec."LP No. Series")
                {
                    ApplicationArea = All;
                }
                field("SSCC No. Series"; Rec."SSCC No. Series")
                {
                    ApplicationArea = All;
                }
                field("GS1 Company Prefix"; Rec."GS1 Company Prefix")
                {
                    ApplicationArea = All;
                }
                field("Default Location Code"; Rec."Default Location Code")
                {
                    ApplicationArea = All;
                }
                field("Print Channel"; Rec."Print Channel")
                {
                    ApplicationArea = All;
                }
                field("PrintNode API Key Set"; Rec."PrintNode API Key Set")
                {
                    ApplicationArea = All;
                }
                field("Print Relay URL"; Rec."Print Relay URL")
                {
                    ApplicationArea = All;
                }
                field("Print Token TTL Hours"; Rec."Print Token TTL Hours")
                {
                    ApplicationArea = All;
                }
                field("Max LP Nesting Depth"; Rec."Max LP Nesting Depth")
                {
                    ApplicationArea = All;
                }
                field("Hierarchical LP Enabled"; Rec."Hierarchical LP Enabled")
                {
                    ApplicationArea = All;
                    ToolTip = 'Yalnız DKC/EMU şirketinde açın. BADE şirketlerinde kapalı bırakın. Açmadan önce gerçek GS1 firma önekini girin.';
                }
                field("Webhook Endpoint"; Rec."Webhook Endpoint")
                {
                    ApplicationArea = All;
                }
                field("Show SO Shipment Mobile"; Rec."Show SO Shipment Mobile")
                {
                    ApplicationArea = All;
                    ToolTip = 'Açık: el terminalinde "Sales Order" sevkiyat sekmesi gösterilir. Kapalı: sadece Warehouse Shipment belgeleri gösterilir.';
                }
                field("Lot No. Series"; Rec."Lot No. Series")
                {
                    ApplicationArea = All;
                    ToolTip = 'Ayarlanırsa, mal kabulde lot boş bırakılınca otomatik lot numarası üretilir. Boş = elle giriş.';
                }
                field("Serial No. Series"; Rec."Serial No. Series")
                {
                    ApplicationArea = All;
                    ToolTip = 'Ayarlanırsa, mal kabulde seri boş bırakılınca otomatik seri numarası üretilir. Boş = elle giriş.';
                }
            }
            group(License)
            {
                Caption = 'License';
                field("License Service URL"; Rec."License Service URL")
                {
                    ApplicationArea = All;
                }
                field("License Key"; Rec."License Key")
                {
                    ApplicationArea = All;
                    MultiLine = true;
                    trigger OnValidate()
                    var
                        Mgmt: Codeunit "DOPSWHS License Mgmt";
                    begin
                        if Rec."License Key" <> '' then
                            Mgmt.VerifyNow();
                    end;
                }
                field("License Tier"; Rec."License Tier")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("License Status"; Rec."License Status")
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = LicenseStyle;
                }
                field("License Seats"; Rec."License Seats")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("License Expires At"; Rec."License Expires At")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("License Email"; Rec."License Email")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("License Last Verified At"; Rec."License Last Verified At")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("License Status Message"; Rec."License Status Message")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
            }
            group(AzureDirectPrint)
            {
                Caption = 'Azure Direct Print';
                field(HttpClientInstruction; HttpClientInstruction)
                {
                    Caption = 'Required Extension Setting';
                    ApplicationArea = All;
                    Editable = false;
                    MultiLine = true;
                    ToolTip = 'Azure Direct uses outbound HTTPS for Blob Storage and Service Bus.';
                }
                field("Azure Tenant Route ID"; Rec."Azure Tenant Route ID") { ApplicationArea = All; }
                field("Azure Company Route ID"; Rec."Azure Company Route ID") { ApplicationArea = All; }
                field("Azure SB Namespace"; Rec."Azure SB Namespace") { ApplicationArea = All; }
                field("Azure Print Jobs Queue"; Rec."Azure Print Jobs Queue") { ApplicationArea = All; Editable = false; }
                field("Azure Printer Status Queue"; Rec."Azure Printer Status Queue") { ApplicationArea = All; Editable = false; }
                field("Azure Jobs SAS Policy"; Rec."Azure Jobs SAS Policy") { ApplicationArea = All; Editable = false; }
                field("Azure Status SAS Policy"; Rec."Azure Status SAS Policy") { ApplicationArea = All; Editable = false; }
                field("Azure Storage Account"; Rec."Azure Storage Account") { ApplicationArea = All; }
                field("Azure Blob Container"; Rec."Azure Blob Container") { ApplicationArea = All; Editable = false; }
                field("Azure Blob Endpoint Suffix"; Rec."Azure Blob Endpoint Suffix") { ApplicationArea = All; Editable = false; }
                field("Azure SB Endpoint Suffix"; Rec."Azure SB Endpoint Suffix") { ApplicationArea = All; Editable = false; }
                field("Azure Dispatch Max Attempts"; Rec."Azure Dispatch Max Attempts") { ApplicationArea = All; }
                field("Azure Blob SAS Expires At"; Rec."Azure Blob SAS Expires At")
                {
                    ApplicationArea = All;
                    StyleExpr = BlobSasExpiryStyle;
                    ToolTip = 'UTC expiration of the Blob create/write SAS. Rotate the credential before this time; the health check warns during the final seven days.';
                }
                field(BlobUploadSecretSet; BlobUploadSecretSet)
                {
                    Caption = 'Blob Upload SAS Set';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(JobsSecretSet; JobsSecretSet)
                {
                    Caption = 'Jobs Send Key Set';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(StatusSecretSet; StatusSecretSet)
                {
                    Caption = 'Status Listen Key Set';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Azure Last Health Check"; Rec."Azure Last Health Check") { ApplicationArea = All; }
                field("Azure Last Health Result"; Rec."Azure Last Health Result") { ApplicationArea = All; }
                field(StaleDispatchedJobs; StaleDispatchedJobs)
                {
                    Caption = 'Stale Dispatched Jobs';
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Azure jobs waiting more than 8 days for an agent result. Inspect the agent outbox and Azure dead-letter queues before using the controlled retry action.';
                }
                field(UnavailableActivePrinters; UnavailableActivePrinters)
                {
                    Caption = 'Selected Printers Not Online';
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Active Azure Direct printers whose agent status is offline/error/unknown or whose heartbeat is older than 15 minutes. Jobs may still be queued durably while the workstation is offline.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            group(HierarchicalLP)
            {
                Caption = 'Hierarchical LP';
                action(SeedDkcHierarchyTemplates)
                {
                    Caption = 'Create DKC LP Templates';
                    ToolTip = 'Creates DKC-ITEM, DKC-BOX and DKC-PALLET templates after Hierarchical LP is enabled for this company.';
                    ApplicationArea = All;
                    Image = CreateDocuments;
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    var
                        HierarchyMgt: Codeunit "DOPSWHS Hierarchical LP Mgt";
                    begin
                        HierarchyMgt.SeedDkcTemplates();
                        Message('DKC-ITEM, DKC-BOX and DKC-PALLET templates are ready.');
                    end;
                }
            }
            group(DemoData)
            {
                Caption = 'Demo Data';
                action(RunDemoSetup)
                {
                    Caption = 'Run Demo Setup';
                    ToolTip = 'Tüm konfigürasyon tablolarını best-practice değerlerle doldurur (No. Series, LP Templates, Device Configs, Barcode Rules, Short Pick Reasons, IWX Report Selection, Demo Devices).';
                    ApplicationArea = All;
                    Image = Setup;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    RunObject = codeunit "DOPSWHS Demo Data Setup";
                }
                action(RunDemoTransactions)
                {
                    Caption = 'Create Demo Transactions';
                    ToolTip = '5 demo License Plate ve 1 aktif Count Sheet oluşturur. Demo Setup tamamlandıktan sonra kullanın.';
                    ApplicationArea = All;
                    Image = Inventory;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    RunObject = codeunit "DOPSWHS Demo Transactions";
                }
                action(RunDemoE2ESuite)
                {
                    Caption = 'Run Demo E2E Suite (100 tx)';
                    ToolTip = 'Tüm 10 WMS fonksiyonu (LP/Receive/PutAway/Pick/Ship/Move/Count/Quality/Production/Assembly) için 10''ar transaction çalıştırır = 100 demo transaction. Mobil app''in API ile çağırdığı aynı codeunit''ları AL üzerinden uçtan-uca koşturur. Sonuçlar Demo E2E Results sayfasında.';
                    ApplicationArea = All;
                    Image = TestFile;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    RunObject = codeunit "DOPSWHS Demo E2E Suite";
                }
                action(ShowDemoE2EResults)
                {
                    Caption = 'Show Demo E2E Results';
                    ToolTip = '100 demo transaction''ın sonuç sayfasını açar (Pass/Fail badge, durasyon, üretilen LP/dokuman).';
                    ApplicationArea = All;
                    Image = TestReport;
                    Promoted = true;
                    PromotedCategory = Process;
                    RunObject = page "DOPSWHS Demo E2E Results";
                }
            }
            group(LicenseActions)
            {
                Caption = 'License';
                action(VerifyLicense)
                {
                    Caption = 'Verify License Now';
                    ApplicationArea = All;
                    Image = ValidateEmailLoggingSetup;
                    Promoted = true;
                    PromotedCategory = Process;
                    ToolTip = 'Forces an immediate call to the licensing-service /verify endpoint and refreshes the status.';
                    trigger OnAction()
                    var
                        Mgmt: Codeunit "DOPSWHS License Mgmt";
                    begin
                        Mgmt.VerifyNow();
                        CurrPage.Update(false);
                        Message('License verification complete.');
                    end;
                }
            }
            group(PrinterBridge)
            {
                Caption = 'Printer Bridge';
                action(PrintersListAction)
                {
                    Caption = 'Printers';
                    ApplicationArea = All;
                    Image = Printer;
                    Promoted = true;
                    PromotedCategory = Process;
                    ToolTip = 'Register printers attached to local agents.';
                    RunObject = page "DOPSWHS Printer List";
                }
                action(DevicePrinterMapAction)
                {
                    Caption = 'Device Printer Mapping';
                    ApplicationArea = All;
                    Image = LinkAccount;
                    Promoted = true;
                    PromotedCategory = Process;
                    ToolTip = 'Map each device/user to a default printer per usage.';
                    RunObject = page "DOPSWHS Device Printer Map";
                }
                action(ImportAzureRuntimeConfig)
                {
                    Caption = 'Import BC Azure Print Config';
                    ApplicationArea = All;
                    Image = ImportDatabase;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    AccessByPermission = tabledata "DOPSWHS Setup" = D;
                    ToolTip = 'Imports schemaVersion 1 business-central.runtime.secrets.json. Credentials are extracted into company-scoped Isolated Storage and are never written to a table. Enable Allow HttpClient Requests for this extension first.';

                    trigger OnAction()
                    var
                        AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
                        ConfigStream: InStream;
                    begin
                        if not UploadIntoStream('JSON files (*.json)|*.json', ConfigStream) then
                            exit;
                        AzureBridge.ImportRuntimeConfiguration(ConfigStream);
                        RefreshAzureSecretIndicators();
                        CurrPage.Update(false);
                        Message('Azure Direct print configuration imported and activated. No credential was stored in a table. In Extension Management, make sure Allow HttpClient Requests is enabled for BCWMSApp, then run Validate Azure Print.');
                    end;
                }
                action(ConfigureAzureSecrets)
                {
                    Caption = 'Configure Azure Secrets';
                    ApplicationArea = All;
                    Image = EncryptionKeys;
                    AccessByPermission = tabledata "DOPSWHS Setup" = D;
                    ToolTip = 'Stores or rotates Azure credentials in company-scoped Isolated Storage. A new Blob SAS requires its expiry date from the deployment output.';

                    trigger OnAction()
                    var
                        SecretDialog: Page "DOPSWHS Azure Print Secrets";
                        AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
                    begin
                        if SecretDialog.RunModal() <> Action::OK then
                            exit;
                        AzureBridge.ConfigureSecrets(
                            SecretDialog.GetBlobUploadSas(),
                            SecretDialog.GetBlobSasExpiresAt(),
                            SecretDialog.GetJobsSharedKey(),
                            SecretDialog.GetStatusSharedKey());
                        RefreshAzureSecretIndicators();
                        CurrPage.Update(false);
                        Message('Azure print credentials were stored securely.');
                    end;
                }
                action(ClearAzureSecrets)
                {
                    Caption = 'Clear Azure Secrets';
                    ApplicationArea = All;
                    Image = ClearLog;
                    AccessByPermission = tabledata "DOPSWHS Setup" = D;

                    trigger OnAction()
                    var
                        AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
                    begin
                        if not Confirm('Clear all Azure Direct print credentials for this company?', false) then
                            exit;
                        AzureBridge.ClearSecrets();
                        RefreshAzureSecretIndicators();
                        CurrPage.Update(false);
                    end;
                }
                action(ValidateAzurePrint)
                {
                    Caption = 'Validate Azure Print';
                    ApplicationArea = All;
                    Image = TestFile;
                    AccessByPermission = tabledata "DOPSWHS Setup" = M;

                    trigger OnAction()
                    var
                        AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
                        Worker: Codeunit "DOPSWHS Azure Print Worker";
                        StaleCount: Integer;
                        UnavailableCount: Integer;
                    begin
                        AzureBridge.ValidateConfiguration(true);
                        Worker.ScheduleWorkerJob();
                        Worker.RunNow();
                        StaleCount := AzureBridge.CountStaleDispatched();
                        UnavailableCount := AzureBridge.CountUnavailableActivePrinters();
                        Rec."Azure Last Health Check" := CurrentDateTime();
                        if AzureBridge.BlobSasExpiresSoon() then
                            Rec."Azure Last Health Result" := CopyStr(
                                StrSubstNo('WARNING: Blob SAS expires at %1. Offline selected printers: %2; stale jobs: %3.', Rec."Azure Blob SAS Expires At", UnavailableCount, StaleCount),
                                1,
                                MaxStrLen(Rec."Azure Last Health Result"))
                        else
                            if UnavailableCount > 0 then
                                Rec."Azure Last Health Result" := CopyStr(
                                    StrSubstNo('WARNING: %1 selected printer(s) not online; jobs remain queued. Stale dispatched jobs: %2.', UnavailableCount, StaleCount),
                                    1,
                                    MaxStrLen(Rec."Azure Last Health Result"))
                            else
                                Rec."Azure Last Health Result" := CopyStr(
                                    StrSubstNo('Configuration valid; worker completed. Stale dispatched jobs: %1.', StaleCount),
                                    1,
                                    MaxStrLen(Rec."Azure Last Health Result"));
                        Rec.Modify(true);
                        if AzureBridge.BlobSasExpiresSoon() then
                            Message('Azure Direct configuration is valid, but the Blob SAS expires at %1. Rotate it now. Selected printers not online: %2. Stale dispatched jobs: %3.', Rec."Azure Blob SAS Expires At", UnavailableCount, StaleCount)
                        else
                            if UnavailableCount > 0 then
                                Message('Azure Direct configuration is valid. %1 selected printer(s) are not online; new jobs can still wait in Azure until the agent returns. Stale dispatched jobs: %2.', UnavailableCount, StaleCount)
                            else
                                Message('Azure Direct configuration is valid and the worker completed one cycle. Stale dispatched jobs: %1. Use a ZPL printer Test Print or a standard BC report on a PDF printer to verify Blob upload, queue send and physical output.', StaleCount);
                    end;
                }
                action(PrintJobQueueAction)
                {
                    Caption = 'Print Job Queue';
                    ApplicationArea = All;
                    Image = Queue;
                    RunObject = page "DOPSWHS Print Job Queue";
                }
            }
            group(TestScenarios)
            {
                Caption = 'Test Scenarios';
                action(GenerateAllScenarios)
                {
                    Caption = 'Generate All Test Scenarios';
                    ToolTip = 'Eldeki master data ve referansları kullanarak tüm alternatif test senaryolarını idempotent olarak yaratır (PO/SO/LP/Count). Tekrar çalıştırıldığında mevcut belgeler atlanır.';
                    ApplicationArea = All;
                    Image = CreateDocument;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    trigger OnAction()
                    var
                        Gen: Codeunit "DOPSWHS Scenario Generator";
                        Result: Text;
                    begin
                        Result := Gen.GenerateAll();
                        Message(Result);
                    end;
                }
                action(CleanupScenarios)
                {
                    Caption = 'Cleanup Generated Scenarios';
                    ToolTip = 'gen.* prefix''ine sahip tüm generated PO/SO belgelerini siler (test reset). LP ve Count Sheet''ler için manuel temizlik gerekir.';
                    ApplicationArea = All;
                    Image = ClearLog;
                    Promoted = true;
                    PromotedCategory = Process;
                    trigger OnAction()
                    var
                        Gen: Codeunit "DOPSWHS Scenario Generator";
                        DeletedCount: Integer;
                    begin
                        DeletedCount := Gen.CleanupGenerated();
                        Message('Silinen belge: %1', DeletedCount);
                    end;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        if not Rec.Get('') then begin
            Rec.Init();
            Rec.Insert(true);
        end;
        UpdateLicenseStyle();
        HttpClientInstruction := 'Required: open Extension Management, select BCWMSApp, and enable Allow HttpClient Requests before importing/testing Azure Direct.';
        RefreshAzureSecretIndicators();
    end;

    trigger OnAfterGetRecord()
    begin
        UpdateLicenseStyle();
        RefreshAzureSecretIndicators();
    end;

    var
        LicenseStyle: Text;
        BlobUploadSecretSet: Boolean;
        JobsSecretSet: Boolean;
        StatusSecretSet: Boolean;
        HttpClientInstruction: Text[250];
        StaleDispatchedJobs: Integer;
        UnavailableActivePrinters: Integer;
        BlobSasExpiryStyle: Text;

    local procedure UpdateLicenseStyle()
    begin
        case Rec."License Status" of
            Rec."License Status"::Active:
                LicenseStyle := 'Favorable';
            Rec."License Status"::Offline:
                LicenseStyle := 'Ambiguous';
            Rec."License Status"::Expired, Rec."License Status"::Invalid, Rec."License Status"::Revoked:
                LicenseStyle := 'Unfavorable';
            else
                LicenseStyle := 'Standard';
        end;
    end;

    local procedure RefreshAzureSecretIndicators()
    var
        AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
    begin
        BlobUploadSecretSet := AzureBridge.BlobSecretIsSet();
        JobsSecretSet := AzureBridge.JobsSecretIsSet();
        StatusSecretSet := AzureBridge.StatusSecretIsSet();
        StaleDispatchedJobs := AzureBridge.CountStaleDispatched();
        UnavailableActivePrinters := AzureBridge.CountUnavailableActivePrinters();
        if (Rec."Azure Blob SAS Expires At" = 0DT) or
           (Rec."Azure Blob SAS Expires At" <= CurrentDateTime())
        then
            BlobSasExpiryStyle := 'Unfavorable'
        else
            if AzureBridge.BlobSasExpiresSoon() then
                BlobSasExpiryStyle := 'Ambiguous'
            else
                BlobSasExpiryStyle := 'Favorable';
    end;
}
