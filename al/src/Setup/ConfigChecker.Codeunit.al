codeunit 72260 "DOPSWHS Config Checker"
{
    // Drives the Assisted Setup "Configuration Check": evaluates each WMS configuration item live
    // (OK / Warning / Missing) and auto-fixes the ones it can. Idempotent.
    Access = Public;

    /// <summary>Seeds the checklist rows and registers the page in BC's Assisted Setup list.</summary>
    procedure RegisterAssistedSetup()
    var
        GuidedExperience: Codeunit "Guided Experience";
    begin
        RefreshChecks();
        GuidedExperience.InsertAssistedSetup(
            'DynOps WMS Configuration Check', 'WMS Config Check',
            'WMS yapılandırma maddelerini tek tek denetler ve otomatik düzeltilebilenleri uygular.',
            5, ObjectType::Page, Page::"DOPSWHS Config Check",
            "Assisted Setup Group"::ReadyForBusiness, '', "Video Category"::Uncategorized, '');
    end;

    procedure RefreshChecks()
    var
        ConfigCheck: Record "DOPSWHS Config Check";
        Status: Option NotChecked,OK,Warning,Missing;
        Detail: Text;
    begin
        EvalPackageNos(Status, Detail);
        Upsert('PKG-NOS', 10, 'Package Nos. (Inventory Setup)', false, true, Status, Detail);

        EvalItemTrackingCode(Status, Detail);
        Upsert('PKG-ITC', 20, 'LP package Item Tracking Code', false, true, Status, Detail);

        EvalWarehouseEmployee(Status, Detail);
        Upsert('WHSE-EMP', 30, 'Warehouse Employee (current user)', true, true, Status, Detail);

        EvalDefaultLocation(Status, Detail);
        Upsert('DEF-LOC', 40, 'Default location + bins', true, true, Status, Detail);

        EvalNumberSeries(Status, Detail);
        Upsert('NO-SERIES', 50, 'DOPSWHS number series', true, true, Status, Detail);

        EvalWebServices(Status, Detail);
        Upsert('WEB-SVC', 60, 'Web service pages published', true, false, Status, Detail);

        EvalAppProfile(Status, Detail);
        Upsert('APP-PROFILE', 70, 'WMS App User Profile (current user)', true, true, Status, Detail);

        // PKG-NOS / PKG-ITC become auto-fixable too (set after eval so the flag is accurate).
        if ConfigCheck.Get('PKG-NOS') then begin ConfigCheck."Auto Fixable" := true; ConfigCheck.Modify(); end;
        if ConfigCheck.Get('PKG-ITC') then begin ConfigCheck."Auto Fixable" := true; ConfigCheck.Modify(); end;
    end;

    /// <summary>Auto-fixes one check by code (where supported), then returns the refreshed status.</summary>
    procedure FixByCode(CheckCode: Code[20])
    begin
        case CheckCode of
            'PKG-NOS':
                FixPackageNos();
            'PKG-ITC':
                FixItemTrackingCode();
            'WHSE-EMP':
                FixWarehouseEmployee();
            'DEF-LOC':
                FixDefaultLocationBins();
            'NO-SERIES':
                FixNumberSeries();
            'WEB-SVC':
                FixWebServices();
            'APP-PROFILE':
                FixAppProfile();
        end;
        RefreshChecks();
    end;

    /// <summary>Auto-fixes every Missing/Warning check that is auto-fixable.</summary>
    procedure FixAll()
    var
        ConfigCheck: Record "DOPSWHS Config Check";
    begin
        RefreshChecks();
        ConfigCheck.SetRange("Auto Fixable", true);
        ConfigCheck.SetFilter("Status", '%1|%2', ConfigCheck."Status"::Missing, ConfigCheck."Status"::Warning);
        if ConfigCheck.FindSet() then
            repeat
                RunFix(ConfigCheck."Code");
            until ConfigCheck.Next() = 0;
        RefreshChecks();
    end;

    local procedure RunFix(CheckCode: Code[20])
    begin
        case CheckCode of
            'PKG-NOS':
                FixPackageNos();
            'PKG-ITC':
                FixItemTrackingCode();
            'WHSE-EMP':
                FixWarehouseEmployee();
            'DEF-LOC':
                FixDefaultLocationBins();
            'NO-SERIES':
                FixNumberSeries();
            'WEB-SVC':
                FixWebServices();
            'APP-PROFILE':
                FixAppProfile();
        end;
    end;

    // ============================ Evaluations ============================

    local procedure EvalPackageNos(var Status: Option NotChecked,OK,Warning,Missing; var Detail: Text)
    var
        InventorySetup: Record "Inventory Setup";
    begin
        if InventorySetup.FindFirst() and (InventorySetup."Package Nos." <> '') then begin
            Status := Status::OK;
            Detail := StrSubstNo('Package no. series: %1', InventorySetup."Package Nos.");
        end else begin
            Status := Status::Missing;
            Detail := 'Inventory Setup Package Nos. atanmamış. (Standart BC package tracking için gerekli.)';
        end;
    end;

    local procedure EvalItemTrackingCode(var Status: Option NotChecked,OK,Warning,Missing; var Detail: Text)
    var
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        ItemTrackingCode.SetRange("Package Specific Tracking", true);
        if not ItemTrackingCode.IsEmpty() then begin
            Status := Status::OK;
            ItemTrackingCode.FindFirst();
            Detail := StrSubstNo('Package-tracking Item Tracking Code mevcut: %1', ItemTrackingCode.Code);
        end else begin
            Status := Status::Missing;
            Detail := 'Package tracking açık bir Item Tracking Code yok (LP item''larına atanacak).';
        end;
    end;

    local procedure EvalWarehouseEmployee(var Status: Option NotChecked,OK,Warning,Missing; var Detail: Text)
    var
        WhseEmployee: Record "Warehouse Employee";
    begin
        WhseEmployee.SetRange("User ID", CopyStr(UserId(), 1, 50));
        if not WhseEmployee.IsEmpty() then begin
            Status := Status::OK;
            Detail := StrSubstNo('%1, %2 lokasyonda warehouse employee.', UserId(), WhseEmployee.Count());
        end else begin
            Status := Status::Missing;
            Detail := StrSubstNo('%1 hiçbir lokasyonda warehouse employee değil (warehouse sayfaları/OData engellenir).', UserId());
        end;
    end;

    local procedure EvalDefaultLocation(var Status: Option NotChecked,OK,Warning,Missing; var Detail: Text)
    var
        Setup: Record "DOPSWHS Setup";
        Bin: Record Bin;
    begin
        if not Setup.Get('') then begin
            Status := Status::Warning;
            Detail := 'DOPSWHS Setup kaydı yok.';
            exit;
        end;
        if Setup."Default Location Code" = '' then begin
            Status := Status::Warning;
            Detail := 'Default Location Code boş — manuel atayın.';
            exit;
        end;
        Bin.SetRange("Location Code", Setup."Default Location Code");
        Bin.SetFilter(Code, 'PICK-01|RECEIVE-1|BULK-01|SHIP-01');
        if Bin.Count() >= 4 then begin
            Status := Status::OK;
            Detail := StrSubstNo('Default lokasyon %1, WMS bin''leri mevcut.', Setup."Default Location Code");
        end else begin
            Status := Status::Warning;
            Detail := StrSubstNo('Default lokasyon %1 ama WMS bin''leri eksik (%2/4).', Setup."Default Location Code", Bin.Count());
        end;
    end;

    local procedure EvalNumberSeries(var Status: Option NotChecked,OK,Warning,Missing; var Detail: Text)
    var
        NoSeries: Record "No. Series";
    begin
        if NoSeries.Get('AWMS-LP') and NoSeries.Get('AWMS-SSCC') then begin
            Status := Status::OK;
            Detail := 'AWMS-LP, AWMS-SSCC, AWMS-CNT numara serileri mevcut.';
        end else begin
            Status := Status::Missing;
            Detail := 'DOPSWHS numara serileri eksik.';
        end;
    end;

    local procedure EvalWebServices(var Status: Option NotChecked,OK,Warning,Missing; var Detail: Text)
    var
        TenantWebService: Record "Tenant Web Service";
    begin
        TenantWebService.SetFilter("Service Name", 'DOPSWHS*');
        if TenantWebService.Count() > 0 then begin
            Status := Status::OK;
            Detail := StrSubstNo('%1 DOPSWHS web servisi yayında.', TenantWebService.Count());
        end else begin
            Status := Status::Missing;
            Detail := 'DOPSWHS web servisleri yayınlanmamış.';
        end;
    end;

    local procedure EvalAppProfile(var Status: Option NotChecked,OK,Warning,Missing; var Detail: Text)
    var
        Profile: Record "DOPSWHS App User Profile";
        CurrentUser: Code[50];
    begin
        CurrentUser := CopyStr(UserId(), 1, 50);
        if Profile.Get(CurrentUser) then begin
            Status := Status::OK;
            Detail := StrSubstNo('%1 için profil: config=%2, loc=%3', CurrentUser, Profile."Config Code", Profile."Default Location Code");
            exit;
        end;
        if Profile.Get('DEFAULT') then begin
            Status := Status::Warning;
            Detail := StrSubstNo('%1 için ayrı profil yok — DEFAULT profile düşülüyor (config=%2).', CurrentUser, Profile."Config Code");
            exit;
        end;
        Status := Status::Missing;
        Detail := 'Hiç App User Profile yok (DEFAULT bile). Mobil app fallback davranışla çalışır.';
    end;

    // ============================ Fixes ============================

    local procedure FixPackageNos()
    var
        InventorySetup: Record "Inventory Setup";
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        if not NoSeries.Get('DOPSWHS-PKG') then begin
            NoSeries.Init();
            NoSeries.Code := 'DOPSWHS-PKG';
            NoSeries.Description := 'LP / Package Numbering';
            NoSeries."Default Nos." := true;
            NoSeries."Manual Nos." := true;
            NoSeries.Insert(true);
        end;
        if not NoSeriesLine.Get('DOPSWHS-PKG', 10000) then begin
            NoSeriesLine.Init();
            NoSeriesLine."Series Code" := 'DOPSWHS-PKG';
            NoSeriesLine."Line No." := 10000;
            NoSeriesLine."Starting No." := 'PKG000001';
            NoSeriesLine."Ending No." := 'PKG999999';
            NoSeriesLine."Increment-by No." := 1;
            NoSeriesLine.Insert(true);
        end;
        if InventorySetup.FindFirst() then begin
            InventorySetup."Package Nos." := 'DOPSWHS-PKG';
            InventorySetup.Modify(true);
        end;
    end;

    local procedure FixItemTrackingCode()
    var
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        if ItemTrackingCode.Get('DOPSWHS-LP') then
            exit;
        ItemTrackingCode.Init();
        ItemTrackingCode.Code := 'DOPSWHS-LP';
        ItemTrackingCode.Description := 'License Plate (package) tracking';
        ItemTrackingCode.Validate("Package Specific Tracking", true);
        ItemTrackingCode.Validate("Package Warehouse Tracking", true);
        ItemTrackingCode.Insert(true);
    end;

    local procedure FixWarehouseEmployee()
    var
        E2EData: Codeunit "DOPSWHS E2E Test Data";
    begin
        E2EData.EnsureWarehouseEmployee();
    end;

    local procedure FixDefaultLocationBins()
    var
        E2EData: Codeunit "DOPSWHS E2E Test Data";
    begin
        E2EData.EnsureBlueLocationBins();
    end;

    local procedure FixNumberSeries()
    var
        DemoSetup: Codeunit "DOPSWHS Demo Data Setup";
    begin
        DemoSetup.EnsureNumberSeries();
    end;

    local procedure FixWebServices()
    var
        WebSvcPublisher: Codeunit "DOPSWHS Web Svc Publisher";
    begin
        WebSvcPublisher.PublishAll();
    end;

    local procedure FixAppProfile()
    var
        AppProfileMgmt: Codeunit "DOPSWHS App Profile Mgmt";
    begin
        AppProfileMgmt.SeedDefaults();
    end;

    // ============================ Helpers ============================

    local procedure Upsert(CheckCode: Code[20]; SortOrder: Integer; Title: Text[100]; Fixable: Boolean; Required: Boolean; Status: Option NotChecked,OK,Warning,Missing; Detail: Text)
    var
        ConfigCheck: Record "DOPSWHS Config Check";
        Exists: Boolean;
    begin
        Exists := ConfigCheck.Get(CheckCode);
        if not Exists then begin
            ConfigCheck.Init();
            ConfigCheck."Code" := CheckCode;
        end;
        ConfigCheck."Sort Order" := SortOrder;
        ConfigCheck."Title" := Title;
        ConfigCheck."Auto Fixable" := Fixable;
        ConfigCheck."Required" := Required;
        ConfigCheck."Status" := Status;
        ConfigCheck."Detail" := CopyStr(Detail, 1, MaxStrLen(ConfigCheck."Detail"));
        if Exists then
            ConfigCheck.Modify()
        else
            ConfigCheck.Insert();
    end;
}
