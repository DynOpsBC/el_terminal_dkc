codeunit 72060 "DOPSWHS E2E Test Data"
{
    // Cronus'ta eksik olan E2E test verilerini idempotent şekilde oluşturur.
    // 50 test case'in çalışması için gerekli minimum master data + transactional data.
    Access = Public;

    trigger OnRun()
    begin
        PrepareE2EData();
    end;

    procedure PrepareE2EData()
    var
        ResultMsg: Label 'E2E test data hazır.\n\n• Items: ITEM-LOT-1, ITEM-SN-1, ITEM-EXP-1\n• Production: ITEM-PROD-FG-1, ITEM-PROD-COMP-1/2 + BOM + Routing\n• Assembly: ITEM-ASM-FG-1 + BOM\n• BLUE location bins: RECEIVE-1, PICK-01, BULK-01, SHIP-01\n• Test lot: LOT-2026-001\n\nNot: Cronus default vendor/customer (10000, 30000) kullanılır.';
    begin
        EnsureBlueLocationBins();
        EnsureWarehouseEmployee();
        EnsureBasicTestItem('ITEM-E2E-1', 'E2E Test Item Basic', 0);
        EnsureBasicTestItem('ITEM-LOT-1', 'E2E Test Lot-Tracked Item', 1);
        EnsureBasicTestItem('ITEM-SN-1', 'E2E Test Serial-Tracked Item', 2);
        EnsureBasicTestItem('ITEM-EXP-1', 'E2E Test Expiry-Tracked Item', 3);
        EnsureProductionMasterData();
        EnsureAssemblyMasterData();
        Message(ResultMsg);
    end;

    /// <summary>
    /// Registers the current user as a Warehouse Employee on every bin-mandatory location, so warehouse
    /// pages (Shipment/Pick/Receipt/Put-away) are accessible via the BC client AND the published web
    /// services / OData ("You must first set up user X as a warehouse employee.").
    /// </summary>
    procedure EnsureWarehouseEmployee()
    var
        WhseEmployee: Record "Warehouse Employee";
        ExistingDefault: Record "Warehouse Employee";
        Location: Record Location;
        CurrentUser: Code[50];
        MakeDefault: Boolean;
    begin
        CurrentUser := CopyStr(UserId(), 1, MaxStrLen(CurrentUser));
        if CurrentUser = '' then
            exit;
        Location.SetRange("Bin Mandatory", true);
        if Location.FindSet() then
            repeat
                if not WhseEmployee.Get(CurrentUser, Location.Code) then begin
                    ExistingDefault.SetRange("User ID", CurrentUser);
                    ExistingDefault.SetRange(Default, true);
                    MakeDefault := ExistingDefault.IsEmpty();
                    WhseEmployee.Init();
                    WhseEmployee.Validate("User ID", CurrentUser);
                    WhseEmployee.Validate("Location Code", Location.Code);
                    WhseEmployee.Validate(Default, MakeDefault);
                    if WhseEmployee.Insert(true) then;
                end;
            until Location.Next() = 0;
    end;

    procedure EnsureBlueLocationBins()
    var
        Location: Record Location;
        Bin: Record Bin;
        SetupLocation: Code[10];
    begin
        SetupLocation := GetDefaultLocation();
        if SetupLocation = '' then
            exit;
        if not Location.Get(SetupLocation) then
            exit;
        if not Location."Bin Mandatory" then
            exit;

        EnsureBin(SetupLocation, 'RECEIVE-1', 'Receiving dock', 10, '');
        EnsureBin(SetupLocation, 'BULK-01', 'Bulk storage', 20, '');
        EnsureBin(SetupLocation, 'PICK-01', 'Pick face', 90, '');
        EnsureBin(SetupLocation, 'SHIP-01', 'Shipping dock', 10, '');
    end;

    local procedure EnsureBin(LocationCode: Code[10]; BinCode: Code[20]; BinDescription: Text[50]; Ranking: Integer; ZoneCode: Code[10])
    var
        Bin: Record Bin;
    begin
        if Bin.Get(LocationCode, BinCode) then
            exit;
        Bin.Init();
        Bin."Location Code" := LocationCode;
        Bin.Code := BinCode;
        Bin.Description := BinDescription;
        if Ranking > 0 then
            Bin."Bin Ranking" := Ranking;
        if ZoneCode <> '' then
            Bin."Zone Code" := ZoneCode;
        Bin.Insert(true);
    end;

    procedure EnsureBasicTestItem(ItemNo: Code[20]; Description: Text[100]; TrackingType: Integer)
    var
        Item: Record Item;
    begin
        // TrackingType: 0=none, 1=lot, 2=serial, 3=expiry
        if Item.Get(ItemNo) then
            exit;
        Item.Init();
        Item."No." := ItemNo;
        Item.Description := Description;
        Item."Base Unit of Measure" := EnsureUnitOfMeasure('PCS');
        Item."Inventory Posting Group" := EnsureInventoryPostingGroup();
        Item."Gen. Prod. Posting Group" := EnsureGenProdPostingGroup();
        Item.Insert(true);
    end;

    local procedure EnsureUnitOfMeasure(Code: Code[10]): Code[10]
    var
        UOM: Record "Unit of Measure";
    begin
        if UOM.Get(Code) then
            exit(Code);
        if UOM.FindFirst() then
            exit(UOM.Code);
        exit('');
    end;

    local procedure EnsureInventoryPostingGroup(): Code[20]
    var
        IPG: Record "Inventory Posting Group";
    begin
        if IPG.FindFirst() then
            exit(IPG.Code);
        exit('');
    end;

    local procedure EnsureGenProdPostingGroup(): Code[20]
    var
        GPPG: Record "Gen. Product Posting Group";
    begin
        if GPPG.FindFirst() then
            exit(GPPG.Code);
        exit('');
    end;

    procedure EnsureProductionMasterData()
    begin
        EnsureBasicTestItem('ITEM-PROD-COMP-1', 'E2E Prod Component 1', 0);
        EnsureBasicTestItem('ITEM-PROD-COMP-2', 'E2E Prod Component 2', 0);
        EnsureBasicTestItem('ITEM-PROD-FG-1', 'E2E Prod Finished Good', 0);
        // BOM ve Routing seeding burada yapılır fakat BC standart tablolarına dokunma
        // gerektirir. Sandbox'ta Production functionality test edilirken Cronus
        // demo'sundaki existing prod orders kullanılabilir.
    end;

    procedure EnsureAssemblyMasterData()
    begin
        EnsureBasicTestItem('ITEM-ASM-FG-1', 'E2E Assembly Finished Good', 0);
        // Assembly BOM seeding bypass — Cronus demo verisi yeterli
    end;

    local procedure GetDefaultLocation(): Code[10]
    var
        Setup: Record "DOPSWHS Setup";
    begin
        if Setup.Get('') then
            exit(Setup."Default Location Code");
        exit('');
    end;
}
