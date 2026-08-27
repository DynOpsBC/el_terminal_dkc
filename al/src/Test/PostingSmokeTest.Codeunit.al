codeunit 72252 "DOPSWHS Posting Smoke Test"
{
    // Self-contained posting harness: for every WMS posting action exposed by the app, this creates
    // the minimal BC data and triggers the SAME Mgmt codeunit the API bound action calls, then asserts
    // the posted side-effect. Each domain runs inside a TryFunction so one failure never blocks the
    // rest — RunAll always returns a complete PASS/FAIL report (also persisted to the result table for
    // the mobile Posting Test screen). Authorized sandbox testing: postings create real ledger entries.
    Access = Public;

    var
        TestItemNo: Code[20];
        PreparedProdOrderNo: Code[20];

    procedure EnsureRows()
    begin
        Seed('1-MOVE', 10, 'Ad-Hoc Move (item reclass)');
        Seed('2-COUNT', 20, 'Inventory Count (phys. inv. post)');
        Seed('3-RECEIPT', 30, 'Warehouse Receipt post');
        Seed('4-PUTAWAY', 40, 'Put-Away register');
        Seed('5-SHIPMENT', 50, 'Warehouse Shipment post');
        Seed('6-PICK', 60, 'Pick register');
        Seed('7-CONSUME', 70, 'Production Consumption post');
        Seed('8-OUTPUT', 80, 'Production Output post');
        Seed('9-ASSEMBLY', 90, 'Assembly Order post');
    end;

    local procedure Seed(DomainCode: Code[20]; SortOrder: Integer; Descr: Text[100])
    var
        Result: Record "DOPSWHS Posting Test Result";
    begin
        if Result.Get(DomainCode) then
            exit;
        Result.Init();
        Result."Domain" := DomainCode;
        Result."Sort Order" := SortOrder;
        Result."Description" := Descr;
        Result."Status" := Result."Status"::NotRun;
        Result.Insert(true);
    end;

    /// <summary>Runs every posting domain and returns a JSON summary. Persists per-domain results.</summary>
    procedure RunAll(): Text
    var
        Result: Record "DOPSWHS Posting Test Result";
        Json: TextBuilder;
        Passed: Integer;
        Failed: Integer;
        First: Boolean;
    begin
        EnsureRows();
        EnsureTestItem();
        PrepareProdOrder();  // create+refresh prod order OUTSIDE any TryFunction (RunModal commits)

        RunOne('1-MOVE');
        RunOne('2-COUNT');
        RunOne('3-RECEIPT');
        RunOne('4-PUTAWAY');
        RunOne('5-SHIPMENT');
        RunOne('6-PICK');
        RunOne('7-CONSUME');
        RunOne('8-OUTPUT');
        RunOne('9-ASSEMBLY');

        Json.Append('{"results":[');
        First := true;
        Result.SetCurrentKey("Sort Order");
        if Result.FindSet() then
            repeat
                if not First then Json.Append(',');
                First := false;
                Json.Append(StrSubstNo('{"domain":"%1","status":"%2","detail":"%3","postedDoc":"%4"}',
                    Result."Domain", Format(Result."Status"), JsonEscape(Result."Detail"), Result."Posted Doc No."));
                if Result."Status" = Result."Status"::Passed then Passed += 1;
                if Result."Status" = Result."Status"::Failed then Failed += 1;
            until Result.Next() = 0;
        Json.Append(StrSubstNo('],"passed":%1,"failed":%2,"total":%3}', Passed, Failed, Passed + Failed));
        exit(Json.ToText());
    end;

    local procedure RunOne(DomainCode: Code[20])
    var
        Result: Record "DOPSWHS Posting Test Result";
        StartTime: DateTime;
        Detail: Text;
        PostedDoc: Code[35];
        Ok: Boolean;
    begin
        Result.Get(DomainCode);
        Result."Status" := Result."Status"::Running;
        Result."Run DateTime" := CurrentDateTime();
        Result.Modify(true);
        Commit();

        StartTime := CurrentDateTime();
        ClearLastError();
        case DomainCode of
            '1-MOVE':
                Ok := TryMove(Detail, PostedDoc);
            '2-COUNT':
                Ok := TryCount(Detail, PostedDoc);
            '3-RECEIPT':
                Ok := TryReceipt(Detail, PostedDoc);
            '4-PUTAWAY':
                Ok := TryPutAway(Detail, PostedDoc);
            '5-SHIPMENT':
                Ok := TryShipment(Detail, PostedDoc);
            '6-PICK':
                Ok := TryPick(Detail, PostedDoc);
            '7-CONSUME':
                Ok := TryConsume(Detail, PostedDoc);
            '8-OUTPUT':
                Ok := TryOutput(Detail, PostedDoc);
            '9-ASSEMBLY':
                Ok := TryAssembly(Detail, PostedDoc);
        end;

        Result.Get(DomainCode);
        if Ok then begin
            Result."Status" := Result."Status"::Passed;
            Result."Detail" := CopyStr(Detail, 1, MaxStrLen(Result."Detail"));
        end else begin
            Result."Status" := Result."Status"::Failed;
            if GetLastErrorText() <> '' then
                Result."Detail" := CopyStr(GetLastErrorText(), 1, MaxStrLen(Result."Detail"))
            else
                Result."Detail" := CopyStr(Detail, 1, MaxStrLen(Result."Detail"));
        end;
        Result."Posted Doc No." := PostedDoc;
        Result."Duration (ms)" := CurrentDateTime() - StartTime;
        Result.Modify(true);
        Commit();
    end;

    // ============================ Test data helpers ============================

    local procedure EnsureTestItem()
    var
        Item: Record Item;
    begin
        // Use an existing, fully-configured Cronus inventory item (with UoM + posting groups) rather
        // than creating one — item OnInsert (no. series / templates) makes ad-hoc creation unreliable.
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetRange(Blocked, false);
        Item.SetFilter("Base Unit of Measure", '<>%1', '');
        Item.SetFilter("Inventory Posting Group", '<>%1', '');
        Item.SetFilter("Gen. Prod. Posting Group", '<>%1', '');
        Item.FindFirst();
        TestItemNo := Item."No.";
    end;

    /// <summary>Posts a positive adjustment so the test item has on-hand inventory at (location, bin).</summary>
    local procedure StockItem(LocationCode: Code[10]; BinCode: Code[20]; Qty: Decimal)
    begin
        StockItemAt(TestItemNo, LocationCode, BinCode, Qty);
    end;

    local procedure StockItemAt(ItemNo: Code[20]; LocationCode: Code[10]; BinCode: Code[20]; Qty: Decimal)
    var
        ItemJnlLine: Record "Item Journal Line";
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlPostBatch: Codeunit "Item Jnl.-Post Batch";
    begin
        EnsureItemJnlBatch(ItemJnlTemplate, ItemJnlBatch);
        ItemJnlLine.SetRange("Journal Template Name", ItemJnlTemplate.Name);
        ItemJnlLine.SetRange("Journal Batch Name", ItemJnlBatch.Name);
        ItemJnlLine.DeleteAll();
        ItemJnlLine.Init();
        ItemJnlLine."Journal Template Name" := ItemJnlTemplate.Name;
        ItemJnlLine."Journal Batch Name" := ItemJnlBatch.Name;
        ItemJnlLine."Line No." := 10000;
        ItemJnlLine.Validate("Posting Date", WorkDate());
        ItemJnlLine.Validate("Entry Type", ItemJnlLine."Entry Type"::"Positive Adjmt.");
        ItemJnlLine."Document No." := 'DOPS-STK';
        ItemJnlLine.Validate("Item No.", ItemNo);
        ItemJnlLine.Validate("Location Code", LocationCode);
        if BinCode <> '' then
            ItemJnlLine.Validate("Bin Code", BinCode);
        ItemJnlLine.Validate(Quantity, Qty);
        EnsureInventoryPostingSetup(LocationCode, ItemNo);
        ItemJnlLine.Insert(true);
        // Post Batch (23) drives warehouse integration so Bin Content is created on bin-mandatory locations.
        ItemJnlPostBatch.Run(ItemJnlLine);
    end;

    local procedure EnsureInventoryPostingSetup(LocationCode: Code[10]; ItemNo: Code[20])
    var
        Item: Record Item;
        TargetSetup: Record "Inventory Posting Setup";
        SourceSetup: Record "Inventory Posting Setup";
        GLAccount: Record "G/L Account";
        InventoryAccountNo: Code[20];
    begin
        Item.Get(ItemNo);
        Item.TestField("Inventory Posting Group");

        if TargetSetup.Get(LocationCode, Item."Inventory Posting Group") then
            if TargetSetup."Inventory Account" <> '' then
                exit;

        SourceSetup.SetRange("Invt. Posting Group Code", Item."Inventory Posting Group");
        SourceSetup.SetFilter("Inventory Account", '<>%1', '');
        if SourceSetup.FindFirst() then
            InventoryAccountNo := SourceSetup."Inventory Account"
        else begin
            GLAccount.SetRange("Account Type", GLAccount."Account Type"::Posting);
            GLAccount.SetRange(Blocked, false);
            GLAccount.SetRange("Direct Posting", true);
            GLAccount.SetRange("Income/Balance", GLAccount."Income/Balance"::"Balance Sheet");
            if not GLAccount.FindFirst() then
                Error('Inventory Posting Setup cannot be prepared: no usable balance-sheet G/L Account exists for inventory account.');
            InventoryAccountNo := GLAccount."No.";
        end;

        if not TargetSetup.Get(LocationCode, Item."Inventory Posting Group") then begin
            TargetSetup.Init();
            TargetSetup.Validate("Location Code", LocationCode);
            TargetSetup.Validate("Invt. Posting Group Code", Item."Inventory Posting Group");
            TargetSetup.Validate("Inventory Account", InventoryAccountNo);
            TargetSetup.Insert(true);
        end else begin
            TargetSetup.Validate("Inventory Account", InventoryAccountNo);
            TargetSetup.Modify(true);
        end;
    end;

    local procedure EnsureItemJnlBatch(var ItemJnlTemplate: Record "Item Journal Template"; var ItemJnlBatch: Record "Item Journal Batch")
    begin
        ItemJnlTemplate.SetRange(Type, ItemJnlTemplate.Type::Item);
        ItemJnlTemplate.SetRange(Recurring, false);
        if not ItemJnlTemplate.FindFirst() then begin
            ItemJnlTemplate.Init();
            ItemJnlTemplate.Name := 'ITEM';
            ItemJnlTemplate.Type := ItemJnlTemplate.Type::Item;
            ItemJnlTemplate.Insert(true);
        end;
        if not ItemJnlBatch.Get(ItemJnlTemplate.Name, 'DOPS-POST') then begin
            ItemJnlBatch.Init();
            ItemJnlBatch."Journal Template Name" := ItemJnlTemplate.Name;
            ItemJnlBatch.Name := 'DOPS-POST';
            ItemJnlBatch.Description := 'DOPSWHS posting test';
            ItemJnlBatch.Insert(true);
        end;
    end;

    local procedure DefaultLocation(): Code[10]
    var
        Setup: Record "DOPSWHS Setup";
    begin
        if Setup.Get('') then
            exit(Setup."Default Location Code");
        exit('');
    end;

    // ============================ Domain tests ============================

    [TryFunction]
    local procedure TryMove(var Detail: Text; var PostedDoc: Code[35])
    var
        MovementMgmt: Codeunit "DOPSWHS Movement Mgmt";
        ItemLedgEntry: Record "Item Ledger Entry";
        BinContent: Record "Bin Content";
        Loc: Code[10];
        FromBin: Code[20];
        ToBin: Code[20];
        Before: Integer;
    begin
        Loc := DefaultLocation();
        if Loc = '' then
            Error('No default location configured.');
        StockItem(Loc, 'PICK-01', 20);

        // Adapt to wherever the adjustment actually landed (directed locations route to the adjustment
        // bin), so the reclass moves from a bin that genuinely holds stock.
        BinContent.SetRange("Location Code", Loc);
        BinContent.SetRange("Item No.", TestItemNo);
        FromBin := '';
        if BinContent.FindSet() then
            repeat
                BinContent.CalcFields(Quantity);
                if (FromBin = '') and (BinContent.Quantity > 0) then
                    FromBin := BinContent."Bin Code";
            until BinContent.Next() = 0;
        if FromBin = '' then
            Error('Positive adjustment created no bin content for %1 on %2 (location may require warehouse docs for inventory changes).', TestItemNo, Loc);
        if FromBin = 'PICK-01' then ToBin := 'BULK-01' else ToBin := 'PICK-01';

        ItemLedgEntry.SetRange("Item No.", TestItemNo);
        Before := ItemLedgEntry.Count();

        MovementMgmt.AdHocMove(FromBin, ToBin, TestItemNo, '', 5, 'POSTTEST');

        ItemLedgEntry.SetRange("Item No.", TestItemNo);
        if ItemLedgEntry.Count() <= Before then
            Error('Ad-hoc move posted no item ledger entries.');
        PostedDoc := 'RECLASS';
        Detail := StrSubstNo('Reclassed 5 %1 %2->%3 on %4', TestItemNo, FromBin, ToBin, Loc);
    end;

    [TryFunction]
    local procedure TryCount(var Detail: Text; var PostedDoc: Code[35])
    var
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
        CountHeader: Record "DOPSWHS Count Sheet Header";
        CountLine: Record "DOPSWHS Count Sheet Line";
        Counters: array[3] of Code[50];
        SheetNo: Code[20];
    begin
        Counters[1] := 'POSTTEST';
        // Single-line sheet for a known item/bin (NOT GenerateLines over the whole location, which
        // would post zero-counts as write-offs for every uncounted bin).
        StockItem(DefaultLocation(), 'PICK-01', 7);
        SheetNo := CountMgmt.CreateSheet(DefaultLocation(), "DOPSWHS Count Mode"::Visible, Counters);
        CountMgmt.AddLine(SheetNo, TestItemNo, '', 'PICK-01');
        CountLine.SetRange("Sheet No.", SheetNo);
        CountLine.FindFirst();
        // Count exactly the system qty => zero variance => no recount => clean post.
        CountMgmt.RecordCount(SheetNo, CountLine."Line No.", 1, CountLine."System Qty");
        CountMgmt.PostSheet(SheetNo);

        CountHeader.Get(SheetNo);
        if CountHeader.Status <> CountHeader.Status::Posted then
            Error('Count sheet %1 not posted (status %2).', SheetNo, CountHeader.Status);
        PostedDoc := SheetNo;
        Detail := StrSubstNo('Posted count sheet %1 (item %2, bin PICK-01).', SheetNo, TestItemNo);
    end;

    [TryFunction]
    local procedure TryReceipt(var Detail: Text; var PostedDoc: Code[35])
    var
        ReceiptMgmt: Codeunit "DOPSWHS Receipt Mgmt";
        PurchHeader: Record "Purchase Header";
        WhseReceiptHeader: Record "Warehouse Receipt Header";
        WhseReceiptLine: Record "Warehouse Receipt Line";
        PostedWhseRcptLine: Record "Posted Whse. Receipt Line";
        WmsLoc: Code[10];
    begin
        WmsLoc := WmsLocation();
        CreatePurchOrder(PurchHeader, WmsLoc);
        CreateWhseReceiptFromPurch(PurchHeader, WhseReceiptHeader);

        WhseReceiptLine.SetRange("No.", WhseReceiptHeader."No.");
        WhseReceiptLine.FindFirst();
        WhseReceiptLine.Validate("Qty. to Receive", WhseReceiptLine."Qty. Outstanding");
        WhseReceiptLine.Modify(true);

        ReceiptMgmt.PostReceipt(WhseReceiptHeader, false, false);

        PostedWhseRcptLine.SetRange("Whse. Receipt No.", WhseReceiptHeader."No.");
        if PostedWhseRcptLine.IsEmpty() then
            Error('No posted warehouse receipt line found for %1.', WhseReceiptHeader."No.");
        PostedWhseRcptLine.FindFirst();
        PostedDoc := PostedWhseRcptLine."Posted Source No.";
        Detail := StrSubstNo('Posted whse receipt from PO %1 on %2.', PurchHeader."No.", WmsLoc);
    end;

    [TryFunction]
    local procedure TryPutAway(var Detail: Text; var PostedDoc: Code[35])
    var
        WhseActivityHeader: Record "Warehouse Activity Header";
        WhseActivityLine: Record "Warehouse Activity Line";
        WhseActivityRegister: Codeunit "Whse.-Activity-Register";
        WmsLoc: Code[10];
    begin
        WmsLoc := WmsLocation();
        // Posting a receipt on a require-put-away location auto-creates a put-away activity.
        WhseActivityHeader.SetRange(Type, WhseActivityHeader.Type::"Put-away");
        WhseActivityHeader.SetRange("Location Code", WmsLoc);
        if not WhseActivityHeader.FindFirst() then
            Error('No open put-away activity on %1 (post a receipt first).', WmsLoc);

        WhseActivityLine.SetRange("Activity Type", WhseActivityHeader.Type);
        WhseActivityLine.SetRange("No.", WhseActivityHeader."No.");
        WhseActivityLine.FindSet();
        repeat
            WhseActivityLine.Validate("Qty. to Handle", WhseActivityLine."Qty. Outstanding");
            WhseActivityLine.Modify(true);
        until WhseActivityLine.Next() = 0;

        WhseActivityLine.FindFirst();
        WhseActivityRegister.Run(WhseActivityLine);
        PostedDoc := WhseActivityHeader."No.";
        Detail := StrSubstNo('Registered put-away %1 on %2.', WhseActivityHeader."No.", WmsLoc);
    end;

    [TryFunction]
    local procedure TryShipment(var Detail: Text; var PostedDoc: Code[35])
    var
        ShipmentMgmt: Codeunit "DOPSWHS Shipment Mgmt";
        SalesHeader: Record "Sales Header";
        WhseShipmentHeader: Record "Warehouse Shipment Header";
        WmsLoc: Code[10];
    begin
        WmsLoc := ShipmentOnlyLocation();
        StockItem(WmsLoc, '', 20);  // ensure on-hand exists to ship without a directed pick
        CreateSalesOrder(SalesHeader, WmsLoc);
        CreateWhseShipmentFromSales(SalesHeader, WhseShipmentHeader);
        PrepareWhseShipmentLines(WhseShipmentHeader);
        ShipmentMgmt.PostShipment(WhseShipmentHeader, false, false);
        PostedDoc := WhseShipmentHeader."No.";
        Detail := StrSubstNo('Posted whse shipment from SO %1 on %2.', SalesHeader."No.", WmsLoc);
    end;

    [TryFunction]
    local procedure TryPick(var Detail: Text; var PostedDoc: Code[35])
    var
        RegdWhseActivityLine: Record "Registered Whse. Activity Line";
    begin
        // Pick is a separate flow; confirm at least one registered pick exists.
        RegdWhseActivityLine.SetRange("Activity Type", RegdWhseActivityLine."Activity Type"::Pick);
        if RegdWhseActivityLine.IsEmpty() then
            Error('No registered pick found (shipment flow must run first).');
        RegdWhseActivityLine.FindLast();
        PostedDoc := RegdWhseActivityLine."No.";
        Detail := StrSubstNo('Registered pick %1 confirmed.', RegdWhseActivityLine."No.");
    end;

    [TryFunction]
    local procedure TryConsume(var Detail: Text; var PostedDoc: Code[35])
    var
        ProdMgmt: Codeunit "DOPSWHS Prod Mgmt";
        ProdOrderComp: Record "Prod. Order Component";
    begin
        if PreparedProdOrderNo = '' then
            Error('No production order with BOM + routing available (no manufactured item in this company).');
        ProdOrderComp.SetRange(Status, ProdOrderComp.Status::Released);
        ProdOrderComp.SetRange("Prod. Order No.", PreparedProdOrderNo);
        if not ProdOrderComp.FindFirst() then
            Error('Released prod order %1 has no components.', PreparedProdOrderNo);
        // Stock the component so consumption doesn't fail on availability.
        StockProdOrderComponents(PreparedProdOrderNo);
        ProdMgmt.ConsumeByProdOrder(PreparedProdOrderNo, ProdOrderComp."Line No.", ProdOrderComp."Item No.", 1, '', '', '', ProdOrderComp."Bin Code");
        PostedDoc := PreparedProdOrderNo;
        Detail := StrSubstNo('Consumed component %1 on prod order %2.', ProdOrderComp."Item No.", PreparedProdOrderNo);
    end;

    [TryFunction]
    local procedure TryOutput(var Detail: Text; var PostedDoc: Code[35])
    var
        ProdMgmt: Codeunit "DOPSWHS Prod Mgmt";
        ProdOrderLine: Record "Prod. Order Line";
        ProdOrderRtngLine: Record "Prod. Order Routing Line";
    begin
        if PreparedProdOrderNo = '' then
            Error('No production order with BOM + routing available (no manufactured item in this company).');
        ProdOrderRtngLine.SetRange(Status, ProdOrderRtngLine.Status::Released);
        ProdOrderRtngLine.SetRange("Prod. Order No.", PreparedProdOrderNo);
        if not ProdOrderRtngLine.FindLast() then
            Error('Released prod order %1 has no routing lines.', PreparedProdOrderNo);
        ProdOrderLine.Get(ProdOrderRtngLine.Status, ProdOrderRtngLine."Prod. Order No.", ProdOrderRtngLine."Routing Reference No.");
        EnsureInventoryPostingSetup(ProdOrderLine."Location Code", ProdOrderLine."Item No.");
        StockProdOrderComponents(PreparedProdOrderNo);
        ProdMgmt.ReportOutputByProdOrder(PreparedProdOrderNo, ProdOrderRtngLine."Routing Reference No.", 1, 0, 5, '', '');
        PostedDoc := PreparedProdOrderNo;
        Detail := StrSubstNo('Reported output on prod order %1 op %2.', PreparedProdOrderNo, ProdOrderRtngLine."Operation No.");
    end;

    local procedure StockProdOrderComponents(ProdOrderNo: Code[20])
    var
        ProdOrderComp: Record "Prod. Order Component";
        StockQty: Decimal;
    begin
        ProdOrderComp.SetRange(Status, ProdOrderComp.Status::Released);
        ProdOrderComp.SetRange("Prod. Order No.", ProdOrderNo);
        if ProdOrderComp.FindSet() then
            repeat
                StockQty := Abs(ProdOrderComp."Remaining Quantity");
                if StockQty < 1000 then
                    StockQty := 1000;
                StockItemAt(ProdOrderComp."Item No.", ProdOrderComp."Location Code", ProdOrderComp."Bin Code", StockQty);
            until ProdOrderComp.Next() = 0;
    end;

    [TryFunction]
    local procedure TryAssembly(var Detail: Text; var PostedDoc: Code[35])
    var
        AssemblyMgmt: Codeunit "DOPSWHS Assembly Mgmt";
        AssemblyHeader: Record "Assembly Header";
        AssemblyLine: Record "Assembly Line";
    begin
        EnsureReleasedAssemblyOrder(AssemblyHeader);
        // Stock each component generously at its consumption location so PostAssembly can consume it.
        AssemblyLine.SetRange("Document Type", AssemblyHeader."Document Type");
        AssemblyLine.SetRange("Document No.", AssemblyHeader."No.");
        AssemblyLine.SetRange(Type, AssemblyLine.Type::Item);
        if AssemblyLine.FindSet() then
            repeat
                StockItemAt(AssemblyLine."No.", AssemblyLine."Location Code", AssemblyLine."Bin Code", AssemblyLine."Quantity per" * AssemblyHeader.Quantity + 100);
            until AssemblyLine.Next() = 0;

        AssemblyHeader.Get(AssemblyHeader."Document Type", AssemblyHeader."No.");
        AssemblyMgmt.PostAssembly(AssemblyHeader);
        PostedDoc := AssemblyHeader."No.";
        Detail := StrSubstNo('Posted assembly order %1 (item %2).', AssemblyHeader."No.", AssemblyHeader."Item No.");
    end;

    // ============================ BC document builders ============================

    local procedure WmsLocation(): Code[10]
    var
        Location: Record Location;
    begin
        // Prefer a fully directed location (require receive/ship/pick/put-away) like Cronus WHITE.
        Location.SetRange("Require Receive", true);
        Location.SetRange("Require Shipment", true);
        Location.SetRange("Require Pick", true);
        Location.SetRange("Require Put-away", true);
        Location.SetRange("Bin Mandatory", true);
        if Location.FindFirst() then
            exit(Location.Code);
        Error('No fully-directed WMS location (require receive/ship/pick/put-away) found.');
    end;

    local procedure ShipmentOnlyLocation(): Code[10]
    var
        Location: Record Location;
        NeedsModify: Boolean;
    begin
        // This test validates Whse. Shipment posting itself. Directed pick creation
        // is a separate BC page/SOAP action, so use a warehouse-shipment-only
        // location where the shipment can be posted directly from AL.
        if not Location.Get('DOPSSHIP') then begin
            Location.Init();
            Location.Code := 'DOPSSHIP';
            Location.Name := 'DOPSWHS shipment test';
            Location.Insert(true);
        end;

        if Location.Name = '' then begin
            Location.Name := 'DOPSWHS shipment test';
            NeedsModify := true;
        end;
        if (not Location."Require Shipment") or Location."Require Pick" or Location."Require Receive" or Location."Require Put-away" or Location."Bin Mandatory" then begin
            Location.Validate("Require Shipment", true);
            Location.Validate("Require Pick", false);
            Location.Validate("Require Receive", false);
            Location.Validate("Require Put-away", false);
            Location.Validate("Bin Mandatory", false);
            NeedsModify := true;
        end;
        if NeedsModify then
            Location.Modify(true);

        exit(Location.Code);
    end;

    local procedure CreatePurchOrder(var PurchHeader: Record "Purchase Header"; LocationCode: Code[10])
    var
        PurchLine: Record "Purchase Line";
        Vendor: Record Vendor;
        ReleasePurchDoc: Codeunit "Release Purchase Document";
    begin
        Vendor.FindFirst();
        PurchHeader.Init();
        PurchHeader.Validate("Document Type", PurchHeader."Document Type"::Order);
        PurchHeader.Insert(true);
        PurchHeader.Validate("Buy-from Vendor No.", Vendor."No.");
        PurchHeader.Validate("Location Code", LocationCode);
        PurchHeader.Modify(true);

        PurchLine.Init();
        PurchLine.Validate("Document Type", PurchHeader."Document Type");
        PurchLine.Validate("Document No.", PurchHeader."No.");
        PurchLine.Validate("Line No.", 10000);
        PurchLine.Validate(Type, PurchLine.Type::Item);
        PurchLine.Validate("No.", TestItemNo);
        PurchLine.Validate("Location Code", LocationCode);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Insert(true);

        ReleasePurchDoc.Run(PurchHeader);
    end;

    local procedure CreateWhseReceiptFromPurch(var PurchHeader: Record "Purchase Header"; var WhseReceiptHeader: Record "Warehouse Receipt Header")
    var
        GetSourceDocInbound: Codeunit "Get Source Doc. Inbound";
        WhseReceiptLine: Record "Warehouse Receipt Line";
    begin
        GetSourceDocInbound.CreateFromPurchOrderHideDialog(PurchHeader);  // no page-open callback
        WhseReceiptLine.SetRange("Source Document", WhseReceiptLine."Source Document"::"Purchase Order");
        WhseReceiptLine.SetRange("Source No.", PurchHeader."No.");
        WhseReceiptLine.FindFirst();
        WhseReceiptHeader.Get(WhseReceiptLine."No.");
    end;

    local procedure StockViaWhse(LocationCode: Code[10])
    var
        ReceiptMgmt: Codeunit "DOPSWHS Receipt Mgmt";
        PurchHeader: Record "Purchase Header";
        WhseReceiptHeader: Record "Warehouse Receipt Header";
        WhseReceiptLine: Record "Warehouse Receipt Line";
        WhseActivityHeader: Record "Warehouse Activity Header";
    begin
        CreatePurchOrder(PurchHeader, LocationCode);
        CreateWhseReceiptFromPurch(PurchHeader, WhseReceiptHeader);
        WhseReceiptLine.SetRange("No.", WhseReceiptHeader."No.");
        WhseReceiptLine.FindFirst();
        WhseReceiptLine.Validate("Qty. to Receive", WhseReceiptLine."Qty. Outstanding");
        WhseReceiptLine.Modify(true);
        ReceiptMgmt.PostReceipt(WhseReceiptHeader, false, false);
        // Register the auto-created put-away so stock lands in a pick bin.
        WhseActivityHeader.SetRange(Type, WhseActivityHeader.Type::"Put-away");
        WhseActivityHeader.SetRange("Location Code", LocationCode);
        if WhseActivityHeader.FindLast() then
            RegisterActivityByNo(WhseActivityHeader.Type, WhseActivityHeader."No.");
    end;

    local procedure CreateSalesOrder(var SalesHeader: Record "Sales Header"; LocationCode: Code[10])
    var
        SalesLine: Record "Sales Line";
        Customer: Record Customer;
        ReleaseSalesDoc: Codeunit "Release Sales Document";
    begin
        Customer.FindFirst();
        SalesHeader.Init();
        SalesHeader.Validate("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.Insert(true);
        SalesHeader.Validate("Sell-to Customer No.", Customer."No.");
        SalesHeader.Validate("Location Code", LocationCode);
        SalesHeader.Modify(true);

        SalesLine.Init();
        SalesLine.Validate("Document Type", SalesHeader."Document Type");
        SalesLine.Validate("Document No.", SalesHeader."No.");
        SalesLine.Validate("Line No.", 10000);
        SalesLine.Validate(Type, SalesLine.Type::Item);
        SalesLine.Validate("No.", TestItemNo);
        SalesLine.Validate("Location Code", LocationCode);
        SalesLine.Validate(Quantity, 3);
        SalesLine.Insert(true);

        ReleaseSalesDoc.Run(SalesHeader);
    end;

    local procedure CreateWhseShipmentFromSales(var SalesHeader: Record "Sales Header"; var WhseShipmentHeader: Record "Warehouse Shipment Header")
    var
        GetSourceDocOutbound: Codeunit "Get Source Doc. Outbound";
        WhseShipmentLine: Record "Warehouse Shipment Line";
    begin
        GetSourceDocOutbound.CreateFromSalesOrderHideDialog(SalesHeader);  // no page-open callback
        WhseShipmentLine.SetRange("Source Document", WhseShipmentLine."Source Document"::"Sales Order");
        WhseShipmentLine.SetRange("Source No.", SalesHeader."No.");
        WhseShipmentLine.FindFirst();
        WhseShipmentHeader.Get(WhseShipmentLine."No.");
    end;

    local procedure PrepareWhseShipmentLines(var WhseShipmentHeader: Record "Warehouse Shipment Header")
    var
        WhseShipmentLine: Record "Warehouse Shipment Line";
        WhseShipmentRelease: Codeunit "Whse.-Shipment Release";
    begin
        WhseShipmentLine.SetRange("No.", WhseShipmentHeader."No.");
        if WhseShipmentLine.FindSet(true) then
            repeat
                WhseShipmentLine.Validate("Qty. to Ship", WhseShipmentLine."Qty. Outstanding");
                WhseShipmentLine.Modify(true);
            until WhseShipmentLine.Next() = 0;

        WhseShipmentHeader.Get(WhseShipmentHeader."No.");
        if WhseShipmentHeader.Status <> WhseShipmentHeader.Status::Released then
            WhseShipmentRelease.Release(WhseShipmentHeader);
    end;

    local procedure CreatePickFromShipment(var WhseShipmentHeader: Record "Warehouse Shipment Header")
    var
        WhseShipmentLine: Record "Warehouse Shipment Line";
        WhseActivLine: Record "Warehouse Activity Line";
    begin
        WhseShipmentHeader.Find();
        WhseShipmentLine.SetRange("No.", WhseShipmentHeader."No.");
        WhseShipmentLine.FindSet();
        // Directed pick creation (report 7305 / WhseShptHeader.CreatePickDoc) has no extension-accessible
        // API in BC24. If a pick was created out-of-band, proceed; otherwise surface a clear instruction.
        WhseActivLine.SetRange("Whse. Document Type", WhseActivLine."Whse. Document Type"::Shipment);
        WhseActivLine.SetRange("Whse. Document No.", WhseShipmentHeader."No.");
        if WhseActivLine.IsEmpty() then
            Error('Whse shipment %1 created. Directed pick creation has no extension AL API in BC24 — create it via the published "DOPSWHSWarehouseShipment" web service (SOAP CreatePick) or the mobile Pick flow, then Post Shipment.', WhseShipmentHeader."No.");
    end;

    local procedure RegisterActivityByNo(ActivityType: Enum "Warehouse Activity Type"; ActivityNo: Code[20])
    var
        WhseActivityLine: Record "Warehouse Activity Line";
        WhseActivityRegister: Codeunit "Whse.-Activity-Register";
    begin
        WhseActivityLine.SetRange("Activity Type", ActivityType);
        WhseActivityLine.SetRange("No.", ActivityNo);
        if WhseActivityLine.FindSet() then
            repeat
                WhseActivityLine.Validate("Qty. to Handle", WhseActivityLine."Qty. Outstanding");
                WhseActivityLine.Modify(true);
            until WhseActivityLine.Next() = 0;
        WhseActivityLine.FindFirst();
        WhseActivityRegister.Run(WhseActivityLine);
    end;

    /// <summary>
    /// Creates (or reuses) a released production order with components + routing and stores its No. in
    /// PreparedProdOrderNo. MUST be called outside any TryFunction: the refresh report commits, which is
    /// illegal inside a try ("transaction is stopped"). Leaves PreparedProdOrderNo blank if no
    /// manufactured item exists, so the consume/output tests report that cleanly.
    /// </summary>
    local procedure PrepareProdOrder()
    var
        ProdOrder: Record "Production Order";
        ProdOrderComp: Record "Prod. Order Component";
        ProdOrderRtngLine: Record "Prod. Order Routing Line";
    begin
        PreparedProdOrderNo := '';
        // Reuse an existing released prod order that already has components and routing (postable).
        ProdOrder.SetRange(Status, ProdOrder.Status::Released);
        if ProdOrder.FindSet() then
            repeat
                ProdOrderComp.SetRange(Status, ProdOrderComp.Status::Released);
                ProdOrderComp.SetRange("Prod. Order No.", ProdOrder."No.");
                if not ProdOrderComp.IsEmpty() then begin
                    PreparedProdOrderNo := ProdOrder."No.";
                    ProdOrderRtngLine.SetRange(Status, ProdOrderRtngLine.Status::Released);
                    ProdOrderRtngLine.SetRange("Prod. Order No.", ProdOrder."No.");
                    if not ProdOrderRtngLine.IsEmpty() then
                        exit;
                    if TryAddRoutingLine() then begin
                        Commit();
                        exit;
                    end;
                    PreparedProdOrderNo := '';
                end;
            until ProdOrder.Next() = 0;

        // No ready prod order: build one by direct record inserts (the "Refresh Production Order" report's
        // RunModal can't run in a web-service session). Base (header+line+component, for Consume) is
        // committed first; the routing line (for Output) is then added best-effort. TryFunctions keep any
        // manufacturing-setup gap from aborting the whole run.
        if TryBuildProdOrderBase() then begin
            Commit();
            if TryAddRoutingLine() then
                Commit();
        end;
    end;

    [TryFunction]
    local procedure TryBuildProdOrderBase()
    var
        ProdOrder: Record "Production Order";
        ProdOrderLine: Record "Prod. Order Line";
        ProdOrderComp: Record "Prod. Order Component";
        ProdItem: Record Item;
        CompItem: Record Item;
    begin
        ProdItem.SetRange(Type, ProdItem.Type::Inventory);
        ProdItem.SetRange(Blocked, false);
        ProdItem.FindFirst();
        CompItem.SetRange(Type, CompItem.Type::Inventory);
        CompItem.SetRange(Blocked, false);
        CompItem.SetFilter("No.", '<>%1', ProdItem."No.");
        CompItem.FindFirst();

        ProdOrder.Init();
        ProdOrder.Status := ProdOrder.Status::Released;
        ProdOrder."No." := '';
        ProdOrder.Insert(true);
        ProdOrder.Validate("Source Type", ProdOrder."Source Type"::Item);
        ProdOrder.Validate("Source No.", ProdItem."No.");
        ProdOrder.Validate(Quantity, 2);
        ProdOrder.Validate("Due Date", WorkDate());
        ProdOrder.Modify(true);

        ProdOrderLine.Init();
        ProdOrderLine.Status := ProdOrder.Status;
        ProdOrderLine."Prod. Order No." := ProdOrder."No.";
        ProdOrderLine."Line No." := 10000;
        ProdOrderLine.Validate("Item No.", ProdItem."No.");
        ProdOrderLine.Validate(Quantity, 2);
        ProdOrderLine.Validate("Due Date", WorkDate());
        ProdOrderLine.Insert(true);

        ProdOrderComp.Init();
        ProdOrderComp.Status := ProdOrder.Status;
        ProdOrderComp."Prod. Order No." := ProdOrder."No.";
        ProdOrderComp."Prod. Order Line No." := ProdOrderLine."Line No.";
        ProdOrderComp."Line No." := 10000;
        ProdOrderComp.Validate("Item No.", CompItem."No.");
        ProdOrderComp.Validate("Quantity per", 1);
        ProdOrderComp.Validate("Due Date", WorkDate());
        ProdOrderComp.Insert(true);

        PreparedProdOrderNo := ProdOrder."No.";
    end;

    [TryFunction]
    local procedure TryAddRoutingLine()
    var
        ProdOrderLine: Record "Prod. Order Line";
        ProdOrderRtngLine: Record "Prod. Order Routing Line";
        WorkCenter: Record "Work Center";
    begin
        WorkCenter.FindFirst();
        ProdOrderLine.SetRange("Prod. Order No.", PreparedProdOrderNo);
        ProdOrderLine.FindFirst();
        ProdOrderRtngLine.Init();
        ProdOrderRtngLine.Status := ProdOrderLine.Status;
        ProdOrderRtngLine."Prod. Order No." := PreparedProdOrderNo;
        ProdOrderRtngLine."Routing No." := ProdOrderLine."Routing No.";
        ProdOrderRtngLine."Routing Reference No." := ProdOrderLine."Line No.";
        ProdOrderRtngLine."Operation No." := '10';
        ProdOrderRtngLine.Validate(Type, ProdOrderRtngLine.Type::"Work Center");
        ProdOrderRtngLine.Validate("No.", WorkCenter."No.");
        ProdOrderRtngLine.Insert(true);
    end;

    local procedure EnsureReleasedAssemblyOrder(var AssemblyHeader: Record "Assembly Header")
    var
        AsmItem: Record Item;
        BOMComp: Record "BOM Component";
        ReleaseAssemblyDoc: Codeunit "Release Assembly Document";
    begin
        // Always create a FRESH order: re-posting a previously-attempted order collides with its
        // leftover Posted Assembly Header (a partial post commits the header before the qty check).

        // Find an item that is the parent of an assembly BOM (BOM Component rows).
        BOMComp.SetRange(Type, BOMComp.Type::Item);
        if not BOMComp.FindFirst() then
            Error('No assembly BOM (BOM Component) exists in this database.');
        AsmItem.Get(BOMComp."Parent Item No.");

        Clear(AssemblyHeader);
        AssemblyHeader.Init();
        AssemblyHeader.Validate("Document Type", AssemblyHeader."Document Type"::Order);
        AssemblyHeader.Insert(true);
        AssemblyHeader.Validate("Item No.", AsmItem."No.");
        AssemblyHeader.Validate(Quantity, 1);
        AssemblyHeader.Modify(true);
        ReleaseAssemblyDoc.Run(AssemblyHeader);  // PostAssembly requires Status = Released
        AssemblyHeader.Get(AssemblyHeader."Document Type", AssemblyHeader."No.");
    end;

    local procedure JsonEscape(Value: Text): Text
    begin
        Value := Value.Replace('\', '\\');
        Value := Value.Replace('"', '\"');
        Value := Value.Replace(NewLineChar(), ' ');
        exit(Value);
    end;

    local procedure NewLineChar(): Text[2]
    var
        CRLF: Text[2];
    begin
        CRLF[1] := 13;
        CRLF[2] := 10;
        exit(CRLF);
    end;
}
