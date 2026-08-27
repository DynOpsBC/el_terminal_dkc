codeunit 72061 "DOPSWHS Test Catalog Seed"
{
    // 50 Test Case + 5 Environment + 3 User Group seed (idempotent).
    Access = Public;

    trigger OnRun()
    begin
        RunFullSeed();
    end;

    procedure RunFullSeed()
    var
        Msg: Label 'Test Catalog seed tamamlandı.\n\n• 50 Test Case (Section A-H)\n• 5 Environment (DEV/TEST/UAT/PREPROD/PROD)\n• 3 User Group (DEV-TEAM/QA-TEAM/BUSINESS-USERS)\n\nRole Center  Test Center "New Test Run" ile koşumu başlatabilirsiniz.';
    begin
        SeedEnvironments();
        SeedUserGroups();
        SeedAllTestCases();
        Message(Msg);
    end;

    local procedure SeedEnvironments()
    begin
        AddEnv('DEV', 'Development environment', 0);
        AddEnv('TEST', 'Internal QA test environment', 1);
        AddEnv('UAT', 'User acceptance test environment', 2);
        AddEnv('PREPROD', 'Pre-production staging', 3);
        AddEnv('PROD', 'Production environment', 4);
    end;

    local procedure AddEnv(Code: Code[20]; Description: Text[100]; CategoryOpt: Integer)
    var
        Env: Record "DOPSWHS Test Environment";
    begin
        if Env.Get(Code) then
            exit;
        Env.Init();
        Env."Code" := Code;
        Env.Description := Description;
        Env.Category := CategoryOpt;
        Env."Sort Order" := CategoryOpt * 10;
        Env.Active := true;
        Env.Insert(true);
    end;

    local procedure SeedUserGroups()
    begin
        AddGroup('DEV-TEAM', 'Developers + lead engineer', 0);
        AddGroup('QA-TEAM', 'QA engineers + automation specialists', 1);
        AddGroup('BUSINESS-USERS', 'Warehouse managers + operators + supervisors', 2);
    end;

    local procedure AddGroup(Code: Code[20]; Description: Text[100]; CategoryOpt: Integer)
    var
        Grp: Record "DOPSWHS Test User Group";
    begin
        if Grp.Get(Code) then
            exit;
        Grp.Init();
        Grp."Code" := Code;
        Grp.Description := Description;
        Grp.Category := CategoryOpt;
        Grp.Active := true;
        Grp.Insert(true);
    end;

    local procedure SeedAllTestCases()
    begin
        SeedSectionA();
        SeedSectionB();
        SeedSectionC();
        SeedSectionD();
        SeedSectionE();
        SeedSectionF();
        SeedSectionG();
        SeedSectionH();
    end;

    local procedure SeedSectionA()
    var
        CU_Setup: Integer;
    begin
        CU_Setup := 72064;
        AddCase('TC-001', 'A', 'Demo Data Setup idempotency', 'CU 72058 RunFullDemoSetup iki kez çağrılır, ikinci çağrı side-effect üretmez.', 0, 0, CU_Setup, 'RunTC001', 5, true, 10);
        AddCase('TC-002', 'A', 'Demo Transactions 5 LP + 1 Count Sheet', 'CreateDemoLPs + CreateActiveCountSheet sonrası count doğrulanır.', 0, 0, CU_Setup, 'RunTC002', 5, true, 20);
        AddCase('TC-003', 'A', 'DynOpsWarehouseManagement profile validate', 'Profile.RoleCenter = 72095 doğrulanır.', 0, 0, CU_Setup, 'RunTC003', 3, false, 30);
        AddCase('TC-004', 'A', 'Role Center cue FlowFields çalışıyor', 'DynOpsWMS Cue tablosu Get + CalcFields hata vermeden çalışır.', 0, 0, CU_Setup, 'RunTC004', 5, true, 40);
        AddCase('TC-005', 'A', 'Test Catalog + Automation infrastructure', 'Test Case catalog 50 kayit + 11 automation codeunit (72061-72071) production app icinde mevcut.', 0, 0, CU_Setup, 'RunTC005', 3, false, 50);
    end;

    local procedure SeedSectionB()
    var
        CU_LP: Integer;
    begin
        CU_LP := 72065;
        AddCase('TC-006', 'B', 'LP build (CARTON-S, default location)', 'LP Management.Build çağrılır, Status=Open doğrulanır.', 0, 0, CU_LP, 'RunTC006', 5, true, 10);
        AddCase('TC-007', 'B', 'LP AddLine 3x Movement Ledger', 'AddLine 3 kez, Movement Ledger ItemAdded entry sayısı 3.', 0, 0, CU_LP, 'RunTC007', 5, true, 20);
        AddCase('TC-008', 'B', 'LP Stop Built + SSCC üretilir', 'Stop çağrılır, Status=Built, SSCC 18 char doğrulanır.', 0, 0, CU_LP, 'RunTC008', 5, true, 30);
        AddCase('TC-009', 'B', 'LP Print Label Print Job Queue entry', 'PrintLabel çağrılır, Print Job Queue satır sayısı 1 artar.', 0, 1, CU_LP, 'RunTC009', 5, false, 40);
        AddCase('TC-010', 'B', 'Partial Use CreateNewLP (10 / use 6)', 'SplitForPartialUse(CreateNewLP, 6) 2 LP oluşur.', 0, 0, CU_LP, 'RunTC010', 7, true, 50);
        AddCase('TC-011', 'B', 'Partial Use Unbuild (10 / use 6)', 'SplitForPartialUse(Unbuild, 6) kaynak Unbuilt, leftover loose.', 0, 0, CU_LP, 'RunTC011', 7, true, 60);
        AddCase('TC-012', 'B', 'LP Transfer line subset', 'Transfer 2 line kaynak ve hedef LP Movement Ledger entries.', 0, 0, CU_LP, 'RunTC012', 7, true, 70);
        AddCase('TC-013', 'B', 'KRİTİK — Bin Content nested rollup = 100 (çift sayım YOK)', '3-level nesting (Pallet 2 Cartons 50 unit each), Bin Content = 100.', 0, 0, CU_LP, 'RunTC013', 10, true, 80);
        AddCase('TC-014', 'B', 'Nest depth 4 reddedilir', 'Nest depth=4 deneyimi exception fırlatır.', 0, 0, CU_LP, 'RunTC014', 5, true, 90);
        AddCase('TC-015', 'B', 'SURROGATE — LPNestManager.Nest direct call (SPA simulate)', 'LP Browser SPA drag-drop = direct AL Nest call.', 2, 1, CU_LP, 'RunTC015', 5, false, 100);
    end;

    local procedure SeedSectionC()
    var
        CU_Recv: Integer;
    begin
        CU_Recv := 72066;
        AddCase('TC-016', 'C', 'Demo Whse Receipt + Post ILE', 'Whse Receipt yarat, Post, Posted Whse Receipt + Item Ledger.', 0, 0, CU_Recv, 'RunTC016', 10, true, 10);
        AddCase('TC-017', 'C', 'Receipt + LP build during receive', 'StartLP + StopLP receipt akışı; posted line LP No doluyor.', 0, 0, CU_Recv, 'RunTC017', 10, true, 20);
        AddCase('TC-018', 'C', 'SURROGATE — GS1-128 ParseBarcode', '(01)08401234567890(10)LOT123(17)260101(21)SN42 parse doğru.', 3, 1, CU_Recv, 'RunTC018', 3, true, 30);
        AddCase('TC-019', 'C', 'Transfer Order receive side', 'Transfer Order receipt akışı, Whse Receipt post.', 0, 0, CU_Recv, 'RunTC019', 10, false, 40);
        AddCase('TC-020', 'C', 'Receipt AssignedToUser audit', 'AssignToUser action çağrısı sonrası field güncellenir.', 0, 0, CU_Recv, 'RunTC020', 5, false, 50);
        AddCase('TC-021', 'C', 'Item Tracking lot-tracked item', 'ITEM-LOT-1 receipt tracking lines beklenen değerle.', 0, 1, CU_Recv, 'RunTC021', 7, false, 60);
        AddCase('TC-022', 'C', 'Receiving Queue FlowField (P 72082)', 'Receiving Queue sayfası PO/TO/WR union toplam sayısı.', 0, 0, CU_Recv, 'RunTC022', 5, false, 70);
        AddCase('TC-023', 'C', 'Posted Whse Receipt Line.LP No field', 'TableExt 72404 LP No alanı posted line üzerinde mevcut.', 0, 0, CU_Recv, 'RunTC023', 3, false, 80);
    end;

    local procedure SeedSectionD()
    var
        CU_PickShip: Integer;
    begin
        CU_PickShip := 72067;
        AddCase('TC-024', 'D', 'Sales Order Pick oluşturma', 'Released SO Whse Shipment Pick (Type=Pick) oluşur.', 0, 0, CU_PickShip, 'RunTC024', 10, true, 10);
        AddCase('TC-025', 'D', 'Pick AssignToMe', 'AssignToMe sonrası AssignedUser=current.', 0, 0, CU_PickShip, 'RunTC025', 3, false, 20);
        AddCase('TC-026', 'D', 'Pick-to-LP + SSCC', 'StartShippingLP + 5 line + StopShippingLP, SSCC üretilir.', 0, 0, CU_PickShip, 'RunTC026', 10, true, 30);
        AddCase('TC-027', 'D', 'MarkPickShort + backorder', 'MarkPickShort(NO_STOCK), backorder flag, register devam eder.', 0, 0, CU_PickShip, 'RunTC027', 7, false, 40);
        AddCase('TC-028', 'D', 'RegisterPick Whse Entries + ILE', 'Pick register, Whse Activity silindi, Whse Entries oluştu.', 0, 0, CU_PickShip, 'RunTC028', 10, true, 50);
        AddCase('TC-029', 'D', 'SURROGATE — PickMgmt.ReassignPick direct call', 'Pick Queue SPA reassign = direct AL ReassignPick.', 2, 1, CU_PickShip, 'RunTC029', 5, false, 60);
        AddCase('TC-030', 'D', 'Whse Shipment Post (print=true)', 'Shipment post, LP Used, Print Job entry oluşur.', 0, 0, CU_PickShip, 'RunTC030', 10, true, 70);
        AddCase('TC-031', 'D', 'Sales Order Ship & Invoice atomic', 'ShipAndInvoice Posted Sales Shipment + Posted Sales Invoice.', 0, 0, CU_PickShip, 'RunTC031', 10, false, 80);
        AddCase('TC-032', 'D', 'Transfer Order ship side post', 'Transfer ship-side post, Posted Transfer Shipment.', 0, 0, CU_PickShip, 'RunTC032', 10, false, 90);
        AddCase('TC-033', 'D', 'Eksik SSCC otomatik üretilir', 'Stop ile SSCC üretilmediyse Shipment.Post sırasında auto-gen.', 0, 0, CU_PickShip, 'RunTC033', 7, false, 100);
    end;

    local procedure SeedSectionE()
    var
        CU_Move: Integer;
    begin
        CU_Move := 72068;
        AddCase('TC-034', 'E', 'AdHocMove Item Reclass Journal', 'AdHocMove(fromBin, toBin, qty=5) Warehouse Entries 2x.', 0, 0, CU_Move, 'RunTC034', 7, false, 10);
        AddCase('TC-035', 'E', 'Directed Whse Movement Register', 'Whse Movement document Register bin contents transfer.', 0, 0, CU_Move, 'RunTC035', 10, false, 20);
        AddCase('TC-036', 'E', 'KRİTİK — Batch isolation (2 user)', 'İki simulated user, ayrı DOPS-<userId> batch oluşur.', 0, 0, CU_Move, 'RunTC036', 7, true, 30);
    end;

    local procedure SeedSectionF()
    var
        CU_Count: Integer;
    begin
        CU_Count := 72069;
        AddCase('TC-037', 'F', 'CreateSheet (Blind, 1 counter)', 'CountSheet yarat, Status=Open, Phys Inv Batch oluşur.', 0, 0, CU_Count, 'RunTC037', 7, true, 10);
        AddCase('TC-038', 'F', 'Multi-counter variance (3 slot)', '3 counter (100/100/95) RecountRequired=true.', 0, 0, CU_Count, 'RunTC038', 10, true, 20);
        AddCase('TC-039', 'F', 'PostSheet Phys Inv Journal + ILE', 'Sheet post, Phys Inv Journal entries, ILE adjustment.', 0, 0, CU_Count, 'RunTC039', 10, true, 30);
        AddCase('TC-040', 'F', 'Variance Review workflow', 'Variance Review page (P 72085) supervisor approve flow.', 0, 0, CU_Count, 'RunTC040', 7, false, 40);
    end;

    local procedure SeedSectionG()
    var
        CU_Prod: Integer;
    begin
        CU_Prod := 72070;
        AddCase('TC-041', 'G', 'Consume ILE Consumption', 'Consume(component, qty, lpNo) ILE Type=Consumption.', 0, 0, CU_Prod, 'RunTC041', 10, false, 10);
        AddCase('TC-042', 'G', 'ReportOutput ILE Output', 'ReportOutput(qty=10, scrap=1, runtime=120) ILE Type=Output.', 0, 0, CU_Prod, 'RunTC042', 10, false, 20);
        AddCase('TC-043', 'G', 'Output to new LP (KB pattern)', 'newLpTemplate=CARTON-S output bin yeni Built LP.', 0, 0, CU_Prod, 'RunTC043', 10, false, 30);
        AddCase('TC-044', 'G', 'Assembly Post (Assemble-to-Stock)', 'AssemblyMgmt.PostAssembly components consume + output.', 0, 0, CU_Prod, 'RunTC044', 10, false, 40);
        AddCase('TC-045', 'G', 'Full prod cycle: Consume Output LP', 'Released Prod Consume Output to LP finished item.', 0, 0, CU_Prod, 'RunTC045', 15, false, 50);
    end;

    local procedure SeedSectionH()
    var
        CU_System: Integer;
    begin
        CU_System := 72071;
        AddCase('TC-046', 'H', 'Device.LastSeen heartbeat cue', 'LastSeen update Çevrimiçi Cihazlar cue=3 (<5dk filter).', 0, 0, CU_System, 'RunTC046', 5, false, 10);
        AddCase('TC-047', 'H', 'Sync Conflict simulate (412)', 'SyncConflictBuffer row oluşur, resolve flow doğrulanır.', 0, 0, CU_System, 'RunTC047', 7, false, 20);
        AddCase('TC-048', 'H', 'REST API smoke (4 endpoint)', 'GET /licensePlates + POST assign + GET /items + POST barcodes/parse.', 3, 0, CU_System, 'RunTC048', 10, false, 30);
        AddCase('TC-049', 'H', 'SURROGATE — Webhook event delivery', 'OnPickReassigned BusinessEvent Webhook Audit row.', 2, 1, CU_System, 'RunTC049', 5, false, 40);
        AddCase('TC-050', 'H', 'SURROGATE — LP Browser tree traversal', '3-level nesting fetch + PrintLpLabel call simulate.', 2, 1, CU_System, 'RunTC050', 5, false, 50);
    end;

    local procedure AddCase(Code: Code[20]; Section: Code[10]; Title: Text[150]; Description: Text[1024]; SurfaceOpt: Integer; AutomationTypeOpt: Integer; AutomationCodeunitId: Integer; AutomationProcedure: Text[80]; EstimatedSeconds: Integer; IsCritical: Boolean; SortOrder: Integer)
    var
        TC: Record "DOPSWHS Test Case";
    begin
        if TC.Get(Code) then begin
            // Update existing record's metadata (preserve Active flag)
            TC.Title := Title;
            TC.Description := Description;
            TC.Surface := SurfaceOpt;
            TC."Automation Type" := AutomationTypeOpt;
            TC."Automation Codeunit ID" := AutomationCodeunitId;
            TC."Automation Procedure" := AutomationProcedure;
            TC."Estimated Seconds" := EstimatedSeconds;
            TC.Critical := IsCritical;
            TC.Section := Section;
            TC."Sort Order" := SortOrder;
            TC.Modify(true);
            exit;
        end;
        TC.Init();
        TC."Code" := Code;
        TC.Section := Section;
        TC.Title := Title;
        TC.Description := Description;
        TC.Surface := SurfaceOpt;
        TC."Automation Type" := AutomationTypeOpt;
        TC."Automation Codeunit ID" := AutomationCodeunitId;
        TC."Automation Procedure" := AutomationProcedure;
        TC."Estimated Seconds" := EstimatedSeconds;
        TC.Active := true;
        TC.Critical := IsCritical;
        TC."Sort Order" := SortOrder;
        TC.Insert(true);
    end;
}
