codeunit 72058 "DOPSWHS Demo Data Setup"
{
    // Consultant-grade setup helper: tüm konfigürasyon tablolarını best-practice
    // değerlerle doldurur. Idempotent — birden fazla kez çağrılabilir.
    Access = Public;

    trigger OnRun()
    begin
        RunFullDemoSetup();
    end;

    procedure RunFullDemoSetup()
    var
        SetupWizard: Codeunit "DOPSWHS Setup Wizard";
        Msg: Label 'Demo setup tamamlandı.\n\n• No. Series\n• Setup row default değerlerle\n• Symbology + Barcode Rules\n• LP Templates (extended)\n• Device Configurations (5 rol)\n• Short Pick Reasons (extended)\n• IWX Report Selection\n• Demo Devices (3)\n\nRole Center artık veriyle dolu.';
    begin
        EnsureNumberSeries();
        EnsureSetupRow();
        SetupWizard.SeedSprint1Defaults();
        SeedExtendedLPTemplates();
        SeedExtendedBarcodeRules();
        SeedRoleBasedDeviceConfigs();
        SeedExtendedShortPickReasons();
        SeedExtendedIwxReports();
        SeedDeviceMenusFull();
        SeedDemoDevices();
        Message(Msg);
    end;

    procedure EnsureNumberSeries()
    begin
        EnsureNoSeries('AWMS-LP', 'LP Numbering', 'LP000001', 'LP999999');
        EnsureNoSeries('AWMS-SSCC', 'SSCC Numbering', '0000000001', '9999999999');
        EnsureNoSeries('AWMS-CNT', 'Count Sheet Numbering', 'CS00001', 'CS99999');
        EnsureNoSeries('AWMS-DEV', 'Device Numbering', 'DEV001', 'DEV999');
    end;

    local procedure EnsureNoSeries(Code: Code[20]; Description: Text[100]; StartNo: Code[20]; EndNo: Code[20])
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        if not NoSeries.Get(Code) then begin
            NoSeries.Init();
            NoSeries."Code" := Code;
            NoSeries.Description := Description;
            NoSeries."Default Nos." := true;
            NoSeries."Manual Nos." := true;
            NoSeries.Insert(true);
        end;
        if not NoSeriesLine.Get(Code, 10000) then begin
            NoSeriesLine.Init();
            NoSeriesLine."Series Code" := Code;
            NoSeriesLine."Line No." := 10000;
            NoSeriesLine."Starting No." := StartNo;
            NoSeriesLine."Ending No." := EndNo;
            NoSeriesLine."Increment-by No." := 1;
            NoSeriesLine."Starting Date" := 0D;
            NoSeriesLine.Insert(true);
        end;
    end;

    procedure EnsureSetupRow()
    var
        Setup: Record "DOPSWHS Setup";
        Location: Record Location;
        DefaultLocationCode: Code[10];
    begin
        if not Setup.Get('') then begin
            Setup.Init();
            Setup."Primary Key" := '';
            Setup.Insert(true);
        end;

        if Setup."LP No. Series" = '' then
            Setup."LP No. Series" := 'AWMS-LP';
        if Setup."SSCC No. Series" = '' then
            Setup."SSCC No. Series" := 'AWMS-SSCC';
        if Setup."GS1 Company Prefix" = '' then
            Setup."GS1 Company Prefix" := '9999999';
        if Setup."Default Location Code" = '' then begin
            Location.SetRange("Bin Mandatory", true);
            if Location.FindFirst() then
                DefaultLocationCode := Location.Code
            else begin
                Location.Reset();
                if Location.FindFirst() then
                    DefaultLocationCode := Location.Code;
            end;
            Setup."Default Location Code" := DefaultLocationCode;
        end;
        Setup."Print Channel" := Setup."Print Channel"::BCNative;
        Setup.Modify(true);
    end;

    local procedure SeedExtendedLPTemplates()
    var
        Template: Record "DOPSWHS LP Template";
    begin
        AddTemplate(Template, 'CARTON-L', 'Large carton', 60, 40, 30, 40);
        AddTemplate(Template, 'PALLET-US', 'US pallet (48x40)', 122, 102, 120, 1100);
        AddTemplate(Template, 'TOTE-B', 'Tote B mini', 30, 20, 18, 12);
    end;

    local procedure AddTemplate(var Template: Record "DOPSWHS LP Template"; Code: Code[20]; Description: Text[100]; LengthCm: Decimal; WidthCm: Decimal; HeightCm: Decimal; MaxWeightKg: Decimal)
    begin
        if Template.Get(Code) then
            exit;
        Template.Init();
        Template."Code" := Code;
        Template.Description := Description;
        Template."Default Length cm" := LengthCm;
        Template."Default Width cm" := WidthCm;
        Template."Default Height cm" := HeightCm;
        Template."Max Weight kg" := MaxWeightKg;
        Template."Label Report ID" := Report::"DOPSWHS LP Label";
        Template."Allow Mixed Items" := true;
        Template."Allow Mixed Lots" := true;
        Template.Insert(true);
    end;

    local procedure SeedExtendedBarcodeRules()
    var
        Rule: Record "DOPSWHS Barcode Rule";
    begin
        AddRule(Rule, 'ITEM-NO', 'Direct item no scan', 'CODE128', '^ITEM-(?<itemno>[A-Z0-9\-]+)$', '{"itemno":"itemno"}', Rule."Maps To"::Item, 60);
        AddRule(Rule, 'BIN-CODE', 'Direct bin code scan (no prefix)', 'CODE128', '^(?<bin>[A-Z]\d{2}-\d{2}-\d{2})$', '{"bin":"bin"}', Rule."Maps To"::Bin, 70);
        AddRule(Rule, 'LP-DIRECT', 'Direct LP No (LP000123)', 'CODE128', '^(?<lp>LP\d{6})$', '{"lp":"lp"}', Rule."Maps To"::LP, 80);
    end;

    local procedure AddRule(var Rule: Record "DOPSWHS Barcode Rule"; Code: Code[30]; Description: Text[100]; Symbology: Code[20]; Regex: Text[250]; CaptureMapJson: Text[2048]; MapsTo: Enum "DOPSWHS Barcode Map Target"; SortOrder: Integer)
    begin
        if Rule.Get(Code) then
            exit;
        Rule.Init();
        Rule."Code" := Code;
        Rule.Description := Description;
        Rule.Symbology := Symbology;
        Rule.Regex := Regex;
        Rule."Capture Map JSON" := CaptureMapJson;
        Rule."Maps To" := MapsTo;
        Rule."Order" := SortOrder;
        Rule.Active := true;
        Rule.Insert(true);
    end;

    local procedure SeedRoleBasedDeviceConfigs()
    var
        DeviceConfig: Record "DOPSWHS Device Configuration";
    begin
        AddDeviceConfig(DeviceConfig, 'RECEIVER', 'Mal Kabul operatörü', DeviceConfig."LP Usage Default Action"::CreateNewLP);
        AddDeviceConfig(DeviceConfig, 'PUTAWAY', 'Yerleştirme operatörü', DeviceConfig."LP Usage Default Action"::CreateNewLP);
        AddDeviceConfig(DeviceConfig, 'PICKER', 'Toplama operatörü', DeviceConfig."LP Usage Default Action"::CreateNewLP);
        AddDeviceConfig(DeviceConfig, 'SHIPPER', 'Sevkiyat operatörü', DeviceConfig."LP Usage Default Action"::Unbuild);
        AddDeviceConfig(DeviceConfig, 'COUNTER', 'Sayım operatörü', DeviceConfig."LP Usage Default Action"::RemoveExcess);
        AddDeviceConfig(DeviceConfig, 'PROD-OP', 'Üretim/Montaj operatörü', DeviceConfig."LP Usage Default Action"::Unbuild);
    end;

    local procedure AddDeviceConfig(var DeviceConfig: Record "DOPSWHS Device Configuration"; Code: Code[20]; Description: Text[100]; PartialUseDefault: Enum "DOPSWHS Partial Use Action")
    var
        Setup: Record "DOPSWHS Setup";
    begin
        if DeviceConfig.Get(Code) then
            exit;
        Setup.Get('');
        DeviceConfig.Init();
        DeviceConfig."Code" := Code;
        DeviceConfig.Description := Description;
        DeviceConfig."Location Code" := Setup."Default Location Code";
        DeviceConfig."Login Mode" := DeviceConfig."Login Mode"::SSO;
        DeviceConfig."Assign Document On Open" := true;
        DeviceConfig."LP Usage Default Action" := PartialUseDefault;
        DeviceConfig."Max List Rows" := 100;
        DeviceConfig."Scan Beep" := true;
        DeviceConfig."Print Channel" := DeviceConfig."Print Channel"::BCNative;
        DeviceConfig.Insert(true);
    end;

    local procedure SeedExtendedShortPickReasons()
    var
        Reason: Record "DOPSWHS Short Pick Reason";
    begin
        AddReason(Reason, 'BIN_BLOCKED', 'Bin geçici olarak bloke', false, true);
        AddReason(Reason, 'COUNTING', 'Bin sayım sırasında', false, true);
    end;

    local procedure AddReason(var Reason: Record "DOPSWHS Short Pick Reason"; Code: Code[20]; Description: Text[100]; IsDefault: Boolean; AllowsBackorder: Boolean)
    begin
        if Reason.Get(Code) then
            exit;
        Reason.Init();
        Reason."Code" := Code;
        Reason.Description := Description;
        Reason.Default := IsDefault;
        Reason."Allows Backorder" := AllowsBackorder;
        Reason.Insert(true);
    end;

    local procedure SeedExtendedIwxReports()
    var
        ReportSelection: Record "DOPSWHS IWX Report Selection";
    begin
        AddReportSelection(ReportSelection, 'LP-LABEL', ReportSelection.Usage::LpLabel, Report::"DOPSWHS LP Label", 10);
        AddReportSelection(ReportSelection, 'PICK-CONF', ReportSelection.Usage::Pick, 7340, 20);
        AddReportSelection(ReportSelection, 'RECEIPT-POSTED', ReportSelection.Usage::Receipt, 7308, 30);
    end;

    local procedure AddReportSelection(var ReportSelection: Record "DOPSWHS IWX Report Selection"; Code: Code[20]; Usage: Enum "DOPSWHS IWX Report Usage"; ReportId: Integer; Sequence: Integer)
    begin
        if ReportSelection.Get(Code) then
            exit;
        ReportSelection.Init();
        ReportSelection."Code" := Code;
        ReportSelection.Usage := Usage;
        ReportSelection."Report ID" := ReportId;
        ReportSelection.Sequence := Sequence;
        ReportSelection.Insert(true);
    end;

    local procedure SeedDeviceMenusFull()
    var
        Module: Enum "DOPSWHS Application Module";
    begin
        AddMenuEntry('RECEIVER', Module::Receive, 'RECV-DOC-LIST', 10);
        AddMenuEntry('RECEIVER', Module::ItemInquiry, 'ITEM-INQ', 20);
        AddMenuEntry('RECEIVER', Module::BinInquiry, 'BIN-INQ', 30);
        AddMenuEntry('PUTAWAY', Module::PutAway, 'PUTAWAY-LIST', 10);
        AddMenuEntry('PUTAWAY', Module::BinInquiry, 'BIN-INQ', 20);
        AddMenuEntry('PICKER', Module::Pick, 'PICK-LIST', 10);
        AddMenuEntry('PICKER', Module::LP, 'LP-MGMT', 20);
        AddMenuEntry('PICKER', Module::ItemInquiry, 'ITEM-INQ', 30);
        AddMenuEntry('SHIPPER', Module::Ship, 'SHIP-LIST', 10);
        AddMenuEntry('COUNTER', Module::Count, 'COUNT-LIST', 10);
        AddMenuEntry('PROD-OP', Module::ProductionConsumption, 'PROD-CONSUME', 10);
        AddMenuEntry('PROD-OP', Module::ProductionOutput, 'PROD-OUTPUT', 20);
        AddMenuEntry('PROD-OP', Module::Assembly, 'ASSEMBLY', 30);
    end;

    local procedure AddMenuEntry(ConfigCode: Code[20]; Module: Enum "DOPSWHS Application Module"; MenuItem: Code[30]; SortOrder: Integer)
    var
        DeviceMenu: Record "DOPSWHS Device Menu";
    begin
        if DeviceMenu.Get(ConfigCode, MenuItem) then
            exit;
        DeviceMenu.Init();
        DeviceMenu."Config Code" := ConfigCode;
        DeviceMenu."Application Module" := Module;
        DeviceMenu."Menu Item" := MenuItem;
        DeviceMenu."Sort Order" := SortOrder;
        DeviceMenu.Visible := true;
        DeviceMenu.Insert(true);
    end;

    local procedure SeedDemoDevices()
    begin
        RegisterDemoDevice('ZEBRA-TC22-001', 'Zebra TC22 Demo Cihaz #1', 'RECEIVER');
        RegisterDemoDevice('HONEYWELL-CT45-001', 'Honeywell CT45 Demo Cihaz', 'PICKER');
        RegisterDemoDevice('CAMERA-PHONE-001', 'Kamera tarayıcı (Android telefon)', 'COUNTER');
    end;

    local procedure RegisterDemoDevice(DeviceId: Code[40]; Description: Text[100]; ConfigCode: Code[20])
    var
        Device: Record "DOPSWHS Device Registration";
    begin
        if Device.Get(DeviceId) then
            exit;
        Device.Init();
        Device."Device ID" := DeviceId;
        Device."Fingerprint" := DeviceId + ' | ' + Description;
        Device."App Version" := '1.0.1.0';
        Device."Last Seen DateTime" := CurrentDateTime();
        Device.Active := true;
        Device."Config Code" := ConfigCode;
        Device.Insert(true);
    end;
}
