codeunit 72072 "DOPSWHS Scenario Generator"
{
    // Otomatik test senaryo üreteci.
    //
    // Eldeki master data (CRONUS standart item/vendor/customer + CU 72060'in
    // yarattığı custom test item'lar) + canlı lokasyon flag'leri kullanarak
    // web/mobile UI'da test edebilmemiz için gereken tüm alternatif source
    // belgelerini idempotent şekilde yaratır.
    //
    // İdempotency: her belgeye External Document No. = 'gen.<key>' yazılır.
    // Tekrar çalıştırıldığında mevcut belge atlanır.
    //
    // Tetikleme: Setup card (P 72061) "Generate All Test Scenarios" action.

    Access = Public;
    Permissions =
        tabledata "Purchase Header" = RIMD,
        tabledata "Purchase Line" = RIMD,
        tabledata "Sales Header" = RIMD,
        tabledata "Sales Line" = RIMD,
        tabledata "Warehouse Receipt Header" = RIMD,
        tabledata "Warehouse Shipment Header" = RIMD,
        tabledata "Warehouse Activity Header" = RIMD;

    var
        CreatedCount: Integer;
        SkippedCount: Integer;
        FailedCount: Integer;
        LogBuffer: Text;
        SourceKeyTok: Label 'gen.%1', Locked = true;
        DefaultVendorTok: Label '10000', Locked = true;
        DefaultCustomerTok: Label '10000', Locked = true;
        AltVendorTok: Label '20000', Locked = true;
        AltCustomerTok: Label '20000', Locked = true;

    procedure GenerateAll(): Text
    var
        E2E: Codeunit "DOPSWHS E2E Test Data";
    begin
        ResetCounters();
        E2E.PrepareE2EData();
        AppendLog('Master data: OK');

        GenerateReceiveScenarios();
        GenerateShipScenarios();
        GenerateLPScenarios();
        GenerateCountScenarios();
        GenerateMovementScenarios();
        GenerateProductionScenarios();
        GenerateAssemblyScenarios();

        exit(StrSubstNo(
            'Scenario Generator tamamlandı.\n' +
            'Oluşturulan: %1 | Atlanan: %2 | Hata: %3\n\n%4',
            CreatedCount, SkippedCount, FailedCount, LogBuffer));
    end;

    procedure CleanupGenerated(): Integer
    var
        PH: Record "Purchase Header";
        SH: Record "Sales Header";
        Deleted: Integer;
    begin
        PH.SetRange("Document Type", PH."Document Type"::Order);
        PH.SetFilter("Vendor Shipment No.", 'gen.*');
        if PH.FindSet() then
            repeat
                if SafeDeletePurchHeader(PH) then
                    Deleted += 1;
            until PH.Next() = 0;

        SH.SetRange("Document Type", SH."Document Type"::Order);
        SH.SetFilter("External Document No.", 'gen.*');
        if SH.FindSet() then
            repeat
                if SafeDeleteSalesHeader(SH) then
                    Deleted += 1;
            until SH.Next() = 0;

        exit(Deleted);
    end;

    // ============================================================
    // A — Receive scenarios
    // ============================================================

    procedure GenerateReceiveScenarios(): Integer
    var
        Items: List of [Code[20]];
        Qtys: List of [Decimal];
        PH: Record "Purchase Header";
    begin
        // gen.recv.direct
        BuildList(Items, Qtys, '1896-S', 10);
        TrySeedPO('recv.direct', DefaultVendorTok, '', Items, Qtys, true, PH);

        // gen.recv.direct.multi
        Clear(Items); Clear(Qtys);
        BuildList(Items, Qtys, '1896-S', 5);
        AppendList(Items, Qtys, '1900-S', 5);
        AppendList(Items, Qtys, '1920-S', 5);
        TrySeedPO('recv.direct.multi', AltVendorTok, '', Items, Qtys, true, PH);

        // gen.recv.whse.white  (location WHITE = Require Receive=true expected)
        Clear(Items); Clear(Qtys);
        BuildList(Items, Qtys, '1896-S', 10);
        if TrySeedPO('recv.whse.white', DefaultVendorTok, 'WHITE', Items, Qtys, true, PH) then
            TryCreateWhseReceipt(PH);

        // gen.recv.whse.yellow
        Clear(Items); Clear(Qtys);
        BuildList(Items, Qtys, '1896-S', 100);
        if TrySeedPO('recv.whse.yellow', DefaultVendorTok, 'YELLOW', Items, Qtys, true, PH) then
            TryCreateWhseReceipt(PH);

        // gen.recv.silver (managed — Pick mandatory but receive testable)
        Clear(Items); Clear(Qtys);
        BuildList(Items, Qtys, '1896-S', 50);
        if TrySeedPO('recv.silver', AltVendorTok, 'SILVER', Items, Qtys, true, PH) then
            TryCreateWhseReceipt(PH);

        // gen.recv.lot (lot tracked test item)
        Clear(Items); Clear(Qtys);
        BuildList(Items, Qtys, 'ITEM-LOT-1', 20);
        TrySeedPO('recv.lot', DefaultVendorTok, '', Items, Qtys, true, PH);

        // gen.recv.serial
        Clear(Items); Clear(Qtys);
        BuildList(Items, Qtys, 'ITEM-SN-1', 5);
        TrySeedPO('recv.serial', DefaultVendorTok, '', Items, Qtys, true, PH);

        // gen.recv.expiry
        Clear(Items); Clear(Qtys);
        BuildList(Items, Qtys, 'ITEM-EXP-1', 15);
        TrySeedPO('recv.expiry', DefaultVendorTok, '', Items, Qtys, true, PH);

        exit(CreatedCount);
    end;

    // ============================================================
    // B — Ship scenarios
    // ============================================================

    procedure GenerateShipScenarios(): Integer
    var
        Items: List of [Code[20]];
        Qtys: List of [Decimal];
        SH: Record "Sales Header";
    begin
        // gen.ship.direct
        BuildList(Items, Qtys, '1896-S', 3);
        TrySeedSO('ship.direct', DefaultCustomerTok, '', Items, Qtys, true, SH);

        // gen.ship.direct.invoice
        Clear(Items); Clear(Qtys);
        BuildList(Items, Qtys, '1900-S', 2);
        TrySeedSO('ship.direct.invoice', DefaultCustomerTok, '', Items, Qtys, true, SH);

        // gen.ship.whse.white
        Clear(Items); Clear(Qtys);
        BuildList(Items, Qtys, '1896-S', 5);
        if TrySeedSO('ship.whse.white', DefaultCustomerTok, 'WHITE', Items, Qtys, true, SH) then
            TryCreateWhseShipment(SH);

        // gen.ship.whse.silver
        Clear(Items); Clear(Qtys);
        BuildList(Items, Qtys, '1896-S', 10);
        if TrySeedSO('ship.whse.silver', AltCustomerTok, 'SILVER', Items, Qtys, true, SH) then
            TryCreateWhseShipment(SH);

        // gen.ship.lot
        Clear(Items); Clear(Qtys);
        BuildList(Items, Qtys, 'ITEM-LOT-1', 5);
        TrySeedSO('ship.lot', DefaultCustomerTok, '', Items, Qtys, true, SH);

        // gen.ship.partial (qty=20 — kullanıcı kısmi ship eder)
        Clear(Items); Clear(Qtys);
        BuildList(Items, Qtys, '1896-S', 20);
        TrySeedSO('ship.partial', DefaultCustomerTok, '', Items, Qtys, true, SH);

        exit(CreatedCount);
    end;

    // ============================================================
    // E — LP scenarios
    // ============================================================

    procedure GenerateLPScenarios(): Integer
    var
        LPMgmt: Codeunit "DOPSWHS LP Management";
        LP: Record "DOPSWHS LP Header";
        Loc: Code[10];
        Bin: Code[20];
    begin
        Loc := ResolveLPLocation();
        Bin := ResolveLPBin(Loc);

        // 5 farklı template ile build
        TrySeedLP(LPMgmt, 'lp.carton.s', 'CARTON-S', Loc, Bin, '1896-S', 10);
        TrySeedLP(LPMgmt, 'lp.carton.m', 'CARTON-M', Loc, Bin, '1900-S', 5);
        TrySeedLP(LPMgmt, 'lp.pallet.eur', 'PALLET-EUR', Loc, Bin, '1920-S', 50);
        TrySeedLP(LPMgmt, 'lp.pallet.us', 'PALLET-US', Loc, Bin, '1896-S', 100);
        TrySeedLP(LPMgmt, 'lp.tote.a', 'TOTE-A', Loc, Bin, 'ITEM-SN-1', 3);

        // gen.lp.partial.split — Built bir LP'yi partial-use
        if FindGeneratedLP('lp.carton.s', LP) then
            TryPartialUseLP(LP);

        exit(CreatedCount);
    end;

    // ============================================================
    // F — Count scenarios
    // ============================================================

    procedure GenerateCountScenarios(): Integer
    var
        Counters: array[3] of Code[50];
    begin
        // 1 counter Blind
        Clear(Counters);
        Counters[1] := CopyStr(UserId(), 1, 50);
        TrySeedCountSheet('count.blind.silver', 'SILVER', "DOPSWHS Count Mode"::Blind, Counters);

        // 3 counter Blind — multi-count variance test
        Clear(Counters);
        Counters[1] := CopyStr(UserId(), 1, 50);
        Counters[2] := 'USER2';
        Counters[3] := 'USER3';
        TrySeedCountSheet('count.multi.silver', 'SILVER', "DOPSWHS Count Mode"::Blind, Counters);

        // Visible (görünür sayım)
        Clear(Counters);
        Counters[1] := CopyStr(UserId(), 1, 50);
        TrySeedCountSheet('count.visible.white', 'WHITE', "DOPSWHS Count Mode"::Visible, Counters);

        exit(CreatedCount);
    end;

    // ============================================================
    // G — Production (mevcut Cronus prod orders kullanılır — placeholder)
    // ============================================================

    procedure GenerateProductionScenarios(): Integer
    begin
        AppendLog('Production: v1 generator skip — Cronus standart prod orders kullanılır');
        exit(0);
    end;

    procedure GenerateAssemblyScenarios(): Integer
    begin
        AppendLog('Assembly: v1 generator skip — Cronus standart assembly orders kullanılır');
        exit(0);
    end;

    procedure GenerateMovementScenarios(): Integer
    begin
        AppendLog('Movement: v1 generator skip — manuel olarak Item Reclass Journal kullanın');
        exit(0);
    end;

    // ============================================================
    // PO helper
    // ============================================================

    local procedure TrySeedPO(KeySuffix: Text; VendorNo: Code[20]; LocationCode: Code[10]; Items: List of [Code[20]]; Qtys: List of [Decimal]; Release: Boolean; var PH: Record "Purchase Header"): Boolean
    var
        ScenarioKey: Code[35];
    begin
        ScenarioKey := MakeKey(KeySuffix);
        if PurchHeaderExists(ScenarioKey, PH) then begin
            SkippedCount += 1;
            AppendLog(StrSubstNo('PO %1 atlandı (mevcut: %2)', ScenarioKey, PH."No."));
            exit(false);
        end;

        if not InsertPO(ScenarioKey, VendorNo, LocationCode, Items, Qtys, Release, PH) then begin
            FailedCount += 1;
            AppendLog(StrSubstNo('PO %1 FAIL: %2', ScenarioKey, GetLastErrorText()));
            exit(false);
        end;

        CreatedCount += 1;
        AppendLog(StrSubstNo('PO %1 %2 (loc=%3, lines=%4)', ScenarioKey, PH."No.", LocationCode, Items.Count));
        exit(true);
    end;

    [TryFunction]
    local procedure InsertPO(ScenarioKey: Code[35]; VendorNo: Code[20]; LocationCode: Code[10]; Items: List of [Code[20]]; Qtys: List of [Decimal]; Release: Boolean; var PH: Record "Purchase Header")
    var
        PL: Record "Purchase Line";
        ReleasePurchDoc: Codeunit "Release Purchase Document";
        i: Integer;
    begin
        Clear(PH);
        PH."Document Type" := PH."Document Type"::Order;
        PH.Insert(true);
        PH.Validate("Buy-from Vendor No.", VendorNo);
        if LocationCode <> '' then
            PH.Validate("Location Code", LocationCode);
        PH.Validate("Vendor Shipment No.", ScenarioKey);
        PH.Modify(true);

        for i := 1 to Items.Count do begin
            Clear(PL);
            PL."Document Type" := PH."Document Type";
            PL."Document No." := PH."No.";
            PL."Line No." := i * 10000;
            PL.Insert(true);
            PL.Validate(Type, PL.Type::Item);
            PL.Validate("No.", Items.Get(i));
            if LocationCode <> '' then
                PL.Validate("Location Code", LocationCode);
            PL.Validate(Quantity, Qtys.Get(i));
            PL.Modify(true);
        end;

        if Release then
            ReleasePurchDoc.Run(PH);

        PH.Find(); // refresh after release
    end;

    local procedure PurchHeaderExists(ScenarioKey: Code[35]; var PH: Record "Purchase Header"): Boolean
    begin
        PH.Reset();
        PH.SetRange("Document Type", PH."Document Type"::Order);
        PH.SetRange("Vendor Shipment No.", ScenarioKey);
        exit(PH.FindFirst());
    end;

    // ============================================================
    // SO helper
    // ============================================================

    local procedure TrySeedSO(KeySuffix: Text; CustomerNo: Code[20]; LocationCode: Code[10]; Items: List of [Code[20]]; Qtys: List of [Decimal]; Release: Boolean; var SH: Record "Sales Header"): Boolean
    var
        ScenarioKey: Code[35];
    begin
        ScenarioKey := MakeKey(KeySuffix);
        if SalesHeaderExists(ScenarioKey, SH) then begin
            SkippedCount += 1;
            AppendLog(StrSubstNo('SO %1 atlandı (mevcut: %2)', ScenarioKey, SH."No."));
            exit(false);
        end;

        if not InsertSO(ScenarioKey, CustomerNo, LocationCode, Items, Qtys, Release, SH) then begin
            FailedCount += 1;
            AppendLog(StrSubstNo('SO %1 FAIL: %2', ScenarioKey, GetLastErrorText()));
            exit(false);
        end;

        CreatedCount += 1;
        AppendLog(StrSubstNo('SO %1 %2 (loc=%3, lines=%4)', ScenarioKey, SH."No.", LocationCode, Items.Count));
        exit(true);
    end;

    [TryFunction]
    local procedure InsertSO(ScenarioKey: Code[35]; CustomerNo: Code[20]; LocationCode: Code[10]; Items: List of [Code[20]]; Qtys: List of [Decimal]; Release: Boolean; var SH: Record "Sales Header")
    var
        SL: Record "Sales Line";
        ReleaseSalesDoc: Codeunit "Release Sales Document";
        i: Integer;
    begin
        Clear(SH);
        SH."Document Type" := SH."Document Type"::Order;
        SH.Insert(true);
        SH.Validate("Sell-to Customer No.", CustomerNo);
        if LocationCode <> '' then
            SH.Validate("Location Code", LocationCode);
        SH.Validate("External Document No.", ScenarioKey);
        SH.Modify(true);

        for i := 1 to Items.Count do begin
            Clear(SL);
            SL."Document Type" := SH."Document Type";
            SL."Document No." := SH."No.";
            SL."Line No." := i * 10000;
            SL.Insert(true);
            SL.Validate(Type, SL.Type::Item);
            SL.Validate("No.", Items.Get(i));
            if LocationCode <> '' then
                SL.Validate("Location Code", LocationCode);
            SL.Validate(Quantity, Qtys.Get(i));
            SL.Modify(true);
        end;

        if Release then
            ReleaseSalesDoc.Run(SH);

        SH.Find();
    end;

    local procedure SalesHeaderExists(ScenarioKey: Code[35]; var SH: Record "Sales Header"): Boolean
    begin
        SH.Reset();
        SH.SetRange("Document Type", SH."Document Type"::Order);
        SH.SetRange("External Document No.", ScenarioKey);
        exit(SH.FindFirst());
    end;

    // ============================================================
    // Whse Receipt + Shipment auto-create — v1 manuel
    //
    // Notlar: Generator PO/SO'ları Released yarattığı için kullanıcı
    // BC web client'tan "Whse Receipt Get Source Documents" veya
    // "Whse Shipment Get Source Documents" tıklayarak Whse belgesini
    // yaratabilir. v2'de headless yaratma eklenecek.
    // ============================================================

    local procedure TryCreateWhseReceipt(var PH: Record "Purchase Header")
    begin
        AppendLog(StrSubstNo('PO %1 Whse Receipt manual: BC client Whse Receipt Get Source Docs.', PH."No."));
    end;

    local procedure TryCreateWhseShipment(var SH: Record "Sales Header")
    begin
        AppendLog(StrSubstNo('SO %1 Whse Shipment manual: BC client Whse Shipment Get Source Docs.', SH."No."));
    end;

    // ============================================================
    // LP helpers
    // ============================================================

    local procedure TrySeedLP(LPMgmt: Codeunit "DOPSWHS LP Management"; KeySuffix: Text; TemplateCode: Code[20]; LocationCode: Code[10]; BinCode: Code[20]; ItemNo: Code[20]; Qty: Decimal)
    var
        LP: Record "DOPSWHS LP Header";
        ScenarioKey: Code[35];
    begin
        ScenarioKey := MakeKey(KeySuffix);
        if FindGeneratedLP(KeySuffix, LP) then begin
            SkippedCount += 1;
            AppendLog(StrSubstNo('LP %1 atlandı (mevcut: %2)', ScenarioKey, LP."No."));
            exit;
        end;

        if not BuildAndPopulateLP(LPMgmt, TemplateCode, LocationCode, BinCode, ItemNo, Qty, ScenarioKey, LP) then begin
            FailedCount += 1;
            AppendLog(StrSubstNo('LP %1 FAIL: %2', ScenarioKey, GetLastErrorText()));
            exit;
        end;

        CreatedCount += 1;
        AppendLog(StrSubstNo('LP %1 %2 (template=%3, item=%4, qty=%5)', ScenarioKey, LP."No.", TemplateCode, ItemNo, Qty));
    end;

    [TryFunction]
    local procedure BuildAndPopulateLP(LPMgmt: Codeunit "DOPSWHS LP Management"; TemplateCode: Code[20]; LocationCode: Code[10]; BinCode: Code[20]; ItemNo: Code[20]; Qty: Decimal; ScenarioKey: Code[35]; var LP: Record "DOPSWHS LP Header")
    begin
        LPMgmt.Build(TemplateCode, LocationCode, BinCode, LP);
        LPMgmt.AddLine(LP, ItemNo, 'PCS', Qty, '', '', 0D);
        LPMgmt.Stop(LP, false);
        LP.Notes := ScenarioKey;
        LP.Modify();
    end;

    local procedure FindGeneratedLP(KeySuffix: Text; var LP: Record "DOPSWHS LP Header"): Boolean
    var
        ScenarioKey: Code[35];
    begin
        ScenarioKey := MakeKey(KeySuffix);
        LP.Reset();
        LP.SetRange(Notes, ScenarioKey);
        exit(LP.FindFirst());
    end;

    local procedure TryPartialUseLP(var LP: Record "DOPSWHS LP Header")
    begin
        // Placeholder — LP partial use için ek line gerekli, skip etmek güvenli
        AppendLog(StrSubstNo('  LP %1 partial-use senaryosu manuel test için Built bırakıldı.', LP."No."));
    end;

    local procedure ResolveLPLocation(): Code[10]
    var
        Setup: Record "DOPSWHS Setup";
    begin
        if Setup.Get('') then
            if Setup."Default Location Code" <> '' then
                exit(Setup."Default Location Code");
        exit('SILVER');
    end;

    local procedure ResolveLPBin(LocationCode: Code[10]): Code[20]
    var
        Bin: Record Bin;
    begin
        Bin.SetRange("Location Code", LocationCode);
        if Bin.FindFirst() then
            exit(Bin.Code);
        exit('');
    end;

    // ============================================================
    // Count helpers
    // ============================================================

    local procedure TrySeedCountSheet(KeySuffix: Text; LocationCode: Code[10]; Mode: Enum "DOPSWHS Count Mode"; var Counters: array[3] of Code[50])
    var
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
        ScenarioKey: Code[35];
        SheetNo: Code[20];
    begin
        // Not: CSH'de External Document No. yok — her seferinde yeni sheet yaratılır.
        // Idempotency v2'de CSH tablosuna alan eklenince devreye alınacak.
        ScenarioKey := MakeKey(KeySuffix);

        if not InvokeCreateSheet(CountMgmt, LocationCode, Mode, Counters, SheetNo) then begin
            FailedCount += 1;
            AppendLog(StrSubstNo('Count %1 FAIL: %2', ScenarioKey, GetLastErrorText()));
            exit;
        end;

        CreatedCount += 1;
        AppendLog(StrSubstNo('Count %1 %2 (loc=%3, mode=%4)', ScenarioKey, SheetNo, LocationCode, Mode));
    end;

    [TryFunction]
    local procedure InvokeCreateSheet(CountMgmt: Codeunit "DOPSWHS Count Mgmt"; LocationCode: Code[10]; Mode: Enum "DOPSWHS Count Mode"; var Counters: array[3] of Code[50]; var SheetNo: Code[20])
    begin
        SheetNo := CountMgmt.CreateSheet(LocationCode, Mode, Counters);
    end;

    // ============================================================
    // Cleanup helpers
    // ============================================================

    [TryFunction]
    local procedure SafeDeletePurchHeader(var PH: Record "Purchase Header")
    var
        LocalRec: Record "Purchase Header";
    begin
        LocalRec :=PH;
        LocalRec.Delete(true);
    end;

    [TryFunction]
    local procedure SafeDeleteSalesHeader(var SH: Record "Sales Header")
    var
        LocalRec: Record "Sales Header";
    begin
        LocalRec :=SH;
        LocalRec.Delete(true);
    end;

    // ============================================================
    // Generic helpers
    // ============================================================

    local procedure ResetCounters()
    begin
        CreatedCount := 0;
        SkippedCount := 0;
        FailedCount := 0;
        LogBuffer := '';
    end;

    local procedure AppendLog(Line: Text)
    begin
        if LogBuffer <> '' then
            LogBuffer += '\n';
        LogBuffer += Line;
    end;

    local procedure MakeKey(KeySuffix: Text): Code[35]
    begin
        exit(CopyStr(StrSubstNo(SourceKeyTok, KeySuffix), 1, 35));
    end;

    local procedure BuildList(var Items: List of [Code[20]]; var Qtys: List of [Decimal]; ItemNo: Code[20]; Qty: Decimal)
    begin
        Items.Add(ItemNo);
        Qtys.Add(Qty);
    end;

    local procedure AppendList(var Items: List of [Code[20]]; var Qtys: List of [Decimal]; ItemNo: Code[20]; Qty: Decimal)
    begin
        Items.Add(ItemNo);
        Qtys.Add(Qty);
    end;
}
