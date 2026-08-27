codeunit 72031 "DOPSWHS Setup Wizard"
{
    Access = Public;

    // TODO Sprint H+ post-deploy: resubscribe to Assisted Setup when the target BC app exposes codeunit 3725 symbols.
    /*
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Assisted Setup", 'OnRegister', '', false, false)]
    local procedure OnRegisterAssistedSetup()
    var
        AssistedSetup: Codeunit "Assisted Setup";
        AssistedSetupGroup: Enum "Assisted Setup Group";
        VideoCategory: Enum "Video Category";
    begin
        AssistedSetup.Add(
            GetAppId(),
            Page::"DOPSWHS Setup",
            'Set up Advanced WMS',
            AssistedSetupGroup::Extensions,
            '',
            VideoCategory::Uncategorized,
            'Configure license plate, SSCC, location, and print settings.');
    end;
    */

    local procedure GetAppId(): Guid
    begin
        exit('984e25aa-07c2-4401-babc-88f975303a52');
    end;

    procedure SeedSprint1Defaults()
    begin
        SeedDeviceConfig();
        SeedSymbologies();
        SeedBarcodeRules();
        SeedDefaultLPTemplates();
        SeedShortPickReasons();
        SeedReportSelections();
        // SubscribeDefaultWebhooks is intentionally NOT called here on a
        // fresh install — webhook publish is license-gated. Wiring it up
        // would fail with `GuardFeature(WebhookPublish)` during the
        // OnInstallAppPerCompany trigger before any License Key is set,
        // crashing the install. The customer admin must enter the License
        // Key first; webhook subscription is then triggered automatically
        // on the next license verify cycle.
    end;

    local procedure SeedDeviceConfig()
    var
        DeviceConfig: Record "DOPSWHS Device Configuration";
        DeviceMenu: Record "DOPSWHS Device Menu";
    begin
        if not DeviceConfig.Get('DEFAULT') then begin
            DeviceConfig.Init();
            DeviceConfig."Code" := 'DEFAULT';
            DeviceConfig.Description := 'Default handheld profile';
            DeviceConfig."Login Mode" := DeviceConfig."Login Mode"::SSO;
            DeviceConfig."Assign Document On Open" := true;
            DeviceConfig."LP Usage Default Action" := DeviceConfig."LP Usage Default Action"::CreateNewLP;
            DeviceConfig."Max List Rows" := 100;
            DeviceConfig."Scan Beep" := true;
            DeviceConfig."Print Channel" := DeviceConfig."Print Channel"::BCNative;
            DeviceConfig.Insert(true);
        end;

        SeedMenu(DeviceMenu, 'DEFAULT', DeviceMenu."Application Module"::ItemInquiry, 'ITEM-INQUIRY', 10);
        SeedMenu(DeviceMenu, 'DEFAULT', DeviceMenu."Application Module"::BinInquiry, 'BIN-INQUIRY', 20);
        SeedMenu(DeviceMenu, 'DEFAULT', DeviceMenu."Application Module"::Configuration, 'CONFIG', 90);
    end;

    local procedure SeedMenu(var DeviceMenu: Record "DOPSWHS Device Menu"; ConfigCode: Code[20]; Module: Enum "DOPSWHS Application Module"; MenuItem: Code[30]; SortOrder: Integer)
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

    local procedure SeedSymbologies()
    var
        Symbology: Record "DOPSWHS Barcode Symbology";
    begin
        SeedSymbology(Symbology, 'EAN13', 'EAN-13 item reference', Symbology.Format::EAN13, 13, 13);
        SeedSymbology(Symbology, 'GS1-128', 'GS1-128 application identifiers', Symbology.Format::GS1128, 16, 80);
        SeedSymbology(Symbology, 'SSCC-18', 'SSCC-18 license plate code', Symbology.Format::SSCC18, 22, 22);
        SeedSymbology(Symbology, 'CODE128', 'Code 128 warehouse labels', Symbology.Format::Code128, 1, 80);
    end;

    local procedure SeedSymbology(var Symbology: Record "DOPSWHS Barcode Symbology"; Code: Code[20]; Description: Text[100]; Format: Enum "DOPSWHS Symbology"; MinLength: Integer; MaxLength: Integer)
    begin
        if Symbology.Get(Code) then
            exit;

        Symbology.Init();
        Symbology."Code" := Code;
        Symbology.Description := Description;
        Symbology.Format := Format;
        Symbology."Min Length" := MinLength;
        Symbology."Max Length" := MaxLength;
        Symbology.Insert(true);
    end;

    local procedure SeedBarcodeRules()
    var
        Rule: Record "DOPSWHS Barcode Rule";
    begin
        SeedRule(Rule, 'EAN13-ITEM', 'EAN-13 item reference', 'EAN13', '^\d{13}$', '{"itemReference":"$0"}', Rule."Maps To"::Item, 10);
        SeedRule(Rule, 'GS1-128-FULL', 'GS1-128 GTIN/lot/expiry/serial', 'GS1-128', '^\(01\)(?<gtin>\d{14})(\(10\)(?<lot>[A-Za-z0-9\-]+))?(\(17\)(?<exp>\d{6}))?(\(21\)(?<sn>[A-Za-z0-9\-]+))?$', '{"gtin":"gtin","lot":"lot","exp":"exp","sn":"sn"}', Rule."Maps To"::Item, 20);
        SeedRule(Rule, 'SSCC-18', 'SSCC-18 license plate', 'SSCC-18', '^\(00\)(\d{18})$', '{"sscc":"1"}', Rule."Maps To"::LP, 30);
        SeedRule(Rule, 'BIN-PREFIX', 'Bin barcode prefix', 'CODE128', '^B-(?<bin>[\w-]+)$', '{"bin":"bin"}', Rule."Maps To"::Bin, 40);
        SeedRule(Rule, 'LP-TEMPLATE', 'LP template barcode prefix', 'CODE128', '^TPL-(?<tpl>[\w-]+)$', '{"tpl":"tpl"}', Rule."Maps To"::LpTemplate, 50);
    end;

    procedure SeedDefaultLPTemplates()
    var
        Template: Record "DOPSWHS LP Template";
    begin
        SeedLPTemplate(Template, 'CARTON-S', 'Small carton', 30, 20, 15, 15);
        SeedLPTemplate(Template, 'CARTON-M', 'Medium carton', 40, 30, 20, 25);
        SeedLPTemplate(Template, 'PALLET-EUR', 'Euro pallet', 120, 80, 120, 1000);
        SeedLPTemplate(Template, 'TOTE-A', 'Tote A', 50, 35, 30, 30);
    end;

    local procedure SeedLPTemplate(var Template: Record "DOPSWHS LP Template"; Code: Code[20]; Description: Text[100]; LengthCm: Decimal; WidthCm: Decimal; HeightCm: Decimal; MaxWeightKg: Decimal)
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

    local procedure SeedRule(var Rule: Record "DOPSWHS Barcode Rule"; Code: Code[30]; Description: Text[100]; Symbology: Code[20]; Regex: Text[250]; CaptureMapJson: Text[2048]; MapsTo: Enum "DOPSWHS Barcode Map Target"; SortOrder: Integer)
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

    local procedure SeedShortPickReasons()
    var
        Reason: Record "DOPSWHS Short Pick Reason";
    begin
        SeedShortPickReason(Reason, 'NO_STOCK', 'No stock available', true, true);
        SeedShortPickReason(Reason, 'DAMAGED', 'Damaged inventory', false, false);
        SeedShortPickReason(Reason, 'EXPIRED', 'Expired inventory', false, false);
        SeedShortPickReason(Reason, 'MISSING', 'Inventory missing from bin', false, false);
        SeedShortPickReason(Reason, 'LOT_NOT_FOUND', 'Expected lot was not found', false, false);
    end;

    local procedure SeedShortPickReason(var Reason: Record "DOPSWHS Short Pick Reason"; Code: Code[20]; Description: Text[100]; IsDefault: Boolean; AllowsBackorder: Boolean)
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

    procedure SeedReportSelections()
    begin
        SeedReportSelection('POSTED-SHIP', Enum::"DOPSWHS IWX Report Usage"::PostedShipment, 10, 7309, 7321);
        SeedReportSelection('RECEIPT-POSTED', Enum::"DOPSWHS IWX Report Usage"::Receipt, 20, 7308, 7318);
        SeedReportSelection('PACK-RECEIPT', Enum::"DOPSWHS IWX Report Usage"::PackReceipt, 30, 1306, 0);
    end;

    local procedure SeedReportSelection(Code: Code[20]; Usage: Enum "DOPSWHS IWX Report Usage"; Sequence: Integer; ReportId: Integer; LegacyReportId: Integer)
    var
        ReportSelection: Record "DOPSWHS IWX Report Selection";
    begin
        if ReportSelection.Get(Code) then begin
            // Preserve customer-selected reports. Only repair an empty value or
            // one of the known incorrect IDs shipped by an older seed.
            if (ReportSelection."Report ID" = 0) or
               ((LegacyReportId <> 0) and (ReportSelection."Report ID" = LegacyReportId))
            then begin
                ReportSelection.Usage := Usage;
                ReportSelection.Sequence := Sequence;
                ReportSelection."Report ID" := ReportId;
                ReportSelection.Modify(true);
            end;
            exit;
        end;
        ReportSelection.Init();
        ReportSelection."Code" := Code;
        ReportSelection.Usage := Usage;
        ReportSelection.Sequence := Sequence;
        ReportSelection."Report ID" := ReportId;
        ReportSelection.Insert(true);
    end;

    local procedure SubscribeDefaultWebhooks()
    var
        Setup: Record "DOPSWHS Setup";
        WebhookMgmt: Codeunit "DOPSWHS Webhook Mgmt";
        Endpoint: Text[250];
    begin
        Endpoint := 'https://placeholder.invalid/api/webhook';
        if Setup.Get('') then
            if Setup."Webhook Endpoint" <> '' then
                Endpoint := Setup."Webhook Endpoint";

        WebhookMgmt.SubscribeWebhooks(Endpoint);
    end;

    /// <summary>
    /// Public entry called by `LicenseMgmt.OnFirstActivation`. Same wiring as
    /// the private install-time helper but only invoked once the license is
    /// active so the WebhookPublish guard passes.
    /// </summary>
    procedure SubscribeDefaultWebhooksAfterLicense()
    begin
        SubscribeDefaultWebhooks();
    end;
}
