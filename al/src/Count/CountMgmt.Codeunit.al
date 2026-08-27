codeunit 72050 "DOPSWHS Count Mgmt"
{
    Access = Public;

    procedure CreateSheet(LocationCode: Code[10]; CountMode: Enum "DOPSWHS Count Mode"; var Counters: array[3] of Code[50]): Code[20]
    var
        CountHeader: Record "DOPSWHS Count Sheet Header";
        ItemJournalBatch: Record "Item Journal Batch";
        Counter: Record "DOPSWHS Count Counter";
        Slot: Integer;
        Dimensions: Dictionary of [Text, Text];
    begin
        CountHeader.Init();
        CountHeader.Validate("Location Code", LocationCode);
        CountHeader.Validate(Mode, CountMode);
        CountHeader.Status := CountHeader.Status::Open;
        CountHeader.Insert(true);
        CountHeader."Source Phys. Inv. Journal Batch" := EnsurePhysInvBatch(CountHeader."No.");
        CountHeader.Modify(true);

        ItemJournalBatch.Get('PHYS. INV.', CountHeader."Source Phys. Inv. Journal Batch");
        for Slot := 1 to 3 do
            if Counters[Slot] <> '' then begin
                Counter.Init();
                Counter."Sheet No." := CountHeader."No.";
                Counter."Counter Slot" := Slot;
                // Reuse the table validation so sheets cannot be created with an
                // unknown or disabled terminal user. The validation also records
                // the assignment timestamp consistently with manual assignment.
                Counter.Validate("User ID", Counters[Slot]);
                Counter.Insert(true);
            end;

        Dimensions.Add('sheetNo', CountHeader."No.");
        Dimensions.Add('locationCode', LocationCode);
        Session.LogMessage('AdvWMS.Count.SheetCreated', StrSubstNo('Count sheet %1 created.', CountHeader."No."), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dimensions);
        exit(CountHeader."No.");
    end;

    /// <summary>
    /// Creates a brand-new, empty V2 count sheet for the terminal operator.
    /// Keeping this server-side prevents the mobile app from creating a classic
    /// sheet and then leaving it half-converted if a second request fails.
    /// </summary>
    procedure CreateV2Sheet(LocationCode: Code[10]; OperatorUserId: Code[50]): Code[20]
    var
        Location: Record Location;
        Counters: array[3] of Code[50];
        SheetNo: Code[20];
    begin
        if LocationCode = '' then
            Error('Sayım V2 oluşturmak için lokasyon zorunludur.');
        if not Location.Get(LocationCode) then
            Error('%1 lokasyonu bulunamadı.', LocationCode);
        if OperatorUserId = '' then
            Error('Sayım V2 oluşturmak için terminal kullanıcı kimliği zorunludur. Yeniden giriş yapın.');

        Counters[1] := OperatorUserId;
        SheetNo := CreateSheet(LocationCode, Enum::"DOPSWHS Count Mode"::Visible, Counters);
        PrepareV2(SheetNo);
        exit(SheetNo);
    end;

    /// <summary>
    /// Populates count sheet lines from current Bin Content for the sheet's location, snapshotting
    /// the on-hand quantity into "System Qty". Idempotent: clears existing lines first. Returns the
    /// number of lines generated. This is the missing link that makes a sheet countable + postable.
    /// </summary>
    procedure GenerateLines(SheetNo: Code[20]) LinesCreated: Integer
    var
        CountHeader: Record "DOPSWHS Count Sheet Header";
        CountLine: Record "DOPSWHS Count Sheet Line";
        BinContent: Record "Bin Content";
        LPHeader: Record "DOPSWHS LP Header";
        LPLine: Record "DOPSWHS LP Line";
        Item: Record Item;
        WarehouseEntry: Record "Warehouse Entry";
        AllocatedQty: Dictionary of [Text, Decimal];
        AllocatedTrackingQty: Dictionary of [Text, Decimal];
        TrackingBalances: Dictionary of [Text, Decimal];
        TrackingKeys: List of [Text];
        AllocationKey: Text;
        TrackingKey: Text;
        LotNo: Code[50];
        SerialNo: Code[50];
        UomCode: Code[10];
        ResidualQty: Decimal;
        LooseTrackingQty: Decimal;
        TotalTrackedLooseQty: Decimal;
        UntrackedLooseQty: Decimal;
        NextLineNo: Integer;
    begin
        CountHeader.Get(SheetNo);
        if CountHeader.Status = CountHeader.Status::Posted then
            Error(CountAlreadyPostedErr, SheetNo);
        if CountHeader."V2 Scan Mode" then
            Error(V2SheetCannotGenerateErr, SheetNo);

        CountLine.SetRange("Sheet No.", SheetNo);
        CountLine.DeleteAll(true);

        // Önce palet/kap (LP) içerikleri ayrı satırlar olarak snapshot edilir.
        // Böylece depocu LP barkodunu okutup doğrudan o paletteki miktarı sayar.
        NextLineNo := 0;
        LPHeader.SetRange("Location Code", CountHeader."Location Code");
        LPHeader.SetFilter(Status, '%1|%2|%3', LPHeader.Status::Open, LPHeader.Status::Built, LPHeader.Status::Assigned);
        if LPHeader.FindSet() then
            repeat
                LPLine.SetRange("LP No.", LPHeader."No.");
                LPLine.SetFilter("Item No.", '<>%1', '');
                // Rafı henüz belli olmayan LP sayımın tamamını durdurmaz. Bu LP,
                // terminalde önce raf sonra LP okutulduğunda AttachLpToBin ile
                // ilgili rafa bağlanır ve satırları o anda sayım sayfasına eklenir.
                // Boş/test LP'ler de böylece bütün deponun sayımını engellemez.
                if (LPHeader."Bin Code" <> '') and LPLine.FindSet() then
                    repeat
                        UomCode := LPLine."Unit of Measure";
                        if (UomCode = '') and Item.Get(LPLine."Item No.") then
                            UomCode := Item."Base Unit of Measure";
                        NextLineNo += 10000;
                        CountLine.Init();
                        CountLine."Sheet No." := SheetNo;
                        CountLine."Line No." := NextLineNo;
                        CountLine."Item No." := LPLine."Item No.";
                        CountLine."Variant Code" := LPLine."Variant Code";
                        CountLine."Bin Code" := LPHeader."Bin Code";
                        CountLine."LP No." := LPHeader."No.";
                        CountLine."LP Line No." := LPLine."Line No.";
                        CountLine."Lot No." := LPLine."Lot No.";
                        CountLine."Serial No." := LPLine."Serial No.";
                        CountLine."Unit of Measure Code" := UomCode;
                        CountLine."System Qty" := LPLine.Quantity;
                        CountLine.Insert(true);
                        AddAllocatedQty(AllocatedQty, AllocationKeyFor(LPLine."Item No.", LPLine."Variant Code", LPHeader."Bin Code", UomCode), LPLine.Quantity);
                        AddAllocatedQty(
                            AllocatedTrackingQty,
                            TrackingAllocationKeyFor(
                                LPLine."Item No.", LPLine."Variant Code", LPHeader."Bin Code", UomCode,
                                LPLine."Lot No.", LPLine."Serial No."),
                            LPLine.Quantity);
                        LinesCreated += 1;
                    until LPLine.Next() = 0;
                LPLine.Reset();
            until LPHeader.Next() = 0;

        // LP'ye bağlı olmayan stok ayrıca sayılır. Aynı stok hem LP satırında hem
        // bin satırında iki kez oluşmasın diye LP miktarı bin içeriğinden düşülür.
        BinContent.SetRange("Location Code", CountHeader."Location Code");
        if BinContent.FindSet() then
            repeat
                BinContent.CalcFields(Quantity);
                UomCode := BinContent."Unit of Measure Code";
                if (UomCode = '') and Item.Get(BinContent."Item No.") then
                    UomCode := Item."Base Unit of Measure";
                AllocationKey := AllocationKeyFor(BinContent."Item No.", BinContent."Variant Code", BinContent."Bin Code", UomCode);
                ResidualQty := BinContent.Quantity;
                if AllocatedQty.ContainsKey(AllocationKey) then
                    ResidualQty -= AllocatedQty.Get(AllocationKey);
                if ResidualQty < 0 then
                    Error(LPExceedsInventoryErr, BinContent."Item No.", BinContent."Bin Code", -ResidualQty);

                // Bin Content miktarı lot/seri kırılımı taşımaz. Warehouse Entry
                // bakiyesini aynı madde/raf/UOM için gruplayarak her lotu ayrı
                // sayım satırı yaparız. Böylece terminalde hem sistem miktarı hem
                // de operatörün girdiği miktar hangi lota ait açıkça görünür.
                Clear(TrackingBalances);
                Clear(TrackingKeys);
                WarehouseEntry.Reset();
                WarehouseEntry.SetRange("Location Code", CountHeader."Location Code");
                WarehouseEntry.SetRange("Bin Code", BinContent."Bin Code");
                WarehouseEntry.SetRange("Item No.", BinContent."Item No.");
                WarehouseEntry.SetRange("Variant Code", BinContent."Variant Code");
                WarehouseEntry.SetRange("Unit of Measure Code", UomCode);
                WarehouseEntry.SetFilter("Lot No.", '<>%1', '');
                if WarehouseEntry.FindSet() then
                    repeat
                        TrackingKey := TrackingKeyFor(WarehouseEntry."Lot No.", WarehouseEntry."Serial No.");
                        AddTrackingBalance(TrackingBalances, TrackingKeys, TrackingKey, WarehouseEntry.Quantity);
                    until WarehouseEntry.Next() = 0;

                WarehouseEntry.Reset();
                WarehouseEntry.SetRange("Location Code", CountHeader."Location Code");
                WarehouseEntry.SetRange("Bin Code", BinContent."Bin Code");
                WarehouseEntry.SetRange("Item No.", BinContent."Item No.");
                WarehouseEntry.SetRange("Variant Code", BinContent."Variant Code");
                WarehouseEntry.SetRange("Unit of Measure Code", UomCode);
                WarehouseEntry.SetRange("Lot No.", '');
                WarehouseEntry.SetFilter("Serial No.", '<>%1', '');
                if WarehouseEntry.FindSet() then
                    repeat
                        TrackingKey := TrackingKeyFor('', WarehouseEntry."Serial No.");
                        AddTrackingBalance(TrackingBalances, TrackingKeys, TrackingKey, WarehouseEntry.Quantity);
                    until WarehouseEntry.Next() = 0;

                TotalTrackedLooseQty := 0;
                foreach TrackingKey in TrackingKeys do begin
                    SplitTrackingKey(TrackingKey, LotNo, SerialNo);
                    LooseTrackingQty := TrackingBalances.Get(TrackingKey);
                    AllocationKey := TrackingAllocationKeyFor(
                        BinContent."Item No.", BinContent."Variant Code", BinContent."Bin Code", UomCode,
                        LotNo, SerialNo);
                    if AllocatedTrackingQty.ContainsKey(AllocationKey) then
                        LooseTrackingQty -= AllocatedTrackingQty.Get(AllocationKey);
                    if LooseTrackingQty < 0 then
                        Error(TrackedLPExceedsInventoryErr, BinContent."Item No.", BinContent."Bin Code", LotNo, SerialNo, -LooseTrackingQty);
                    if LooseTrackingQty > 0 then begin
                        CreateLooseCountLine(
                            CountLine, SheetNo, NextLineNo,
                            BinContent."Item No.", BinContent."Variant Code", BinContent."Bin Code", UomCode,
                            LotNo, SerialNo, LooseTrackingQty);
                        LinesCreated += 1;
                        TotalTrackedLooseQty += LooseTrackingQty;
                    end;
                end;

                UntrackedLooseQty := ResidualQty - TotalTrackedLooseQty;
                if UntrackedLooseQty < 0 then
                    Error(TrackingBreakdownExceedsInventoryErr, BinContent."Item No.", BinContent."Bin Code", TotalTrackedLooseQty, ResidualQty);
                if UntrackedLooseQty > 0 then begin
                    CreateLooseCountLine(
                        CountLine, SheetNo, NextLineNo,
                        BinContent."Item No.", BinContent."Variant Code", BinContent."Bin Code", UomCode,
                        '', '', UntrackedLooseQty);
                    LinesCreated += 1;
                end;
            until BinContent.Next() = 0;
    end;

    /// <summary>
    /// İlk rafı bulunmayan bir LP'yi, terminalde okutulan rafa bağlar ve LP
    /// satırlarını açık sayım belgesine ekler. Aynı stok daha önce paletsiz
    /// bin satırı olarak üretildiği için o satırın sistem miktarı azaltılır;
    /// böylece stok hem LP hem paletsiz satırda iki kez sayılmaz.
    /// </summary>
    procedure AttachLpToBin(SheetNo: Code[20]; LpNo: Code[20]; BinCode: Code[20]) LinesCreated: Integer
    var
        CountHeader: Record "DOPSWHS Count Sheet Header";
        CountLine: Record "DOPSWHS Count Sheet Line";
        LPHeader: Record "DOPSWHS LP Header";
        LPLine: Record "DOPSWHS LP Line";
        Bin: Record Bin;
        Item: Record Item;
        LPMgt: Codeunit "DOPSWHS LP Management";
        UomCode: Code[10];
        NextLineNo: Integer;
    begin
        CountHeader.Get(SheetNo);
        if CountHeader.Status = CountHeader.Status::Posted then
            Error(CountAlreadyPostedErr, SheetNo);
        if BinCode = '' then
            Error(BinRequiredErr);
        if not Bin.Get(CountHeader."Location Code", BinCode) then
            Error(BinNotInLocationErr, BinCode, CountHeader."Location Code");
        if not LPHeader.Get(LpNo) then
            Error(LPNotFoundErr, LpNo);
        if LPHeader."Location Code" <> CountHeader."Location Code" then
            Error(LPLocationMismatchErr, LpNo, LPHeader."Location Code", CountHeader."Location Code");
        if not (LPHeader.Status in [LPHeader.Status::Open, LPHeader.Status::Built, LPHeader.Status::Assigned]) then
            Error(LPStatusNotCountableErr, LpNo, Format(LPHeader.Status));
        if (LPHeader."Bin Code" <> '') and (LPHeader."Bin Code" <> BinCode) then
            Error(LPAlreadyInOtherBinErr, LpNo, LPHeader."Bin Code", BinCode);

        // Aynı LP daha önce bu sayım sayfasına bağlandıysa işlem idempotenttir.
        CountLine.SetRange("Sheet No.", SheetNo);
        CountLine.SetRange("LP No.", LpNo);
        if not CountLine.IsEmpty() then begin
            if LPHeader."Bin Code" = '' then begin
                LPHeader.Validate("Bin Code", BinCode);
                LPHeader.Modify(true);
            end;
            exit(CountLine.Count());
        end;

        LPHeader.Validate("Bin Code", BinCode);
        LPHeader.Modify(true);
        LPMgt.WriteToLedger(LPHeader, Enum::"DOPSWHS LP Action"::Moved, '', BinCode, 0, '', '', SheetNo);

        CountLine.Reset();
        CountLine.SetRange("Sheet No.", SheetNo);
        if CountLine.FindLast() then
            NextLineNo := CountLine."Line No.";

        LPLine.SetRange("LP No.", LpNo);
        LPLine.SetFilter("Item No.", '<>%1', '');
        LPLine.SetFilter(Quantity, '>%1', 0);
        if LPLine.FindSet() then
            repeat
                UomCode := LPLine."Unit of Measure";
                if (UomCode = '') and Item.Get(LPLine."Item No.") then
                    UomCode := Item."Base Unit of Measure";

                ReduceLooseCountQty(
                    SheetNo, LPLine."Item No.", LPLine."Variant Code", BinCode,
                    UomCode, LPLine."Lot No.", LPLine."Serial No.", LPLine.Quantity, LpNo);

                NextLineNo += 10000;
                CountLine.Init();
                CountLine."Sheet No." := SheetNo;
                CountLine."Line No." := NextLineNo;
                CountLine."Item No." := LPLine."Item No.";
                CountLine."Variant Code" := LPLine."Variant Code";
                CountLine."Bin Code" := BinCode;
                CountLine."LP No." := LpNo;
                CountLine."LP Line No." := LPLine."Line No.";
                CountLine."Lot No." := LPLine."Lot No.";
                CountLine."Serial No." := LPLine."Serial No.";
                CountLine."Unit of Measure Code" := UomCode;
                CountLine."System Qty" := LPLine.Quantity;
                CountLine.Insert(true);
                LinesCreated += 1;
            until LPLine.Next() = 0;
    end;

    /// <summary>Adds (or refreshes) a single count line for a specific item/bin, snapshotting on-hand.</summary>
    procedure AddLine(SheetNo: Code[20]; ItemNo: Code[20]; VariantCode: Code[10]; BinCode: Code[20]): Integer
    var
        CountHeader: Record "DOPSWHS Count Sheet Header";
        CountLine: Record "DOPSWHS Count Sheet Line";
        BinContent: Record "Bin Content";
        Item: Record Item;
        NextLineNo: Integer;
        OnHand: Decimal;
    begin
        CountHeader.Get(SheetNo);
        CountLine.SetRange("Sheet No.", SheetNo);
        CountLine.SetRange("Item No.", ItemNo);
        CountLine.SetRange("Bin Code", BinCode);
        if CountLine.FindFirst() then
            exit(CountLine."Line No.");

        if BinContent.Get(CountHeader."Location Code", BinCode, ItemNo, VariantCode, '') then begin
            BinContent.CalcFields(Quantity);
            OnHand := BinContent.Quantity;
        end;

        CountLine.Reset();
        CountLine.SetRange("Sheet No.", SheetNo);
        if CountLine.FindLast() then
            NextLineNo := CountLine."Line No.";
        NextLineNo += 10000;

        CountLine.Init();
        CountLine."Sheet No." := SheetNo;
        CountLine."Line No." := NextLineNo;
        CountLine."Item No." := ItemNo;
        CountLine."Variant Code" := VariantCode;
        CountLine."Bin Code" := BinCode;
        if Item.Get(ItemNo) then
            CountLine."Unit of Measure Code" := Item."Base Unit of Measure";
        CountLine."System Qty" := OnHand;
        CountLine.Insert(true);
        exit(NextLineNo);
    end;

    /// <summary>
    /// Marks an empty count sheet for scan-created V2 lines. A sheet that already contains classic
    /// generated lines cannot be converted, preventing the two counting semantics from being mixed.
    /// </summary>
    procedure PrepareV2(SheetNo: Code[20])
    var
        CountHeader: Record "DOPSWHS Count Sheet Header";
        CountLine: Record "DOPSWHS Count Sheet Line";
    begin
        CountHeader.Get(SheetNo);
        if CountHeader.Status = CountHeader.Status::Posted then
            Error(CountAlreadyPostedErr, SheetNo);
        if CountHeader."V2 Scan Mode" then
            exit;

        CountLine.SetRange("Sheet No.", SheetNo);
        if not CountLine.IsEmpty() then
            Error(V2RequiresEmptySheetErr, SheetNo);

        CountHeader."V2 Scan Mode" := true;
        CountHeader.Modify(true);
    end;

    /// <summary>
    /// Atomically creates/fetches the exact item+bin+tracking line and adds the QR quantity to the
    /// selected counter. ScanId makes a retry idempotent when the HTTP response is lost.
    /// </summary>
    procedure ScanV2Label(SheetNo: Code[20]; ScanId: Guid; ItemNo: Code[20]; VariantCode: Code[10]; BinCode: Code[20]; UomCode: Code[10]; LotNo: Code[50]; SerialNo: Code[50]; Qty: Decimal; CounterSlot: Integer): Integer
    var
        CountHeader: Record "DOPSWHS Count Sheet Header";
        CountLine: Record "DOPSWHS Count Sheet Line";
        ScanEvent: Record "DOPSWHS Count V2 Scan";
        WarehouseEntry: Record "Warehouse Entry";
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        ItemUom: Record "Item Unit of Measure";
        ItemTrackingCode: Record "Item Tracking Code";
        Bin: Record Bin;
        NextLineNo: Integer;
        CurrentQty: Decimal;
        SystemQty: Decimal;
    begin
        if Qty <= 0 then
            Error(V2QtyPositiveErr);
        if not (CounterSlot in [1, 2, 3]) then
            Error(CounterSlotErr);

        // Serialize idempotency checks before touching the count line. A mobile timeout can safely
        // replay the same ScanId: the already committed line is returned without adding quantity.
        ScanEvent.LockTable();
        if ScanEvent.Get(ScanId) then begin
            if ScanEvent."Sheet No." <> SheetNo then
                Error(V2ScanIdConflictErr, ScanId);
            exit(ScanEvent."Line No.");
        end;

        PrepareV2(SheetNo);
        CountHeader.Get(SheetNo);
        if not Bin.Get(CountHeader."Location Code", BinCode) then
            Error(BinNotInLocationErr, BinCode, CountHeader."Location Code");

        Item.Get(ItemNo);
        if VariantCode <> '' then
            ItemVariant.Get(ItemNo, VariantCode);
        if UomCode = '' then
            UomCode := Item."Base Unit of Measure";
        ItemUom.Get(ItemNo, UomCode);

        if (Item."Item Tracking Code" <> '') and ItemTrackingCode.Get(Item."Item Tracking Code") then begin
            if (ItemTrackingCode."Lot Specific Tracking" or ItemTrackingCode."Lot Warehouse Tracking") and (LotNo = '') then
                Error(V2LotRequiredErr, ItemNo);
            if (ItemTrackingCode."SN Specific Tracking" or ItemTrackingCode."SN Warehouse Tracking") and (SerialNo = '') then
                Error(V2SerialRequiredErr, ItemNo);
        end;

        CountLine.LockTable();
        CountLine.SetRange("Sheet No.", SheetNo);
        CountLine.SetRange("Item No.", ItemNo);
        CountLine.SetRange("Variant Code", VariantCode);
        CountLine.SetRange("Bin Code", BinCode);
        CountLine.SetRange("LP No.", '');
        CountLine.SetRange("Unit of Measure Code", UomCode);
        CountLine.SetRange("Lot No.", LotNo);
        CountLine.SetRange("Serial No.", SerialNo);
        if not CountLine.FindFirst() then begin
            WarehouseEntry.SetRange("Location Code", CountHeader."Location Code");
            WarehouseEntry.SetRange("Bin Code", BinCode);
            WarehouseEntry.SetRange("Item No.", ItemNo);
            WarehouseEntry.SetRange("Variant Code", VariantCode);
            WarehouseEntry.SetRange("Unit of Measure Code", UomCode);
            WarehouseEntry.SetRange("Lot No.", LotNo);
            WarehouseEntry.SetRange("Serial No.", SerialNo);
            if WarehouseEntry.FindSet() then
                repeat
                    SystemQty += WarehouseEntry.Quantity;
                until WarehouseEntry.Next() = 0;

            CountLine.Reset();
            CountLine.SetRange("Sheet No.", SheetNo);
            if CountLine.FindLast() then
                NextLineNo := CountLine."Line No.";

            CountLine.Init();
            CountLine."Sheet No." := SheetNo;
            CountLine."Line No." := NextLineNo + 10000;
            CountLine."Item No." := ItemNo;
            CountLine."Variant Code" := VariantCode;
            CountLine."Bin Code" := BinCode;
            CountLine."Unit of Measure Code" := UomCode;
            CountLine."Lot No." := LotNo;
            CountLine."Serial No." := SerialNo;
            CountLine."System Qty" := SystemQty;
            CountLine."Unexpected Stock" := SystemQty <= 0;
            CountLine.Insert(true);
        end;

        if IsSlotCounted(CountLine, CounterSlot) then
            CurrentQty := CountedQtyForSlot(CountLine, CounterSlot);
        RecordCount(SheetNo, CountLine."Line No.", CounterSlot, CurrentQty + Qty);

        if CountHeader.Status = CountHeader.Status::Open then begin
            CountHeader.Status := CountHeader.Status::InProgress;
            CountHeader.Modify(true);
        end;

        ScanEvent.Init();
        ScanEvent."Scan ID" := ScanId;
        ScanEvent."Sheet No." := SheetNo;
        ScanEvent."Line No." := CountLine."Line No.";
        ScanEvent."Counter Slot" := CounterSlot;
        ScanEvent.Quantity := Qty;
        ScanEvent."Created DateTime" := CurrentDateTime();
        ScanEvent.Insert(true);
        exit(CountLine."Line No.");
    end;

    /// <summary>Idempotently subtracts the quantity contributed by one V2 scan event.</summary>
    procedure UndoV2Scan(SheetNo: Code[20]; ScanId: Guid): Integer
    var
        CountHeader: Record "DOPSWHS Count Sheet Header";
        CountLine: Record "DOPSWHS Count Sheet Line";
        ScanEvent: Record "DOPSWHS Count V2 Scan";
        CurrentQty: Decimal;
    begin
        CountHeader.Get(SheetNo);
        if CountHeader.Status = CountHeader.Status::Posted then
            Error(CountAlreadyPostedErr, SheetNo);
        if not CountHeader."V2 Scan Mode" then
            Error(NotV2SheetErr, SheetNo);

        ScanEvent.LockTable();
        if not ScanEvent.Get(ScanId) then
            Error(V2ScanNotFoundErr, ScanId);
        if ScanEvent."Sheet No." <> SheetNo then
            Error(V2ScanIdConflictErr, ScanId);
        if ScanEvent.Reversed then
            exit(ScanEvent."Line No.");

        CountLine.LockTable();
        CountLine.Get(SheetNo, ScanEvent."Line No.");
        if not IsSlotCounted(CountLine, ScanEvent."Counter Slot") then
            Error(V2UndoCountMissingErr, ScanId);
        CurrentQty := CountedQtyForSlot(CountLine, ScanEvent."Counter Slot");
        if CurrentQty < ScanEvent.Quantity then
            Error(V2UndoQtyErr, ScanId, CurrentQty, ScanEvent.Quantity);

        RecordCount(SheetNo, CountLine."Line No.", ScanEvent."Counter Slot", CurrentQty - ScanEvent.Quantity);
        ScanEvent.Reversed := true;
        ScanEvent.Modify(true);
        exit(CountLine."Line No.");
    end;

    /// <summary>
    /// Records stock that the operator physically finds in the scanned bin although the generated
    /// count sheet has no matching line. System Qty is deliberately zero so posting preserves the
    /// positive variance, including lot/serial tracking.
    /// </summary>
    procedure AddUnexpectedItem(SheetNo: Code[20]; ItemNo: Code[20]; VariantCode: Code[10]; BinCode: Code[20]; UomCode: Code[10]; LotNo: Code[50]; SerialNo: Code[50]; Qty: Decimal; CounterSlot: Integer): Integer
    var
        CountHeader: Record "DOPSWHS Count Sheet Header";
        CountLine: Record "DOPSWHS Count Sheet Line";
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        ItemUom: Record "Item Unit of Measure";
        Bin: Record Bin;
        NextLineNo: Integer;
    begin
        CountHeader.Get(SheetNo);
        if CountHeader.Status = CountHeader.Status::Posted then
            Error(CountAlreadyPostedErr, SheetNo);
        if Qty <= 0 then
            Error(UnexpectedQtyPositiveErr);
        if not (CounterSlot in [1, 2, 3]) then
            Error(CounterSlotErr);
        if not Bin.Get(CountHeader."Location Code", BinCode) then
            Error(BinNotInLocationErr, BinCode, CountHeader."Location Code");
        Item.Get(ItemNo);
        if VariantCode <> '' then
            ItemVariant.Get(ItemNo, VariantCode);
        if UomCode = '' then
            UomCode := Item."Base Unit of Measure";
        ItemUom.Get(ItemNo, UomCode);

        // A matching generated line may have been missed only because the scanned barcode did not
        // resolve to the BC item number. Reuse it instead of creating a duplicate variance line.
        CountLine.SetRange("Sheet No.", SheetNo);
        CountLine.SetRange("Item No.", ItemNo);
        CountLine.SetRange("Variant Code", VariantCode);
        CountLine.SetRange("Bin Code", BinCode);
        CountLine.SetRange("LP No.", '');
        CountLine.SetRange("Unit of Measure Code", UomCode);
        CountLine.SetRange("Lot No.", LotNo);
        CountLine.SetRange("Serial No.", SerialNo);
        if CountLine.FindFirst() then begin
            RecordCount(SheetNo, CountLine."Line No.", CounterSlot, Qty);
            exit(CountLine."Line No.");
        end;

        CountLine.Reset();
        CountLine.SetRange("Sheet No.", SheetNo);
        if CountLine.FindLast() then
            NextLineNo := CountLine."Line No.";

        CountLine.Init();
        CountLine."Sheet No." := SheetNo;
        CountLine."Line No." := NextLineNo + 10000;
        CountLine."Item No." := ItemNo;
        CountLine."Variant Code" := VariantCode;
        CountLine."Bin Code" := BinCode;
        CountLine."Unit of Measure Code" := UomCode;
        CountLine."Lot No." := LotNo;
        CountLine."Serial No." := SerialNo;
        CountLine."System Qty" := 0;
        CountLine."Unexpected Stock" := true;
        SetCountValue(CountLine, CounterSlot, Qty);
        CountLine.Insert(true);
        exit(CountLine."Line No.");
    end;

    /// <summary>
    /// Records an existing LP that is physically found in a different bin. The original generated
    /// line remains in its system bin and will be counted as zero when that address is closed; new
    /// zero-system lines in the physical bin create the balancing positive variance.
    /// </summary>
    procedure AddUnexpectedLp(SheetNo: Code[20]; LpNo: Code[20]; BinCode: Code[20]; CounterSlot: Integer): Integer
    var
        CountHeader: Record "DOPSWHS Count Sheet Header";
        CountLine: Record "DOPSWHS Count Sheet Line";
        LPHeader: Record "DOPSWHS LP Header";
        LPLine: Record "DOPSWHS LP Line";
        Item: Record Item;
        Bin: Record Bin;
        UomCode: Code[10];
        NextLineNo: Integer;
        LinesCreated: Integer;
    begin
        CountHeader.Get(SheetNo);
        if CountHeader.Status = CountHeader.Status::Posted then
            Error(CountAlreadyPostedErr, SheetNo);
        if not (CounterSlot in [1, 2, 3]) then
            Error(CounterSlotErr);
        if not Bin.Get(CountHeader."Location Code", BinCode) then
            Error(BinNotInLocationErr, BinCode, CountHeader."Location Code");
        if not LPHeader.Get(LpNo) then
            Error(LPNotFoundErr, LpNo);
        if LPHeader."Location Code" <> CountHeader."Location Code" then
            Error(LPLocationMismatchErr, LpNo, LPHeader."Location Code", CountHeader."Location Code");
        if not (LPHeader.Status in [LPHeader.Status::Open, LPHeader.Status::Built, LPHeader.Status::Assigned]) then
            Error(LPStatusNotCountableErr, LpNo, Format(LPHeader.Status));

        CountLine.SetRange("Sheet No.", SheetNo);
        if CountLine.FindLast() then
            NextLineNo := CountLine."Line No.";

        LPLine.SetRange("LP No.", LpNo);
        LPLine.SetFilter("Item No.", '<>%1', '');
        LPLine.SetFilter(Quantity, '>%1', 0);
        if not LPLine.FindSet() then
            Error(LPHasNoCountableLinesErr, LpNo);
        repeat
            CountLine.Reset();
            CountLine.SetRange("Sheet No.", SheetNo);
            CountLine.SetRange("LP No.", LpNo);
            CountLine.SetRange("LP Line No.", LPLine."Line No.");
            CountLine.SetRange("Bin Code", BinCode);
            if CountLine.FindFirst() then
                SetCountValueAndModify(CountLine, CounterSlot, LPLine.Quantity)
            else begin
                UomCode := LPLine."Unit of Measure";
                if (UomCode = '') and Item.Get(LPLine."Item No.") then
                    UomCode := Item."Base Unit of Measure";
                NextLineNo += 10000;
                CountLine.Init();
                CountLine."Sheet No." := SheetNo;
                CountLine."Line No." := NextLineNo;
                CountLine."Item No." := LPLine."Item No.";
                CountLine."Variant Code" := LPLine."Variant Code";
                CountLine."Bin Code" := BinCode;
                CountLine."LP No." := LpNo;
                CountLine."LP Line No." := LPLine."Line No.";
                CountLine."Lot No." := LPLine."Lot No.";
                CountLine."Serial No." := LPLine."Serial No.";
                CountLine."Unit of Measure Code" := UomCode;
                CountLine."System Qty" := 0;
                CountLine."Unexpected Stock" := true;
                SetCountValue(CountLine, CounterSlot, LPLine.Quantity);
                CountLine.Insert(true);
            end;
            LinesCreated += 1;
        until LPLine.Next() = 0;
        exit(LinesCreated);
    end;

    procedure StartRecount(SheetNo: Code[20])
    var
        CountHeader: Record "DOPSWHS Count Sheet Header";
        CountLine: Record "DOPSWHS Count Sheet Line";
    begin
        CountHeader.Get(SheetNo);
        if CountHeader.Status = CountHeader.Status::Posted then
            Error(CountAlreadyPostedErr, SheetNo);

        CountLine.SetRange("Sheet No.", SheetNo);
        if CountLine.FindSet(true) then
            repeat
                CountLine."Counted Qty 1" := 0;
                CountLine."Counted Qty 2" := 0;
                CountLine."Counted Qty 3" := 0;
                CountLine."Counted 1" := false;
                CountLine."Counted 2" := false;
                CountLine."Counted 3" := false;
                CountLine.Variance := 0;
                CountLine."Recount Required" := false;
                CountLine.Modify(true);
            until CountLine.Next() = 0;

        CountHeader.Status := CountHeader.Status::InProgress;
        CountHeader.Modify(true);
    end;

    procedure RecordCount(SheetNo: Code[20]; LineNo: Integer; CounterSlot: Integer; Qty: Decimal)
    var
        CountHeader: Record "DOPSWHS Count Sheet Header";
        CountLine: Record "DOPSWHS Count Sheet Line";
        Counter: Record "DOPSWHS Count Counter";
    begin
        if not (CounterSlot in [1, 2, 3]) then
            Error(CounterSlotErr);
        if Qty < 0 then
            Error(CountQtyNegativeErr);

        CountHeader.Get(SheetNo);
        if CountHeader.Status = CountHeader.Status::Posted then
            Error(CountAlreadyPostedErr, SheetNo);

        Counter.SetRange("Sheet No.", SheetNo);
        if not Counter.IsEmpty() then begin
            Counter.Reset();
            if not Counter.Get(SheetNo, CounterSlot) then
                Error(CounterNotAssignedErr, CounterSlot, SheetNo);
        end;

        CountLine.Get(SheetNo, LineNo);
        SetCountValue(CountLine, CounterSlot, Qty);
        EvaluateLineVariance(CountLine, SheetNo);
        CountLine.Modify(true);
    end;

    procedure EvaluateVariance(SheetNo: Code[20])
    var
        CountLine: Record "DOPSWHS Count Sheet Line";
    begin
        CountLine.SetRange("Sheet No.", SheetNo);
        if CountLine.FindSet(true) then
            repeat
                EvaluateLineVariance(CountLine, SheetNo);
                CountLine.Modify(true);
            until CountLine.Next() = 0;
    end;

    procedure PostSheet(SheetNo: Code[20])
    var
        CountHeader: Record "DOPSWHS Count Sheet Header";
        CountLine: Record "DOPSWHS Count Sheet Line";
        ItemJournalLine: Record "Item Journal Line";
        ItemJnlPostBatch: Codeunit "Item Jnl.-Post Batch";
        Dimensions: Dictionary of [Text, Text];
        LineNo: Integer;
        CountDocumentNo: Code[20];
    begin
        CountHeader.Get(SheetNo);
        if CountHeader.Status = CountHeader.Status::Posted then
            Error(CountAlreadyPostedErr, SheetNo);

        EnsureAllRequiredCountsRecorded(SheetNo);
        EvaluateVariance(SheetNo);
        CountLine.SetRange("Sheet No.", SheetNo);
        CountLine.SetRange("Recount Required", true);
        if not CountLine.IsEmpty() then begin
            // Uyuşmazlık bayrakları terminalde gösterilebilsin; stok postu henüz
            // başlamadığı için bu noktada yalnız analitik sayım sonucu kalıcıdır.
            Commit();
            Error(RecountRequiredErr, SheetNo);
        end;

        CountDocumentNo := CopyStr('CNT-' + SheetNo, 1, MaxStrLen(CountDocumentNo));
        Clear(ItemJournalLine);
        ItemJournalLine.SetRange("Journal Template Name", 'PHYS. INV.');
        ItemJournalLine.SetRange("Journal Batch Name", CountHeader."Source Phys. Inv. Journal Batch");
        ItemJournalLine.SetFilter("Document No.", '<>%1', CountDocumentNo);
        if not ItemJournalLine.IsEmpty() then
            Error(CountBatchContainsOtherLinesErr, CountHeader."Source Phys. Inv. Journal Batch", SheetNo);
        ItemJournalLine.SetRange("Document No.", CountDocumentNo);
        ItemJournalLine.DeleteAll(true);

        CountLine.Reset();
        CountLine.SetRange("Sheet No.", SheetNo);
        if CountLine.FindSet() then
            repeat
                LineNo += 10000;
                ItemJournalLine.Init();
                ItemJournalLine.Validate("Journal Template Name", 'PHYS. INV.');
                ItemJournalLine.Validate("Journal Batch Name", CountHeader."Source Phys. Inv. Journal Batch");
                ItemJournalLine."Line No." := LineNo;
                ItemJournalLine.Validate("Posting Date", Today());
                ItemJournalLine."Document No." := CountDocumentNo;
                ItemJournalLine.Validate("Item No.", CountLine."Item No.");
                ItemJournalLine.Validate("Location Code", CountHeader."Location Code");
                ItemJournalLine.Validate("Variant Code", CountLine."Variant Code");
                ItemJournalLine.Validate("Bin Code", CountLine."Bin Code");
                if CountLine."Unit of Measure Code" <> '' then
                    ItemJournalLine.Validate("Unit of Measure Code", CountLine."Unit of Measure Code");
                // Phys. inventory line: BC derives entry type + quantity from calculated vs counted.
                ItemJournalLine.Validate("Phys. Inventory", true);
                ItemJournalLine.Validate("Qty. (Calculated)", CountLine."System Qty");
                ItemJournalLine.Validate("Qty. (Phys. Inventory)", GetWinningQty(CountLine, SheetNo));
                ItemJournalLine.Insert(true);
                AddItemTracking(ItemJournalLine, CountLine."Lot No.", CountLine."Serial No.");
            until CountLine.Next() = 0;

        EnsureLicensePlateReferencesExist(SheetNo);

        ItemJournalLine.Reset();
        ItemJournalLine.SetRange("Journal Template Name", 'PHYS. INV.');
        ItemJournalLine.SetRange("Journal Batch Name", CountHeader."Source Phys. Inv. Journal Batch");
        ItemJournalLine.SetRange("Document No.", CountDocumentNo);
        if ItemJournalLine.FindFirst() then
            ItemJnlPostBatch.Run(ItemJournalLine);

        // BC stok postu başarılı olduktan sonra LP içeriğini aynı kazanan sayım
        // miktarıyla eşitle. Böylece etiket ve bir sonraki LP sorgusu yeni miktarı gösterir.
        ApplyWinningCountsToLicensePlates(SheetNo);

        CountHeader.Status := CountHeader.Status::Posted;
        CountHeader."Posted DateTime" := CurrentDateTime();
        CountHeader.Modify(true);

        Dimensions.Add('sheetNo', SheetNo);
        Session.LogMessage('AdvWMS.Count.SheetPosted', StrSubstNo('Count sheet %1 posted.', SheetNo), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dimensions);
    end;

    local procedure EnsureLicensePlateReferencesExist(SheetNo: Code[20])
    var
        CountLine: Record "DOPSWHS Count Sheet Line";
        LPLine: Record "DOPSWHS LP Line";
    begin
        CountLine.SetRange("Sheet No.", SheetNo);
        CountLine.SetFilter("LP No.", '<>%1', '');
        if CountLine.FindSet() then
            repeat
                if not LPLine.Get(CountLine."LP No.", CountLine."LP Line No.") then
                    Error(LPLineMissingErr, CountLine."LP No.", CountLine."LP Line No.");
            until CountLine.Next() = 0;
    end;

    local procedure AllocationKeyFor(ItemNo: Code[20]; VariantCode: Code[10]; BinCode: Code[20]; UomCode: Code[10]): Text
    begin
        exit(ItemNo + '|' + VariantCode + '|' + BinCode + '|' + UomCode);
    end;

    local procedure AddAllocatedQty(var AllocatedQty: Dictionary of [Text, Decimal]; AllocationKeyValue: Text; Qty: Decimal)
    begin
        if AllocatedQty.ContainsKey(AllocationKeyValue) then
            AllocatedQty.Set(AllocationKeyValue, AllocatedQty.Get(AllocationKeyValue) + Qty)
        else
            AllocatedQty.Add(AllocationKeyValue, Qty);
    end;

    local procedure ReduceLooseCountQty(SheetNo: Code[20]; ItemNo: Code[20]; VariantCode: Code[10]; BinCode: Code[20]; UomCode: Code[10]; LotNo: Code[50]; SerialNo: Code[50]; Qty: Decimal; LpNo: Code[20])
    var
        LooseLine: Record "DOPSWHS Count Sheet Line";
    begin
        LooseLine.SetRange("Sheet No.", SheetNo);
        LooseLine.SetRange("Item No.", ItemNo);
        LooseLine.SetRange("Variant Code", VariantCode);
        LooseLine.SetRange("Bin Code", BinCode);
        LooseLine.SetRange("LP No.", '');
        LooseLine.SetRange("Unit of Measure Code", UomCode);
        LooseLine.SetRange("Lot No.", LotNo);
        LooseLine.SetRange("Serial No.", SerialNo);
        if not LooseLine.FindFirst() then
            Error(LPStockMissingInBinErr, LpNo, ItemNo, Qty, BinCode);
        if IsSlotCounted(LooseLine, 1) or IsSlotCounted(LooseLine, 2) or IsSlotCounted(LooseLine, 3) then
            Error(LooseLineAlreadyCountedErr, ItemNo, BinCode, LpNo);
        if LooseLine."System Qty" < Qty then
            Error(LPStockInsufficientInBinErr, LpNo, ItemNo, Qty, BinCode, LooseLine."System Qty");

        LooseLine."System Qty" -= Qty;
        if LooseLine."System Qty" = 0 then
            LooseLine.Delete(true)
        else
            LooseLine.Modify(true);
    end;

    local procedure CreateLooseCountLine(var CountLine: Record "DOPSWHS Count Sheet Line"; SheetNo: Code[20]; var NextLineNo: Integer; ItemNo: Code[20]; VariantCode: Code[10]; BinCode: Code[20]; UomCode: Code[10]; LotNo: Code[50]; SerialNo: Code[50]; Qty: Decimal)
    begin
        NextLineNo += 10000;
        CountLine.Init();
        CountLine."Sheet No." := SheetNo;
        CountLine."Line No." := NextLineNo;
        CountLine."Item No." := ItemNo;
        CountLine."Variant Code" := VariantCode;
        CountLine."Bin Code" := BinCode;
        CountLine."Unit of Measure Code" := UomCode;
        CountLine."Lot No." := LotNo;
        CountLine."Serial No." := SerialNo;
        CountLine."System Qty" := Qty;
        CountLine.Insert(true);
    end;

    local procedure SetCountValue(var CountLine: Record "DOPSWHS Count Sheet Line"; CounterSlot: Integer; Qty: Decimal)
    begin
        case CounterSlot of
            1:
                begin
                    CountLine.Validate("Counted Qty 1", Qty);
                    CountLine."Counted 1" := true;
                end;
            2:
                begin
                    CountLine.Validate("Counted Qty 2", Qty);
                    CountLine."Counted 2" := true;
                end;
            3:
                begin
                    CountLine.Validate("Counted Qty 3", Qty);
                    CountLine."Counted 3" := true;
                end;
        end;
    end;

    local procedure SetCountValueAndModify(var CountLine: Record "DOPSWHS Count Sheet Line"; CounterSlot: Integer; Qty: Decimal)
    begin
        SetCountValue(CountLine, CounterSlot, Qty);
        CountLine.Modify(true);
    end;

    local procedure IsSlotCounted(CountLine: Record "DOPSWHS Count Sheet Line"; CounterSlot: Integer): Boolean
    begin
        // Non-zero fallback keeps in-progress sheets created before the counted flags were added
        // postable after an extension upgrade. A recorded zero is represented only by the flag.
        case CounterSlot of
            1:
                exit(CountLine."Counted 1" or (CountLine."Counted Qty 1" <> 0));
            2:
                exit(CountLine."Counted 2" or (CountLine."Counted Qty 2" <> 0));
            3:
                exit(CountLine."Counted 3" or (CountLine."Counted Qty 3" <> 0));
        end;
        exit(false);
    end;

    local procedure EnsureAllRequiredCountsRecorded(SheetNo: Code[20])
    var
        CountLine: Record "DOPSWHS Count Sheet Line";
        Counter: Record "DOPSWHS Count Counter";
    begin
        Counter.SetRange("Sheet No.", SheetNo);
        CountLine.SetRange("Sheet No.", SheetNo);
        if CountLine.FindSet() then
            repeat
                if Counter.IsEmpty() then begin
                    if not IsSlotCounted(CountLine, 1) then
                        Error(CountLineNotRecordedErr, CountLine."Line No.", 1);
                end else begin
                    Counter.Reset();
                    Counter.SetRange("Sheet No.", SheetNo);
                    if Counter.FindSet() then
                        repeat
                            if not IsSlotCounted(CountLine, Counter."Counter Slot") then
                                Error(CountLineNotRecordedErr, CountLine."Line No.", Counter."Counter Slot");
                        until Counter.Next() = 0;
                end;
            until CountLine.Next() = 0;
    end;

    local procedure AddTrackingBalance(var Balances: Dictionary of [Text, Decimal]; var Keys: List of [Text]; KeyValue: Text; Qty: Decimal)
    begin
        if Balances.ContainsKey(KeyValue) then
            Balances.Set(KeyValue, Balances.Get(KeyValue) + Qty)
        else begin
            Balances.Add(KeyValue, Qty);
            Keys.Add(KeyValue);
        end;
    end;

    local procedure TrackingKeyFor(LotNo: Code[50]; SerialNo: Code[50]): Text
    begin
        exit(LotNo + '|' + SerialNo);
    end;

    local procedure TrackingAllocationKeyFor(ItemNo: Code[20]; VariantCode: Code[10]; BinCode: Code[20]; UomCode: Code[10]; LotNo: Code[50]; SerialNo: Code[50]): Text
    begin
        exit(AllocationKeyFor(ItemNo, VariantCode, BinCode, UomCode) + '|' + TrackingKeyFor(LotNo, SerialNo));
    end;

    local procedure SplitTrackingKey(KeyValue: Text; var LotNo: Code[50]; var SerialNo: Code[50])
    var
        SeparatorPos: Integer;
    begin
        Clear(LotNo);
        Clear(SerialNo);
        SeparatorPos := StrPos(KeyValue, '|');
        if SeparatorPos = 0 then begin
            LotNo := CopyStr(KeyValue, 1, MaxStrLen(LotNo));
            exit;
        end;
        LotNo := CopyStr(KeyValue, 1, SeparatorPos - 1);
        SerialNo := CopyStr(KeyValue, SeparatorPos + 1, MaxStrLen(SerialNo));
    end;

    local procedure ApplyWinningCountsToLicensePlates(SheetNo: Code[20])
    var
        CountLine: Record "DOPSWHS Count Sheet Line";
        RelatedLine: Record "DOPSWHS Count Sheet Line";
        LPLine: Record "DOPSWHS LP Line";
        LPHeader: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
        ProcessedLines: Dictionary of [Text, Boolean];
        ProcessedLPs: Dictionary of [Code[20], Boolean];
        LineKey: Text;
        OldBinCode: Code[20];
        TotalWinningQty: Decimal;
    begin
        CountLine.SetRange("Sheet No.", SheetNo);
        CountLine.SetFilter("LP No.", '<>%1', '');
        if CountLine.FindSet() then
            repeat
                LineKey := CountLine."LP No." + '|' + Format(CountLine."LP Line No.");
                if not ProcessedLines.ContainsKey(LineKey) then begin
                    TotalWinningQty := 0;
                    RelatedLine.Reset();
                    RelatedLine.SetRange("Sheet No.", SheetNo);
                    RelatedLine.SetRange("LP No.", CountLine."LP No.");
                    RelatedLine.SetRange("LP Line No.", CountLine."LP Line No.");
                    if RelatedLine.FindSet() then
                        repeat
                            TotalWinningQty += GetWinningQty(RelatedLine, SheetNo);
                        until RelatedLine.Next() = 0;
                    if not LPLine.Get(CountLine."LP No.", CountLine."LP Line No.") then
                        Error(LPLineMissingErr, CountLine."LP No.", CountLine."LP Line No.");
                    LPLine.Validate(Quantity, TotalWinningQty);
                    LPLine.Modify(true);
                    ProcessedLines.Add(LineKey, true);
                end;

                // An LP physically found in another bin is moved only after the physical inventory
                // journal posts successfully. This preserves the A-bin shortage/B-bin surplus audit.
                if CountLine."Unexpected Stock" and
                   (GetWinningQty(CountLine, SheetNo) > 0) and
                   (not ProcessedLPs.ContainsKey(CountLine."LP No."))
                then begin
                    if LPHeader.Get(CountLine."LP No.") then begin
                        OldBinCode := LPHeader."Bin Code";
                        if OldBinCode <> CountLine."Bin Code" then begin
                            LPHeader.Validate("Bin Code", CountLine."Bin Code");
                            LPHeader.Modify(true);
                            LPMgt.WriteToLedger(
                                LPHeader, Enum::"DOPSWHS LP Action"::Moved,
                                OldBinCode, CountLine."Bin Code", 0, '', '', SheetNo);
                        end;
                    end;
                    ProcessedLPs.Add(CountLine."LP No.", true);
                end;
            until CountLine.Next() = 0;
    end;

    local procedure AddItemTracking(var ItemJournalLine: Record "Item Journal Line"; LotNo: Code[50]; SerialNo: Code[50])
    var
        TempReservEntry: Record "Reservation Entry" temporary;
        CreateReservEntry: Codeunit "Create Reserv. Entry";
    begin
        if ((LotNo = '') and (SerialNo = '')) or (ItemJournalLine.Quantity = 0) then
            exit;
        TempReservEntry."Lot No." := LotNo;
        TempReservEntry."Serial No." := SerialNo;
        CreateReservEntry.CreateReservEntryFor(
            Database::"Item Journal Line", ItemJournalLine."Entry Type".AsInteger(),
            ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name", 0,
            ItemJournalLine."Line No.", ItemJournalLine."Qty. per Unit of Measure",
            ItemJournalLine.Quantity, ItemJournalLine."Quantity (Base)", TempReservEntry);
        CreateReservEntry.CreateEntry(
            ItemJournalLine."Item No.", ItemJournalLine."Variant Code", ItemJournalLine."Location Code",
            ItemJournalLine.Description, 0D, 0D, 0, Enum::"Reservation Status"::Prospect);
    end;

    procedure EnsurePhysInvBatch(SheetNo: Code[20]): Code[10]
    var
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        BatchName: Code[10];
    begin
        BatchName := CopyStr('DOPS-CNT-' + SheetNo, 1, MaxStrLen(BatchName));
        if not ItemJournalTemplate.Get('PHYS. INV.') then begin
            ItemJournalTemplate.Init();
            ItemJournalTemplate.Name := 'PHYS. INV.';
            ItemJournalTemplate.Type := ItemJournalTemplate.Type::"Phys. Inventory";
            ItemJournalTemplate.Insert(true);
        end;
        if not ItemJournalBatch.Get('PHYS. INV.', BatchName) then begin
            ItemJournalBatch.Init();
            ItemJournalBatch."Journal Template Name" := 'PHYS. INV.';
            ItemJournalBatch.Name := BatchName;
            ItemJournalBatch.Description := CopyStr(StrSubstNo('Count sheet %1', SheetNo), 1, MaxStrLen(ItemJournalBatch.Description));
            ItemJournalBatch.Insert(true);
        end;
        exit(BatchName);
    end;

    local procedure GetAssignedCounterSlots(SheetNo: Code[20]; var CounterSlots: array[3] of Integer): Integer
    var
        Counter: Record "DOPSWHS Count Counter";
        AssignedCounterCount: Integer;
    begin
        Clear(CounterSlots);
        Counter.SetRange("Sheet No.", SheetNo);
        if Counter.FindSet() then
            repeat
                AssignedCounterCount += 1;
                CounterSlots[AssignedCounterCount] := Counter."Counter Slot";
            until (Counter.Next() = 0) or (AssignedCounterCount = ArrayLen(CounterSlots));

        // Eski sayım belgelerinde sayıcı kaydı olmayabilir; geriye uyumlulukta
        // yalnız slot 1 geçerlidir.
        if AssignedCounterCount = 0 then begin
            CounterSlots[1] := 1;
            AssignedCounterCount := 1;
        end;
        exit(AssignedCounterCount);
    end;

    local procedure CountedQtyForSlot(CountLine: Record "DOPSWHS Count Sheet Line"; CounterSlot: Integer): Decimal
    begin
        case CounterSlot of
            1:
                exit(CountLine."Counted Qty 1");
            2:
                exit(CountLine."Counted Qty 2");
            3:
                exit(CountLine."Counted Qty 3");
        end;
        exit(0);
    end;

    local procedure AllAssignedSlotsRecorded(CountLine: Record "DOPSWHS Count Sheet Line"; SheetNo: Code[20]): Boolean
    var
        CounterSlots: array[3] of Integer;
        AssignedCounterCount: Integer;
        CounterIndex: Integer;
    begin
        AssignedCounterCount := GetAssignedCounterSlots(SheetNo, CounterSlots);
        for CounterIndex := 1 to AssignedCounterCount do
            if not IsSlotCounted(CountLine, CounterSlots[CounterIndex]) then
                exit(false);
        exit(true);
    end;

    local procedure GetWinningQty(CountLine: Record "DOPSWHS Count Sheet Line"; SheetNo: Code[20]): Decimal
    var
        CounterSlots: array[3] of Integer;
        AssignedCounterCount: Integer;
        Qty1: Decimal;
        Qty2: Decimal;
        Qty3: Decimal;
    begin
        AssignedCounterCount := GetAssignedCounterSlots(SheetNo, CounterSlots);
        Qty1 := CountedQtyForSlot(CountLine, CounterSlots[1]);
        if AssignedCounterCount = 1 then
            exit(Qty1);

        Qty2 := CountedQtyForSlot(CountLine, CounterSlots[2]);
        if AssignedCounterCount = 2 then
            exit(Qty1); // Uyuşmazlık ShouldRecount ile postu durdurur; eşitse ikisi de aynıdır.

        Qty3 := CountedQtyForSlot(CountLine, CounterSlots[3]);
        if Qty1 = Qty2 then
            exit(Qty1);
        if Qty1 = Qty3 then
            exit(Qty1);
        if Qty2 = Qty3 then
            exit(Qty2);
        exit(Qty1);
    end;

    local procedure EvaluateLineVariance(var CountLine: Record "DOPSWHS Count Sheet Line"; SheetNo: Code[20])
    begin
        if not AllAssignedSlotsRecorded(CountLine, SheetNo) then begin
            CountLine.Variance := 0;
            CountLine."Recount Required" := false;
            exit;
        end;
        CountLine.Variance := GetWinningQty(CountLine, SheetNo) - CountLine."System Qty";
        CountLine."Recount Required" := ShouldRecount(CountLine, SheetNo);
    end;

    local procedure ShouldRecount(CountLine: Record "DOPSWHS Count Sheet Line"; SheetNo: Code[20]): Boolean
    var
        CounterSlots: array[3] of Integer;
        AssignedCounterCount: Integer;
        CounterIndex: Integer;
        FirstQty: Decimal;
    begin
        AssignedCounterCount := GetAssignedCounterSlots(SheetNo, CounterSlots);
        if AssignedCounterCount < 2 then
            exit(false);
        if not AllAssignedSlotsRecorded(CountLine, SheetNo) then
            exit(false);

        FirstQty := CountedQtyForSlot(CountLine, CounterSlots[1]);
        for CounterIndex := 2 to AssignedCounterCount do
            if Abs(FirstQty - CountedQtyForSlot(CountLine, CounterSlots[CounterIndex])) > 0 then
                exit(true);
        exit(false);
    end;

    var
        LPExceedsInventoryErr: Label '%1 ürününün %2 rafındaki LP miktarı BC stok miktarını %3 aşıyor. Sayım satırları üretilmeden önce LP/bin tutarsızlığını düzeltin.', Comment = '%1 item, %2 bin, %3 excess qty';
        LPLineMissingErr: Label '%1 LP numarasının %2 satırı artık bulunamadı. Sayım satırlarını yeniden üretin.', Comment = '%1 LP, %2 line';
        BinRequiredErr: Label 'Önce raf/bin barkodunu okutun.';
        BinNotInLocationErr: Label '%1 rafı %2 lokasyonunda bulunamadı.', Comment = '%1 bin, %2 location';
        LPNotFoundErr: Label '%1 LP numarası bulunamadı.', Comment = '%1 LP';
        LPLocationMismatchErr: Label '%1 LP numarası %2 lokasyonundadır; %3 lokasyonundaki bu sayıma bağlanamaz.', Comment = '%1 LP, %2 LP location, %3 count location';
        LPStatusNotCountableErr: Label '%1 LP numarasının durumu %2 olduğu için sayılamaz.', Comment = '%1 LP, %2 status';
        LPAlreadyInOtherBinErr: Label '%1 LP numarası sistemde %2 rafındadır; %3 rafına ilk atama yapılamaz. Önce fiziksel yerini doğrulayın.', Comment = '%1 LP, %2 current bin, %3 scanned bin';
        LPStockMissingInBinErr: Label '%1 LP içindeki %2 ürününden %3 adet için %4 rafında BC stoku bulunamadı.', Comment = '%1 LP, %2 item, %3 qty, %4 bin';
        LPStockInsufficientInBinErr: Label '%1 LP içindeki %2 ürününden %3 adet var; %4 rafındaki kullanılabilir BC stoku %5 adettir.', Comment = '%1 LP, %2 item, %3 LP qty, %4 bin, %5 available';
        LooseLineAlreadyCountedErr: Label '%1 ürününün %2 rafındaki paletsiz sayım satırı daha önce sayılmıştır. %3 LP numarası bu aşamada rafa bağlanamaz; sayım satırlarını yeniden üretin.', Comment = '%1 item, %2 bin, %3 LP';
        TrackedLPExceedsInventoryErr: Label '%1 ürününün %2 rafındaki lot/seri bakiyesinden LP miktarı fazladır (Lot: %3, Seri: %4, fark: %5). LP ve BC izleme kayıtlarını düzeltin.', Comment = '%1 item, %2 bin, %3 lot, %4 serial, %5 excess';
        TrackingBreakdownExceedsInventoryErr: Label '%1 ürününün %2 rafındaki lot/seri toplamı (%3), kullanılabilir raf stokunu (%4) aşıyor. BC izleme kayıtlarını düzeltin.', Comment = '%1 item, %2 bin, %3 tracked qty, %4 residual qty';
        CounterSlotErr: Label 'Sayıcı slotu 1, 2 veya 3 olmalıdır.';
        CountQtyNegativeErr: Label 'Sayım miktarı negatif olamaz.';
        CountAlreadyPostedErr: Label '%1 sayım belgesi daha önce kaydedildi; kapalı belge değiştirilemez.', Comment = '%1 count sheet no';
        CounterNotAssignedErr: Label '%1 sayıcı slotu %2 sayım belgesine atanmamıştır.', Comment = '%1 counter slot, %2 count sheet no';
        RecountRequiredErr: Label '%1 sayım belgesinde uyuşmayan satırlar var. Terminalde işaretlenen satırları yeniden sayın.', Comment = '%1 count sheet no';
        CountBatchContainsOtherLinesErr: Label '%1 fiziksel sayım batch''inde %2 belgesine ait olmayan satırlar var. Veri kaybını önlemek için kayıt durduruldu.', Comment = '%1 batch name, %2 count sheet no';
        UnexpectedQtyPositiveErr: Label 'Beklenmeyen fiziksel stok miktarı sıfırdan büyük olmalıdır.';
        CountLineNotRecordedErr: Label 'Sayım satırı %1, sayıcı slotu %2 tarafından henüz sayılmadı. Tüm satırlar sayılmadan kayıt yapılamaz.', Comment = '%1 line no, %2 counter slot';
        LPHasNoCountableLinesErr: Label '%1 LP numarasında sayılabilecek pozitif miktarlı ürün satırı yok.', Comment = '%1 LP no';
        V2SheetCannotGenerateErr: Label '%1 sayım belgesi Sayım V2 ile başlatıldı; klasik satır üretme işlemi kullanılamaz.', Comment = '%1 count sheet no';
        V2RequiresEmptySheetErr: Label '%1 sayım belgesinde klasik sayım satırları var. Sayım V2 için satır üretilmemiş boş bir belge seçin.', Comment = '%1 count sheet no';
        NotV2SheetErr: Label '%1 sayım belgesi Sayım V2 modunda değildir.', Comment = '%1 count sheet no';
        V2QtyPositiveErr: Label 'Sayım V2 QR miktarı sıfırdan büyük olmalıdır.';
        V2LotRequiredErr: Label '%1 ürünü lot takiplidir; QR içinde lot numarası bulunmalıdır.', Comment = '%1 item no';
        V2SerialRequiredErr: Label '%1 ürünü seri takiplidir; QR içinde seri numarası bulunmalıdır.', Comment = '%1 item no';
        V2ScanIdConflictErr: Label '%1 okutma kimliği başka bir sayım belgesinde kullanılmıştır.', Comment = '%1 scan guid';
        V2ScanNotFoundErr: Label '%1 okutması bulunamadığı için geri alınamadı.', Comment = '%1 scan guid';
        V2UndoCountMissingErr: Label '%1 okutmasının sayım değeri bulunamadığı için geri alınamadı.', Comment = '%1 scan guid';
        V2UndoQtyErr: Label '%1 okutması geri alınamadı: güncel miktar %2, okutmanın miktarı %3.', Comment = '%1 scan guid, %2 current qty, %3 scan qty';
}
