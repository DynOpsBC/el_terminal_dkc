page 72095 "DOPSWHS DynOps WMS RC"
{
    Caption = 'DynOps Warehouse Management';
    PageType = RoleCenter;
    ApplicationArea = All;

    layout
    {
        area(RoleCenter)
        {
            part(Activities; "DOPSWHS DynOps WMS Activities")
            {
                ApplicationArea = All;
            }
            part(TestCenter; "DOPSWHS Test Center")
            {
                ApplicationArea = All;
            }
        }
    }

    actions
    {
        // ============================================
        // EMBED ACTIONS — burası RC içindeki "Sections" navigation menüsü
        // ============================================
        area(Sections)
        {
            group(MalKabulNav)
            {
                Caption = 'Mal Kabul';
                action(WhseReceiptsNav) { Caption = 'Açık Mal Kabul'; ApplicationArea = All; RunObject = page "Warehouse Receipts"; }
                action(ReceivingQueueNav) { Caption = 'Mal Kabul Kuyruğu'; ApplicationArea = All; RunObject = page "DOPSWHS Receiving Queue"; }
                action(POListNav) { Caption = 'Sipariş Listesi (PO)'; ApplicationArea = All; RunObject = page "Purchase Order List"; }
                action(TransferInNav) { Caption = 'Transfer Orderlar'; ApplicationArea = All; RunObject = page "Transfer Orders"; }
            }
            group(YerlestirmeNav)
            {
                Caption = 'Yerleştirme';
                action(WhsePutAwayNav) { Caption = 'Warehouse Put-Away'; ApplicationArea = All; RunObject = page "Warehouse Put-aways"; }
                action(InvtPutAwayNav) { Caption = 'Inventory Put-Away'; ApplicationArea = All; RunObject = page "Inventory Put-aways"; }
            }
            group(ToplamaNav)
            {
                Caption = 'Toplama';
                action(PickingOrdersNav) { Caption = 'Toplanacak Siparişler'; ApplicationArea = All; RunObject = page "DOPSWHS Picking Order List"; }
                action(WhsePicksNav) { Caption = 'Warehouse Picks'; ApplicationArea = All; RunObject = page "Warehouse Picks"; }
                action(InvtPicksNav) { Caption = 'Inventory Picks'; ApplicationArea = All; RunObject = page "Inventory Picks"; }
                action(PickQueueNav) { Caption = 'Pick Kuyruğu (Drag-Drop)'; ApplicationArea = All; RunObject = page "DOPSWHS Pick Queue"; }
                action(ShortPickReasonNav) { Caption = 'Short Pick Reasons'; ApplicationArea = All; RunObject = page "DOPSWHS Short Pick Reason List"; }
            }
            group(SevkiyatNav)
            {
                Caption = 'Sevkiyat';
                action(OrderPackingNav) { Caption = 'Sipariş Paketleme'; ApplicationArea = All; RunObject = page "DOPSWHS Packing Order List"; }
                action(WhseShipmentsNav) { Caption = 'Warehouse Shipments'; ApplicationArea = All; RunObject = page "Warehouse Shipment List"; }
                action(ShipmentQueueNav) { Caption = 'Sevkiyat Kuyruğu'; ApplicationArea = All; RunObject = page "DOPSWHS Shipment Queue"; }
                action(SalesOrdersNav) { Caption = 'Sales Orders'; ApplicationArea = All; RunObject = page "Sales Order List"; }
            }
            group(HareketlerNav)
            {
                Caption = 'Hareketler';
                // TODO Sprint H+ post-deploy: bind to "Warehouse Movements" once standard BC page name resolves in target symbols.
                action(WhseMovementsNav) { Caption = 'Warehouse Movements (Activity)'; ApplicationArea = All; RunObject = page "Warehouse Activity List"; }
                action(ItemReclassNav) { Caption = 'Item Reclass. Journal (Ad-Hoc)'; ApplicationArea = All; RunObject = page "Item Reclass. Journal"; }
            }
            group(UretimNav)
            {
                Caption = 'Üretim & Montaj';
                action(ReleasedProdOrdersNav) { Caption = 'Released Production Orders'; ApplicationArea = All; RunObject = page "Released Production Orders"; }
                action(AssemblyOrdersNav) { Caption = 'Assembly Orders'; ApplicationArea = All; RunObject = page "Assembly Orders"; }
            }
            group(LPNav)
            {
                Caption = 'License Plate';
                action(LPListNav) { Caption = 'LP List'; ApplicationArea = All; RunObject = page "DOPSWHS LP List"; }
                action(LPTemplateNav) { Caption = 'LP Templates'; ApplicationArea = All; RunObject = page "DOPSWHS LP Template List"; }
                action(LPMovLedgerNav) { Caption = 'LP Movement Ledger'; ApplicationArea = All; RunObject = page "DOPSWHS LP Movement Ledger"; }
            }
            group(SayimNav)
            {
                Caption = 'Sayım';
                action(CountSheetsNav) { Caption = 'Count Sheets'; ApplicationArea = All; RunObject = page "DOPSWHS Count Sheet List"; }
                action(PhysInvJournalNav) { Caption = 'Physical Inventory Journal'; ApplicationArea = All; RunObject = page "Phys. Inventory Journal"; }
            }
            group(SistemNav)
            {
                Caption = 'Sistem Yönetimi';
                action(SetupNav) { Caption = 'BCWMSApp Setup'; ApplicationArea = All; RunObject = page "DOPSWHS Setup"; }
                action(DeviceConfigNav) { Caption = 'Device Configuration'; ApplicationArea = All; RunObject = page "DOPSWHS Device Config List"; }
                action(DeviceRegistrationNav) { Caption = 'Device Registration'; ApplicationArea = All; RunObject = page "DOPSWHS Device Reg List"; }
                action(BarcodeRulesNav) { Caption = 'Barcode Rules'; ApplicationArea = All; RunObject = page "DOPSWHS Barcode Rule List"; }
                action(SymbologyNav) { Caption = 'Barcode Symbologies'; ApplicationArea = All; RunObject = page "DOPSWHS Symbology List"; }
                action(IWXReportSelNav) { Caption = 'IWX Report Selection'; ApplicationArea = All; RunObject = page "DOPSWHS IWX Report Selection"; }
                action(PrintJobLogNav) { Caption = 'Print Job Log'; ApplicationArea = All; RunObject = page "DOPSWHS Print Job Log"; }
                action(PrintersNav) { Caption = 'Printers'; ApplicationArea = All; RunObject = page "DOPSWHS Printer List"; }
                action(DevicePrinterMapNav) { Caption = 'Device Printer Mapping'; ApplicationArea = All; RunObject = page "DOPSWHS Device Printer Map"; }
                action(SyncConflictNav) { Caption = 'Sync Conflicts'; ApplicationArea = All; RunObject = page "DOPSWHS Sync Conflict List"; }
            }

            // ============================================
            // KULLANICI YÖNETİMİ — hızlı user/role ataması
            // ============================================
            group(UserMgmtGroup)
            {
                Caption = 'Kullanıcı Yönetimi';
                action(QuickUserAssignNav)
                {
                    Caption = 'Hızlı Kullanıcı Atama';
                    ApplicationArea = All;
                    RunObject = page "DOPSWHS Quick User Assign";
                    Image = AddAction;
                    ToolTip = 'Tek karttan email + rol seçip atama. Demo seed (Kaan + Deniz) shortcut da burada.';
                }
                action(AppUserRoleListNav)
                {
                    Caption = 'Atanmış Kullanıcılar';
                    ApplicationArea = All;
                    RunObject = page "DOPSWHS App User Role List";
                    Image = UserSetup;
                    ToolTip = 'Tüm WMS rol atamalarını listeler; satır ekleme/silme buradan.';
                }
                action(AppRoleListNav)
                {
                    Caption = 'Rol Kataloğu';
                    ApplicationArea = All;
                    RunObject = page "DOPSWHS App Role List";
                    Image = SetupList;
                    ToolTip = 'Mevcut WMS rollerini (INV_ADMIN, PICKER, RECEIVER, vb.) ve filter kurallarını gösterir.';
                }
                action(M365SyncNav)
                {
                    Caption = 'M365 Kullanıcı Senkronizasyonu';
                    ApplicationArea = All;
                    RunObject = page Users;
                    Image = Refresh;
                    ToolTip = 'BC standart "Users" sayfasını açar; oradan "Get users from Microsoft 365" ile yeni kullanıcı çek.';
                }
            }
        }

        // ============================================
        // SHORTCUT ACTIONS — RC üst banner'da promoted
        // ============================================
        area(Embedding)
        {
            action(NewLPShortcut)
            {
                Caption = '+ Yeni LP';
                ApplicationArea = All;
                RunObject = page "DOPSWHS LP Card";
                RunPageMode = Create;
                Image = NewItem;
            }
            action(NewCountSheetShortcut)
            {
                Caption = '+ Yeni Sayım';
                ApplicationArea = All;
                RunObject = page "DOPSWHS Count Sheet Card";
                RunPageMode = Create;
                Image = Inventory;
            }
            action(QuickMoveShortcut)
            {
                Caption = 'Hızlı Bin-to-Bin';
                ApplicationArea = All;
                RunObject = page "Item Reclass. Journal";
                Image = TransferOrder;
            }
            action(ItemInquiryShortcut)
            {
                Caption = 'Item Inquiry';
                ApplicationArea = All;
                RunObject = page "Item List";
                Image = Item;
            }
            action(BinInquiryShortcut)
            {
                Caption = 'Bin Inquiry';
                ApplicationArea = All;
                RunObject = page "Bin Contents List";
                Image = Bin;
            }
            action(SetupWizardShortcut)
            {
                Caption = 'Setup';
                ApplicationArea = All;
                RunObject = page "DOPSWHS Setup";
                Image = Setup;
            }
        }

        // ============================================
        // PROMOTED — header'da görünen ana action bar
        // ============================================
        area(Processing)
        {
            group(WmsAccess)
            {
                Caption = 'WMS Web / Mobile Bağlantısı';
                action(WMSTokenHelpAction)
                {
                    Caption = 'WMS Token Nasıl Alınır?';
                    ToolTip = 'Web tarayıcı veya mobil app için BCWMS giriş token''ı üretme adımları (az CLI, PowerShell, device-code). Komutları kopyala, çalıştır, çıkan token''ı uygulamaya yapıştır.';
                    ApplicationArea = All;
                    Image = EncryptionKeys;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    RunObject = page "DOPSWHS WMS Token Help";
                }
            }
            group(QuickActions)
            {
                Caption = 'Hızlı İşlemler';
                action(NewLPPromoted)
                {
                    Caption = '+ Yeni LP';
                    ApplicationArea = All;
                    RunObject = page "DOPSWHS LP Card";
                    RunPageMode = Create;
                    Image = NewItem;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                }
                action(NewCountSheetPromoted)
                {
                    Caption = '+ Yeni Sayım Sayfası';
                    ApplicationArea = All;
                    RunObject = page "DOPSWHS Count Sheet Card";
                    RunPageMode = Create;
                    Image = Inventory;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                }
                action(QuickMovePromoted)
                {
                    Caption = 'Hızlı Bin-to-Bin Hareket';
                    ApplicationArea = All;
                    RunObject = page "Item Reclass. Journal";
                    Image = TransferOrder;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                }
                action(ItemInquiryPromoted)
                {
                    Caption = 'Item Inquiry';
                    ApplicationArea = All;
                    RunObject = page "Item List";
                    Image = Item;
                    Promoted = true;
                    PromotedCategory = Process;
                }
                action(BinInquiryPromoted)
                {
                    Caption = 'Bin Inquiry';
                    ApplicationArea = All;
                    RunObject = page "Bin Contents List";
                    Image = Bin;
                    Promoted = true;
                    PromotedCategory = Process;
                }
            }
            group(TestCenterActions)
            {
                Caption = 'Test Center';
                action(SetupTestCatalog)
                {
                    Caption = 'Setup Test Catalog';
                    ToolTip = '50 Test Case + 5 Environment + 3 User Group seed (idempotent).';
                    ApplicationArea = All;
                    Image = Setup;
                    Promoted = true;
                    PromotedCategory = Category5;
                    PromotedIsBig = true;
                    RunObject = codeunit "DOPSWHS Test Catalog Seed";
                }
                action(SetupE2ETestData)
                {
                    Caption = 'Setup E2E Test Data';
                    ToolTip = 'Cronus uzerinde eksik master data (test item, lot, prod, BOM) auto-create.';
                    ApplicationArea = All;
                    Image = TestDatabase;
                    Promoted = true;
                    PromotedCategory = Category5;
                    PromotedIsBig = true;
                    RunObject = codeunit "DOPSWHS E2E Test Data";
                }
                action(OpenTestRunList)
                {
                    Caption = 'Test Run List';
                    ApplicationArea = All;
                    Image = List;
                    Promoted = true;
                    PromotedCategory = Category5;
                    PromotedIsBig = true;
                    RunObject = page "DOPSWHS Test Run List";
                }
                action(OpenTestCaseList)
                {
                    Caption = 'Test Case Catalog';
                    ApplicationArea = All;
                    Image = ItemAttribute;
                    Promoted = true;
                    PromotedCategory = Category5;
                    RunObject = page "DOPSWHS Test Case List";
                }
                action(OpenEnvList)
                {
                    Caption = 'Environments';
                    ApplicationArea = All;
                    Image = Setup;
                    Promoted = true;
                    PromotedCategory = Category5;
                    RunObject = page "DOPSWHS Test Environment List";
                }
                action(OpenGroupList)
                {
                    Caption = 'User Groups';
                    ApplicationArea = All;
                    Image = UserGroup;
                    Promoted = true;
                    PromotedCategory = Category5;
                    RunObject = page "DOPSWHS Test User Group List";
                }
            }
            group(DemoActions)
            {
                Caption = 'Demo Data (Danışman Modu)';
                action(RunDemoSetupRC)
                {
                    Caption = 'Run Demo Setup';
                    ToolTip = 'Tüm konfigürasyon tablolarını best-practice değerlerle doldur (idempotent).';
                    ApplicationArea = All;
                    Image = Setup;
                    Promoted = true;
                    PromotedCategory = Category5;
                    PromotedIsBig = true;
                    RunObject = codeunit "DOPSWHS Demo Data Setup";
                }
                action(CreateDemoTransactionsRC)
                {
                    Caption = 'Create Demo Transactions';
                    ToolTip = '5 demo LP + 1 aktif Count Sheet oluştur. Setup tamamlandıktan sonra çalıştır.';
                    ApplicationArea = All;
                    Image = Inventory;
                    Promoted = true;
                    PromotedCategory = Category5;
                    PromotedIsBig = true;
                    RunObject = codeunit "DOPSWHS Demo Transactions";
                }
            }
            group(SetupActions)
            {
                Caption = 'Yapılandırma';
                action(SetupPromoted)
                {
                    Caption = 'BCWMSApp Setup';
                    ApplicationArea = All;
                    RunObject = page "DOPSWHS Setup";
                    Image = Setup;
                    Promoted = true;
                    PromotedCategory = Category4;
                }
                action(BarcodeRulesPromoted)
                {
                    Caption = 'Barcode Rules';
                    ApplicationArea = All;
                    RunObject = page "DOPSWHS Barcode Rule List";
                    Image = BarCode;
                    Promoted = true;
                    PromotedCategory = Category4;
                }
                action(DeviceConfigPromoted)
                {
                    Caption = 'Device Configuration';
                    ApplicationArea = All;
                    RunObject = page "DOPSWHS Device Config List";
                    Image = Setup;
                    Promoted = true;
                    PromotedCategory = Category4;
                }
                action(LPTemplatesPromoted)
                {
                    Caption = 'LP Templates';
                    ApplicationArea = All;
                    RunObject = page "DOPSWHS LP Template List";
                    Image = Template;
                    Promoted = true;
                    PromotedCategory = Category4;
                }
            }
        }
    }
}
