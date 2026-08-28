codeunit 72040 "DOPSWHS LP Management"
{
    Access = Public;
    Permissions =
        tabledata Item = R,
        tabledata "Item Unit of Measure" = R,
        tabledata "Item Tracking Code" = R,
        tabledata Location = R,
        tabledata Bin = R,
        tabledata "Bin Content" = R,
        tabledata "Warehouse Entry" = R;

    procedure Build(TemplateCode: Code[20]; LocationCode: Code[10]; BinCode: Code[20]; var LP: Record "DOPSWHS LP Header")
    var
        Template: Record "DOPSWHS LP Template";
        Location: Record Location;
        Bin: Record Bin;
    begin
        OnBeforeBuild(TemplateCode, LocationCode, BinCode, LP);
        if TemplateCode = '' then
            Error('LP şablon kodu zorunludur.');
        if not Template.Get(TemplateCode) then
            Error('%1 LP şablonu bulunamadı.', TemplateCode);
        if LocationCode = '' then
            Error('LP oluşturmak için lokasyon kodu zorunludur.');
        if not Location.Get(LocationCode) then
            Error('%1 lokasyonu bulunamadı.', LocationCode);
        if (BinCode <> '') and (not Bin.Get(LocationCode, BinCode)) then
            Error('%1 rafı %2 lokasyonunda bulunamadı.', BinCode, LocationCode);

        LogMutation('LP.Build');
        // Record.Init() primary key'i korur. Daha önce okunan LP numarasının
        // yeni LP oluşturulurken tekrar kullanılmasını engelle.
        Clear(LP);
        LP.Init();
        LP."LP Template Code" := TemplateCode;
        LP."Unit Type" := Template."Unit Type";
        LP."Location Code" := LocationCode;
        LP."Bin Code" := BinCode;
        LP.Status := LP.Status::Open;
        LP."Length cm" := Template."Default Length cm";
        LP."Width cm" := Template."Default Width cm";
        LP."Height cm" := Template."Default Height cm";
        LP.Insert(true);
        WriteToLedger(LP, LPActionBuilt(), '', BinCode, 0, '', '', '');
        OnAfterBuild(LP);
    end;

    procedure Stop(var LP: Record "DOPSWHS LP Header"; PrintLabel: Boolean)
    begin
        Stop(LP, PrintLabel, '');
    end;

    procedure Stop(var LP: Record "DOPSWHS LP Header"; PrintLabel: Boolean; PrinterId: Code[50])
    var
        Dispatcher: Codeunit "DOPSWHS Print Dispatcher";
        Generator: Codeunit "DOPSWHS SSCC Generator";
    begin
        OnBeforeStop(LP, PrintLabel);
        RequireStatus(LP, LP.Status::Open);
        LogMutation('LP.Stop');
        LP.Status := LP.Status::Built;
        if LP.SSCC = '' then
            LP.SSCC := Generator.Generate();
        LP.Modify(true);
        WriteToLedger(LP, LPActionBuilt(), LP."Bin Code", LP."Bin Code", 0, '', '', '');
        if PrintLabel then
            Dispatcher.PrintLPLabel(LP, PrinterId, 1);
        OnAfterStop(LP);
    end;

    procedure Reopen(var LP: Record "DOPSWHS LP Header")
    begin
        OnBeforeReopen(LP);
        RequireStatus(LP, LP.Status::Built);
        LogMutation('LP.Reopen');
        LP.Status := LP.Status::Open;
        LP.Modify(true);
        OnAfterReopen(LP);
    end;

    procedure AddLine(var LP: Record "DOPSWHS LP Header"; ItemNo: Code[20]; UoM: Code[10]; Qty: Decimal; LotNo: Code[50]; SerialNo: Code[50]; ExpiryDate: Date)
    var
        LPLine: Record "DOPSWHS LP Line";
    begin
        OnBeforeAddLine(LP, ItemNo, UoM, Qty);
        RequireStatus(LP, LP.Status::Open);
        LogMutation('LP.AddLine');
        LPLine.Init();
        LPLine."LP No." := LP."No.";
        LPLine.Validate("Item No.", ItemNo);
        LPLine."Unit of Measure" := UoM;
        LPLine.Validate(Quantity, Qty);
        LPLine."Lot No." := LotNo;
        LPLine."Serial No." := SerialNo;
        LPLine."Expiration Date" := ExpiryDate;
        LPLine.Insert(true);
        WriteToLedger(LP, LPActionItemAdded(), '', LP."Bin Code", Qty, ItemNo, LotNo + SerialNo, '');
        OnAfterAddLine(LP, LPLine);
    end;

    /// <summary>
    /// Adds an item to an open LP and, when the source bin differs from the LP bin, posts the real
    /// Business Central bin-to-bin movement first. This keeps Bin Content and LP contents aligned.
    /// </summary>
    [CommitBehavior(CommitBehavior::Error)]
    procedure AddLineFromBin(var LP: Record "DOPSWHS LP Header"; ItemNo: Code[20]; UoM: Code[10]; Qty: Decimal; LotNo: Code[50]; SerialNo: Code[50]; SourceBinCode: Code[20]; OperatorUserId: Code[50])
    var
        LPLine: Record "DOPSWHS LP Line";
        Item: Record Item;
        ItemUoM: Record "Item Unit of Measure";
        ItemTrackingCode: Record "Item Tracking Code";
        SourceBin: Record Bin;
        SourceBinInOtherLocation: Record Bin;
        TargetBin: Record Bin;
        MovementMgmt: Codeunit "DOPSWHS Movement Mgmt";
        EffectiveUoM: Code[10];
        MovementQty: Decimal;
    begin
        LP.LockTable();
        LP.Get(LP."No.");
        OnBeforeAddLine(LP, ItemNo, UoM, Qty);
        RequireStatus(LP, LP.Status::Open);
        if ItemNo = '' then
            Error('Madde numarası zorunludur.');
        if Qty <= 0 then
            Error('Miktar sıfırdan büyük olmalıdır.');
        LP.TestField("Location Code");
        LP.TestField("Bin Code");
        if SourceBinCode = '' then
            Error('Kaynak raf zorunludur.');

        Item.Get(ItemNo);
        if (Item."Item Tracking Code" <> '') and ItemTrackingCode.Get(Item."Item Tracking Code") then begin
            if (ItemTrackingCode."Lot Specific Tracking" or ItemTrackingCode."Lot Warehouse Tracking") and (LotNo = '') then
                Error('%1 lot takipli maddesi için lot numarası zorunludur. Stoktaki lotlardan birini seçin.', ItemNo);
            if (ItemTrackingCode."SN Specific Tracking" or ItemTrackingCode."SN Warehouse Tracking") and (SerialNo = '') then
                Error('%1 seri takipli maddesi için seri numarası zorunludur. Stoktaki seri numarasını okutun.', ItemNo);
        end;
        EffectiveUoM := UoM;
        if EffectiveUoM = '' then
            EffectiveUoM := Item."Base Unit of Measure";
        MovementQty := Qty;
        if EffectiveUoM <> Item."Base Unit of Measure" then begin
            ItemUoM.Get(ItemNo, EffectiveUoM);
            if ItemUoM."Qty. per Unit of Measure" <= 0 then
                Error('%1 maddesinin %2 birimi için birim başına miktar sıfırdan büyük olmalıdır.', ItemNo, EffectiveUoM);
            MovementQty := Qty * ItemUoM."Qty. per Unit of Measure";
        end;
        if (SerialNo <> '') and (MovementQty <> 1) then
            Error('%1 seri numarası tek bir temel birimi temsil eder; miktar 1 olmalıdır.', SerialNo);

        if not SourceBin.Get(LP."Location Code", SourceBinCode) then begin
            SourceBinInOtherLocation.SetRange(Code, SourceBinCode);
            if SourceBinInOtherLocation.FindFirst() then
                Error(
                    'Source bin %1 belongs to location %2 but LP %3 belongs to location %4. Cross-location LP line assignment is not allowed.',
                    SourceBinCode, SourceBinInOtherLocation."Location Code", LP."No.", LP."Location Code");
            Error('%1 kaynak rafı %2 lokasyonunda bulunamadı.', SourceBinCode, LP."Location Code");
        end;
        if not TargetBin.Get(LP."Location Code", LP."Bin Code") then
            Error('%1 LP hedef rafı %2 lokasyonunda bulunamadı.', LP."Bin Code", LP."Location Code");

        EnsureLooseStockAvailable(LP."Location Code", SourceBinCode, ItemNo, LotNo, SerialNo, MovementQty);

        LogMutation('LP.AddLineFromBin');
        if SourceBinCode <> LP."Bin Code" then
            MovementMgmt.AdHocMoveTrackedAtLocation(
                LP."Location Code", SourceBinCode, LP."Bin Code", ItemNo, LP."No.",
                MovementQty, OperatorUserId, LotNo, SerialNo);

        LPLine.Init();
        LPLine."LP No." := LP."No.";
        LPLine.Validate("Item No.", ItemNo);
        LPLine."Unit of Measure" := EffectiveUoM;
        LPLine.Validate(Quantity, Qty);
        LPLine."Lot No." := LotNo;
        LPLine."Serial No." := SerialNo;
        LPLine."Source Bin Code" := SourceBinCode;
        LPLine.Insert(true);
        WriteToLedger(LP, LPActionItemAdded(), SourceBinCode, LP."Bin Code", Qty, ItemNo, LotNo + SerialNo, '');
        OnAfterAddLine(LP, LPLine);
    end;

    /// <summary>
    /// Moves every item line carried by an LP to another bin and updates the LP header in the same
    /// server transaction. The mobile client must never post one movement per HTTP request and then
    /// patch the header: a later failure would leave Bin Content and the LP card out of sync.
    /// </summary>
    [CommitBehavior(CommitBehavior::Error)]
    procedure MoveToBin(var LP: Record "DOPSWHS LP Header"; TargetBinCode: Code[20]; OperatorUserId: Code[50])
    var
        LPLine: Record "DOPSWHS LP Line";
        Item: Record Item;
        ItemUoM: Record "Item Unit of Measure";
        SourceBin: Record Bin;
        TargetBin: Record Bin;
        MovementMgmt: Codeunit "DOPSWHS Movement Mgmt";
        SourceBinCode: Code[20];
        EffectiveUoM: Code[10];
        MovementQty: Decimal;
        TotalQty: Decimal;
    begin
        LP.LockTable();
        LP.Get(LP."No.");

        if OperatorUserId = '' then
            Error('%1 LP numarasını taşımak için operatör kullanıcı kimliği zorunludur.', LP."No.");
        if not (LP.Status in [LP.Status::Open, LP.Status::Built]) then
            Error('%1 LP numarası %2 durumundayken taşınamaz. Önce belge atamasını kaldırın.', LP."No.", LP.Status);
        LP.TestField("Location Code");
        LP.TestField("Bin Code");
        if TargetBinCode = '' then
            Error('%1 LP numarasını taşımak için hedef raf zorunludur.', LP."No.");

        SourceBinCode := LP."Bin Code";
        if SourceBinCode = TargetBinCode then
            Error('%1 LP numarası zaten %2 rafındadır.', LP."No.", TargetBinCode);
        if not SourceBin.Get(LP."Location Code", SourceBinCode) then
            Error('%1 kaynak rafı %2 lokasyonunda bulunamadı.', SourceBinCode, LP."Location Code");
        if not TargetBin.Get(LP."Location Code", TargetBinCode) then
            Error('%1 hedef rafı %2 lokasyonunda bulunamadı.', TargetBinCode, LP."Location Code");

        LPLine.SetRange("LP No.", LP."No.");
        if LPLine.FindSet() then
            repeat
                if LPLine."Child LP No." <> '' then
                    Error('%1 LP numarası iç içe %2 LP numarasını içeriyor. Ana LP taşınmadan önce bağlantıyı kaldırın.', LP."No.", LPLine."Child LP No.");
                if LPLine."Item No." = '' then
                    Error('%1 LP numarasının %2 satırında madde bulunmadığı için taşınamaz.', LP."No.", LPLine."Line No.");
                if LPLine."Variant Code" <> '' then
                    Error('%1 maddesinin %2 varyantı için LP hareketi desteklenmiyor. Standart depo hareketini kullanın.', LPLine."Item No.", LPLine."Variant Code");
                if LPLine.Quantity <= 0 then
                    Error('%1 LP numarasının %2 satırındaki miktar sıfırdan büyük olmalıdır.', LP."No.", LPLine."Line No.");

                Item.Get(LPLine."Item No.");
                EffectiveUoM := LPLine."Unit of Measure";
                if EffectiveUoM = '' then
                    EffectiveUoM := Item."Base Unit of Measure";
                MovementQty := LPLine.Quantity;
                if EffectiveUoM <> Item."Base Unit of Measure" then begin
                    ItemUoM.Get(LPLine."Item No.", EffectiveUoM);
                    if ItemUoM."Qty. per Unit of Measure" <= 0 then
                        Error('%1 maddesinin %2 birimi için birim başına miktar sıfırdan büyük olmalıdır.', LPLine."Item No.", EffectiveUoM);
                    MovementQty := LPLine.Quantity * ItemUoM."Qty. per Unit of Measure";
                end;
                if (LPLine."Serial No." <> '') and (MovementQty <> 1) then
                    Error('%1 seri numarası tek bir temel birimi temsil eder; miktar 1 olmalıdır.', LPLine."Serial No.");

                MovementMgmt.AdHocMoveTrackedAtLocation(
                    LP."Location Code", SourceBinCode, TargetBinCode, LPLine."Item No.", LP."No.",
                    MovementQty, OperatorUserId, LPLine."Lot No.", LPLine."Serial No.");
                TotalQty += LPLine.Quantity;
            until LPLine.Next() = 0;

        LogMutation('LP.MoveToBin');
        LP.Validate("Bin Code", TargetBinCode);
        LP.Modify(true);
        WriteToLedger(LP, LPActionTransferOut(), SourceBinCode, TargetBinCode, TotalQty, '', '', 'BIN-MOVE');
    end;

    procedure RemoveLine(var LPLine: Record "DOPSWHS LP Line")
    var
        LP: Record "DOPSWHS LP Header";
    begin
        LP.Get(LPLine."LP No.");
        OnBeforeRemoveLine(LPLine);
        RequireStatus(LP, LP.Status::Open);
        LogMutation('LP.RemoveLine');
        WriteToLedger(LP, LPActionItemRemoved(), LP."Bin Code", '', LPLine.Quantity, LPLine."Item No.", LPLine."Lot No." + LPLine."Serial No.", '');
        LPLine.Delete(true);
        OnAfterRemoveLine(LP);
    end;

    procedure Assign(var LP: Record "DOPSWHS LP Header"; DocType: Enum "DOPSWHS Assigned Doc Type"; DocNo: Code[20])
    begin
        OnBeforeAssign(LP, DocType, DocNo);
        RequireStatus(LP, LP.Status::Built);
        LogMutation('LP.Assign');
        LP.Status := LP.Status::Assigned;
        LP."Assigned Document Type" := DocType;
        LP."Assigned Document No." := DocNo;
        LP.Modify(true);
        WriteToLedger(LP, LPActionAssigned(), LP."Bin Code", LP."Bin Code", 0, '', '', Format(DocType) + ':' + DocNo);
        OnAfterAssign(LP);
    end;

    procedure Release(var LP: Record "DOPSWHS LP Header")
    begin
        OnBeforeRelease(LP);
        RequireStatus(LP, LP.Status::Assigned);
        LogMutation('LP.Release');
        LP.Status := LP.Status::Built;
        Clear(LP."Assigned Document Type");
        LP."Assigned Document No." := '';
        LP.Modify(true);
        WriteToLedger(LP, LPActionReleased(), LP."Bin Code", LP."Bin Code", 0, '', '', '');
        OnAfterRelease(LP);
    end;

    procedure Transfer(var SourceLP: Record "DOPSWHS LP Header"; var TargetLP: Record "DOPSWHS LP Header"; LineSelections: List of [Integer]; QtyByLine: Dictionary of [Integer, Decimal])
    var
        SourceLine: Record "DOPSWHS LP Line";
        TargetLine: Record "DOPSWHS LP Line";
        LineNo: Integer;
        TransferQty: Decimal;
    begin
        OnBeforeTransfer(SourceLP, TargetLP);
        if SourceLP."No." = TargetLP."No." then
            Error('Kaynak ve hedef LP aynı olamaz: %1.', SourceLP."No.");
        if not (SourceLP.Status in [SourceLP.Status::Open, SourceLP.Status::Built]) then
            Error('Kaynak LP %1 açık veya tamamlanmış durumda olmalıdır. Mevcut durum: %2.', SourceLP."No.", SourceLP.Status);
        if not (TargetLP.Status in [TargetLP.Status::Open, TargetLP.Status::Built]) then
            Error('Hedef LP %1 açık veya tamamlanmış durumda olmalıdır. Mevcut durum: %2.', TargetLP."No.", TargetLP.Status);
        SourceLP.TestField("Location Code");
        TargetLP.TestField("Location Code");
        if SourceLP."Location Code" <> TargetLP."Location Code" then
            Error(
                'LP transferi lokasyonlar arasında yapılamaz. Kaynak LP %1, %2; hedef LP %3, %4 lokasyonundadır.',
                SourceLP."No.", SourceLP."Location Code", TargetLP."No.", TargetLP."Location Code");
        if SourceLP."Bin Code" <> TargetLP."Bin Code" then
            Error(
                'LP içerik transferi için iki LP aynı rafta olmalıdır. Önce depo hareketiyle LP''yi taşıyın (%1 -> %2).',
                SourceLP."Bin Code", TargetLP."Bin Code");
        LogMutation('LP.Transfer');
        foreach LineNo in LineSelections do begin
            SourceLine.Get(SourceLP."No.", LineNo);
            if not QtyByLine.Get(LineNo, TransferQty) then
                TransferQty := SourceLine.Quantity;
            if (TransferQty <= 0) or (TransferQty > SourceLine.Quantity) then
                Error('%1 satırı için transfer miktarı geçersizdir.', LineNo);

            TargetLine.Init();
            TargetLine."LP No." := TargetLP."No.";
            TargetLine.Validate("Item No.", SourceLine."Item No.");
            TargetLine."Variant Code" := SourceLine."Variant Code";
            TargetLine."Unit of Measure" := SourceLine."Unit of Measure";
            TargetLine.Validate(Quantity, TransferQty);
            TargetLine."Lot No." := SourceLine."Lot No.";
            TargetLine."Serial No." := SourceLine."Serial No.";
            TargetLine."Package No." := SourceLine."Package No.";
            TargetLine."Expiration Date" := SourceLine."Expiration Date";
            TargetLine."Source Bin Code" := SourceLine."Source Bin Code";
            TargetLine."Source Document Type" := SourceLine."Source Document Type";
            TargetLine."Source Document No." := SourceLine."Source Document No.";
            TargetLine."Source Document Line No." := SourceLine."Source Document Line No.";
            TargetLine."Source Document Quantity" := SourceLine."Source Document Quantity";
            TargetLine.Insert(true);

            SourceLine.Validate(Quantity, SourceLine.Quantity - TransferQty);
            if SourceLine.Quantity = 0 then
                SourceLine.Delete(true)
            else
                SourceLine.Modify(true);

            WriteToLedger(SourceLP, LPActionTransferOut(), SourceLP."Bin Code", TargetLP."Bin Code", TransferQty, SourceLine."Item No.", SourceLine."Lot No.", TargetLP."No.");
            WriteToLedger(TargetLP, LPActionTransferIn(), SourceLP."Bin Code", TargetLP."Bin Code", TransferQty, SourceLine."Item No.", SourceLine."Lot No.", SourceLP."No.");
        end;
        OnAfterTransfer(SourceLP, TargetLP);
    end;

    procedure Unbuild(var LP: Record "DOPSWHS LP Header")
    var
        LPLine: Record "DOPSWHS LP Line";
    begin
        OnBeforeUnbuild(LP);
        if not (LP.Status in [LP.Status::Built, LP.Status::Open]) then
            Error('Yalnız açık veya tamamlanmış LP bozulabilir.');
        LogMutation('LP.Unbuild');
        LPLine.SetRange("LP No.", LP."No.");
        LPLine.DeleteAll(true);
        WriteToLedger(LP, LPActionUnbuilt(), LP."Bin Code", '', 0, '', '', '');
        LP.Status := LP.Status::Unbuilt;
        LP.Modify(true);
        OnAfterUnbuild(LP);
    end;

    procedure SplitForPartialUse(var LP: Record "DOPSWHS LP Header"; Action: Enum "DOPSWHS Partial Use Action"; Qty: Decimal; LineNo: Integer)
    var
        LPLine: Record "DOPSWHS LP Line";
        NewLP: Record "DOPSWHS LP Header";
        Lines: List of [Integer];
        Quantities: Dictionary of [Integer, Decimal];
        ExcessQty: Decimal;
    begin
        OnBeforeSplitForPartialUse(LP, Action, Qty, LineNo);
        LogMutation('LP.PartialUse');
        LPLine.Get(LP."No.", LineNo);
        if (Qty <= 0) or (Qty > LPLine.Quantity) then
            Error('Kısmi kullanım miktarı geçersizdir.');

        case Action of
            Action::CreateNewLP:
                begin
                    ExcessQty := LPLine.Quantity - Qty;
                    if ExcessQty > 0 then begin
                        Build(LP."LP Template Code", LP."Location Code", LP."Bin Code", NewLP);
                        Stop(NewLP, false);
                        Lines.Add(LineNo);
                        Quantities.Add(LineNo, ExcessQty);
                        Transfer(LP, NewLP, Lines, Quantities);
                    end;
                    LPLine.Get(LP."No.", LineNo);
                    LPLine.Validate(Quantity, Qty);
                    LPLine.Modify(true);
                end;
            Action::RemoveExcess:
                begin
                    LPLine.Validate(Quantity, Qty);
                    LPLine.Modify(true);
                end;
            Action::RemoveUsedPortion:
                begin
                    LPLine.Validate(Quantity, LPLine.Quantity - Qty);
                    if LPLine.Quantity = 0 then
                        LPLine.Delete(true)
                    else
                        LPLine.Modify(true);
                end;
            Action::Unbuild:
                Unbuild(LP);
        end;
        OnAfterSplitForPartialUse(LP);
    end;

    procedure WriteToLedger(var LP: Record "DOPSWHS LP Header"; Action: Enum "DOPSWHS LP Action"; FromBin: Code[20]; ToBin: Code[20]; Quantity: Decimal; ItemNo: Code[20]; LotSerial: Code[50]; RelatedDocument: Code[40])
    var
        Ledger: Record "DOPSWHS LP Movement Ledger";
    begin
        Ledger.Init();
        Ledger."LP No." := LP."No.";
        Ledger.Action := Action;
        Ledger."From Bin" := FromBin;
        Ledger."To Bin" := ToBin;
        Ledger.Quantity := Quantity;
        Ledger."Item No." := ItemNo;
        Ledger."Lot Serial" := LotSerial;
        Ledger."User ID" := CopyStr(UserId(), 1, MaxStrLen(Ledger."User ID"));
        Ledger.DateTime := CurrentDateTime();
        Ledger."Related Document" := RelatedDocument;
        Ledger.Insert(true);
    end;

    local procedure EnsureLooseStockAvailable(LocationCode: Code[10]; BinCode: Code[20]; ItemNo: Code[20]; LotNo: Code[50]; SerialNo: Code[50]; RequiredBaseQty: Decimal)
    var
        BinContent: Record "Bin Content";
        WarehouseEntry: Record "Warehouse Entry";
        LPHeader: Record "DOPSWHS LP Header";
        LPLine: Record "DOPSWHS LP Line";
        Item: Record Item;
        ItemUoM: Record "Item Unit of Measure";
        BinQtyBase: Decimal;
        AllocatedQtyBase: Decimal;
        AllocatedTrackedQtyBase: Decimal;
        TrackedQtyBase: Decimal;
        LineQtyBase: Decimal;
    begin
        BinContent.SetRange("Location Code", LocationCode);
        BinContent.SetRange("Bin Code", BinCode);
        BinContent.SetRange("Item No.", ItemNo);
        BinContent.SetRange("Variant Code", '');
        if BinContent.FindSet() then
            repeat
                BinContent.CalcFields("Quantity (Base)");
                BinQtyBase += BinContent."Quantity (Base)";
            until BinContent.Next() = 0;

        if (LotNo <> '') or (SerialNo <> '') then begin
            WarehouseEntry.SetRange("Location Code", LocationCode);
            WarehouseEntry.SetRange("Bin Code", BinCode);
            WarehouseEntry.SetRange("Item No.", ItemNo);
            WarehouseEntry.SetRange("Variant Code", '');
            if LotNo <> '' then
                WarehouseEntry.SetRange("Lot No.", LotNo);
            if SerialNo <> '' then
                WarehouseEntry.SetRange("Serial No.", SerialNo);
            if WarehouseEntry.FindSet() then
                repeat
                    TrackedQtyBase += WarehouseEntry."Qty. (Base)";
                until WarehouseEntry.Next() = 0;
        end;

        Item.Get(ItemNo);
        LPHeader.SetRange("Location Code", LocationCode);
        LPHeader.SetRange("Bin Code", BinCode);
        LPHeader.SetFilter(Status, '%1|%2|%3', LPHeader.Status::Open, LPHeader.Status::Built, LPHeader.Status::Assigned);
        if LPHeader.FindSet() then
            repeat
                LPLine.Reset();
                LPLine.SetRange("LP No.", LPHeader."No.");
                LPLine.SetRange("Item No.", ItemNo);
                LPLine.SetRange("Variant Code", '');
                if LPLine.FindSet() then
                    repeat
                        LineQtyBase := LPLine.Quantity;
                        if (LPLine."Unit of Measure" <> '') and
                           (LPLine."Unit of Measure" <> Item."Base Unit of Measure") and
                           ItemUoM.Get(ItemNo, LPLine."Unit of Measure")
                        then
                            LineQtyBase *= ItemUoM."Qty. per Unit of Measure";
                        AllocatedQtyBase += LineQtyBase;
                        if ((LotNo = '') or (LPLine."Lot No." = LotNo)) and
                           ((SerialNo = '') or (LPLine."Serial No." = SerialNo))
                        then
                            AllocatedTrackedQtyBase += LineQtyBase;
                    until LPLine.Next() = 0;
            until LPHeader.Next() = 0;

        if ((LotNo <> '') or (SerialNo <> '')) and
           ((TrackedQtyBase - AllocatedTrackedQtyBase) < RequiredBaseQty)
        then
            Error(
                'Insufficient unassigned tracked stock for item %1 in bin %2 (lot %3, serial %4). Tracked stock: %5, already assigned: %6, requested: %7.',
                ItemNo, BinCode, LotNo, SerialNo, TrackedQtyBase, AllocatedTrackedQtyBase, RequiredBaseQty);

        if (BinQtyBase - AllocatedQtyBase) < RequiredBaseQty then
            Error(
                'Insufficient unassigned stock for item %1 in bin %2. Bin stock: %3, already assigned to active LPs: %4, requested: %5.',
                ItemNo, BinCode, BinQtyBase, AllocatedQtyBase, RequiredBaseQty);
    end;

    local procedure RequireStatus(var LP: Record "DOPSWHS LP Header"; RequiredStatus: Enum "DOPSWHS LP Status")
    begin
        if LP.Status <> RequiredStatus then
            Error('%1 LP numarasının durumu %2 olmalıdır. Güncel durum: %3.', LP."No.", RequiredStatus, LP.Status);
    end;

    local procedure LogMutation(EventName: Text)
    var
        Telemetry: Codeunit "DOPSWHS Telemetry";
    begin
        Telemetry.LogInfo(EventName, EventName);
    end;

    local procedure LPActionBuilt(): Enum "DOPSWHS LP Action" begin exit(Enum::"DOPSWHS LP Action"::Built); end;
    local procedure LPActionAssigned(): Enum "DOPSWHS LP Action" begin exit(Enum::"DOPSWHS LP Action"::Assigned); end;
    local procedure LPActionReleased(): Enum "DOPSWHS LP Action" begin exit(Enum::"DOPSWHS LP Action"::Released); end;
    local procedure LPActionTransferIn(): Enum "DOPSWHS LP Action" begin exit(Enum::"DOPSWHS LP Action"::TransferIn); end;
    local procedure LPActionTransferOut(): Enum "DOPSWHS LP Action" begin exit(Enum::"DOPSWHS LP Action"::TransferOut); end;
    local procedure LPActionUnbuilt(): Enum "DOPSWHS LP Action" begin exit(Enum::"DOPSWHS LP Action"::Unbuilt); end;
    local procedure LPActionItemAdded(): Enum "DOPSWHS LP Action" begin exit(Enum::"DOPSWHS LP Action"::ItemAdded); end;
    local procedure LPActionItemRemoved(): Enum "DOPSWHS LP Action" begin exit(Enum::"DOPSWHS LP Action"::ItemRemoved); end;

    [IntegrationEvent(false, false)] local procedure OnBeforeBuild(TemplateCode: Code[20]; LocationCode: Code[10]; BinCode: Code[20]; var LP: Record "DOPSWHS LP Header") begin end;
    [IntegrationEvent(false, false)] local procedure OnAfterBuild(var LP: Record "DOPSWHS LP Header") begin end;
    [IntegrationEvent(false, false)] local procedure OnBeforeStop(var LP: Record "DOPSWHS LP Header"; PrintLabel: Boolean) begin end;
    [IntegrationEvent(false, false)] local procedure OnAfterStop(var LP: Record "DOPSWHS LP Header") begin end;
    [IntegrationEvent(false, false)] local procedure OnBeforeReopen(var LP: Record "DOPSWHS LP Header") begin end;
    [IntegrationEvent(false, false)] local procedure OnAfterReopen(var LP: Record "DOPSWHS LP Header") begin end;
    [IntegrationEvent(false, false)] local procedure OnBeforeAddLine(var LP: Record "DOPSWHS LP Header"; ItemNo: Code[20]; UoM: Code[10]; Qty: Decimal) begin end;
    [IntegrationEvent(false, false)] local procedure OnAfterAddLine(var LP: Record "DOPSWHS LP Header"; var LPLine: Record "DOPSWHS LP Line") begin end;
    [IntegrationEvent(false, false)] local procedure OnBeforeRemoveLine(var LPLine: Record "DOPSWHS LP Line") begin end;
    [IntegrationEvent(false, false)] local procedure OnAfterRemoveLine(var LP: Record "DOPSWHS LP Header") begin end;
    [IntegrationEvent(false, false)] local procedure OnBeforeAssign(var LP: Record "DOPSWHS LP Header"; DocType: Enum "DOPSWHS Assigned Doc Type"; DocNo: Code[20]) begin end;
    [IntegrationEvent(false, false)] local procedure OnAfterAssign(var LP: Record "DOPSWHS LP Header") begin end;
    [IntegrationEvent(false, false)] local procedure OnBeforeRelease(var LP: Record "DOPSWHS LP Header") begin end;
    [IntegrationEvent(false, false)] local procedure OnAfterRelease(var LP: Record "DOPSWHS LP Header") begin end;
    [IntegrationEvent(false, false)] local procedure OnBeforeTransfer(var SourceLP: Record "DOPSWHS LP Header"; var TargetLP: Record "DOPSWHS LP Header") begin end;
    [IntegrationEvent(false, false)] local procedure OnAfterTransfer(var SourceLP: Record "DOPSWHS LP Header"; var TargetLP: Record "DOPSWHS LP Header") begin end;
    [IntegrationEvent(false, false)] local procedure OnBeforeUnbuild(var LP: Record "DOPSWHS LP Header") begin end;
    [IntegrationEvent(false, false)] local procedure OnAfterUnbuild(var LP: Record "DOPSWHS LP Header") begin end;
    [IntegrationEvent(false, false)] local procedure OnBeforeSplitForPartialUse(var LP: Record "DOPSWHS LP Header"; Action: Enum "DOPSWHS Partial Use Action"; Qty: Decimal; LineNo: Integer) begin end;
    [IntegrationEvent(false, false)] local procedure OnAfterSplitForPartialUse(var LP: Record "DOPSWHS LP Header") begin end;
}
