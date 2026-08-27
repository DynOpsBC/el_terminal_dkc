codeunit 72048 "DOPSWHS Prod Mgmt"
{
    Access = Public;

    procedure Consume(var ProdOrderComponent: Record "Prod. Order Component"; ItemNo: Code[20]; Qty: Decimal; LpNo: Code[20]; LotNo: Code[50]; SerialNo: Code[50]; BinCode: Code[20])
    var
        ItemJournalLine: Record "Item Journal Line";
        ItemJnlPostBatch: Codeunit "Item Jnl.-Post Batch";
        License: Codeunit "DOPSWHS License Mgmt";
        ConsumeQty: Decimal;
        ConsumeItemNo: Code[20];
    begin
        License.GuardFeature(Enum::"DOPSWHS License Feature"::Production);
        OnBeforeConsume(ProdOrderComponent, ItemNo, Qty, LpNo, LotNo, SerialNo, BinCode);
        ProdOrderComponent.TestField(Status, ProdOrderComponent.Status::Released);

        ConsumeItemNo := ItemNo;
        if ConsumeItemNo = '' then
            ConsumeItemNo := ProdOrderComponent."Item No.";
        if ConsumeItemNo <> ProdOrderComponent."Item No." then
            Error('Item %1 does not match production component %2.', ConsumeItemNo, ProdOrderComponent."Item No.");

        ConsumeQty := Qty;
        if LpNo <> '' then
            ConsumeQty := ResolveLpQuantity(LpNo, ConsumeItemNo, LotNo, SerialNo);
        if ConsumeQty <= 0 then
            Error('Consumption quantity must be greater than zero.');

        CreateConsumptionLine(ProdOrderComponent, ConsumeItemNo, ConsumeQty, LpNo, LotNo, SerialNo, BinCode, ItemJournalLine);
        LogTelemetry('AdvWMS.Production.Consumed', ProdOrderComponent."Prod. Order No.");
        // Post Batch (23) avoids the "Do you want to post?" Confirm that codeunit 241 raises (API/mobile-safe).
        ItemJnlPostBatch.Run(ItemJournalLine);
        OnAfterConsume(ProdOrderComponent, ItemJournalLine);
    end;

    procedure ConsumeByProdOrder(ProdOrderNo: Code[20]; ComponentLineNo: Integer; ItemNo: Code[20]; Qty: Decimal; LpNo: Code[20]; LotNo: Code[50]; SerialNo: Code[50]; BinCode: Code[20])
    var
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        ProdOrderComponent.SetRange(Status, ProdOrderComponent.Status::Released);
        ProdOrderComponent.SetRange("Prod. Order No.", ProdOrderNo);
        ProdOrderComponent.SetRange("Line No.", ComponentLineNo);
        if ItemNo <> '' then
            ProdOrderComponent.SetRange("Item No.", ItemNo);
        ProdOrderComponent.FindFirst();

        if (LpNo <> '') and (ComponentLineNo = 0) then
            FindComponentForLp(ProdOrderNo, ItemNo, LpNo, ProdOrderComponent);

        Consume(ProdOrderComponent, ItemNo, Qty, LpNo, LotNo, SerialNo, BinCode);
    end;

    procedure CreateProductionPick(ProdOrderNo: Code[20]): Code[20]
    var
        ProductionOrder: Record "Production Order";
        PickHeader: Record "Warehouse Activity Header";
        License: Codeunit "DOPSWHS License Mgmt";
        SortingMethod: Option "None","Item","Document","Shelf or Bin","Due Date","Bin Ranking","Action Type";
        PickNo: Code[20];
        AssignToUserId: Code[50];
    begin
        License.GuardFeature(Enum::"DOPSWHS License Feature"::Production);

        // Aynı üretim emri için açık bir pick varsa ikinci belge üretmeden onu aç.
        PickNo := FindOpenProductionPick(ProdOrderNo);
        if PickNo <> '' then
            exit(PickNo);

        if not ProductionOrder.Get(ProductionOrder.Status::Released, ProdOrderNo) then
            Error('Serbest bırakılmış %1 numaralı üretim emri bulunamadı.', ProdOrderNo);

        AssignToUserId := CopyStr(UserId(), 1, MaxStrLen(AssignToUserId));
        ProductionOrder.SetHideValidationDialog(true);
        ProductionOrder.CreatePick(AssignToUserId, SortingMethod::"Shelf or Bin", false, false, false);

        PickNo := FindOpenProductionPick(ProdOrderNo);
        if PickNo = '' then
            Error('Warehouse pick could not be created for production order %1. Check the location and warehouse pick setup.', ProdOrderNo);

        // Standart fonksiyon bazı sürümlerde atamayı satırda bırakabiliyor;
        // mobilde "Bana atanan" filtresinde görünmesini başlıkta garanti et.
        if PickHeader.Get(PickHeader.Type::Pick, PickNo) then
            if PickHeader."Assigned User ID" <> AssignToUserId then begin
                PickHeader.Validate("Assigned User ID", AssignToUserId);
                PickHeader.Modify(true);
            end;

        exit(PickNo);
    end;

    procedure FinishProductionOrder(ProdOrderNo: Code[20]; UpdateUnitCost: Boolean): Code[20]
    var
        ProductionOrder: Record "Production Order";
        FinishedProductionOrder: Record "Production Order";
        ProdOrderStatusManagement: Codeunit "Prod. Order Status Management";
        License: Codeunit "DOPSWHS License Mgmt";
    begin
        License.GuardFeature(Enum::"DOPSWHS License Feature"::Production);

        if not ProductionOrder.Get(ProductionOrder.Status::Released, ProdOrderNo) then begin
            // Mobil istemci aynı isteği bağlantı kesintisinden sonra yeniden
            // gönderebilir. Emir zaten bitmişse işlem idempotent kabul edilir.
            if FinishedProductionOrder.Get(FinishedProductionOrder.Status::Finished, ProdOrderNo) then
                exit(ProdOrderNo);
            Error('Released production order %1 was not found.', ProdOrderNo);
        end;

        OnBeforeFinishProductionOrder(ProductionOrder, UpdateUnitCost);
        ProdOrderStatusManagement.ChangeProdOrderStatus(
            ProductionOrder,
            Enum::"Production Order Status"::Finished,
            WorkDate(),
            UpdateUnitCost);

        if not FinishedProductionOrder.Get(FinishedProductionOrder.Status::Finished, ProdOrderNo) then
            Error('%1 numaralı üretim emri bitirilemedi.', ProdOrderNo);

        LogTelemetry('AdvWMS.Production.Finished', ProdOrderNo);
        OnAfterFinishProductionOrder(FinishedProductionOrder);
        exit(ProdOrderNo);
    end;

    local procedure FindOpenProductionPick(ProdOrderNo: Code[20]): Code[20]
    var
        WhseActivityLine: Record "Warehouse Activity Line";
    begin
        WhseActivityLine.SetRange("Activity Type", WhseActivityLine."Activity Type"::Pick);
        WhseActivityLine.SetRange("Source No.", ProdOrderNo);
        if WhseActivityLine.FindFirst() then
            exit(WhseActivityLine."No.");
        exit('');
    end;

    procedure ReportOutput(var ProdOrderRoutingLine: Record "Prod. Order Routing Line"; OutputQty: Decimal; ScrapQty: Decimal; Runtime: Decimal; NewLpTemplate: Code[20]; BinCode: Code[20]): Code[20]
    var
        License: Codeunit "DOPSWHS License Mgmt";
    begin
        License.GuardFeature(Enum::"DOPSWHS License Feature"::Production);
        exit(ReportOutputInternal(ProdOrderRoutingLine, OutputQty, ScrapQty, Runtime, NewLpTemplate, BinCode));
    end;

    local procedure ReportOutputInternal(var ProdOrderRoutingLine: Record "Prod. Order Routing Line"; OutputQty: Decimal; ScrapQty: Decimal; Runtime: Decimal; NewLpTemplate: Code[20]; BinCode: Code[20]): Code[20]
    var
        ItemJournalLine: Record "Item Journal Line";
        ItemJnlPostBatch: Codeunit "Item Jnl.-Post Batch";
        NewLpNo: Code[20];
    begin
        OnBeforeOutput(ProdOrderRoutingLine, OutputQty, ScrapQty, Runtime, NewLpTemplate, BinCode);
        ProdOrderRoutingLine.TestField(Status, ProdOrderRoutingLine.Status::Released);
        if (OutputQty <= 0) and (ScrapQty <= 0) then
            Error('Output or scrap quantity must be greater than zero.');

        CreateOutputLine(ProdOrderRoutingLine, OutputQty, ScrapQty, Runtime, BinCode, ItemJournalLine);
        LogTelemetry('AdvWMS.Production.Output', ProdOrderRoutingLine."Prod. Order No.");
        ItemJnlPostBatch.Run(ItemJournalLine);

        if NewLpTemplate <> '' then
            NewLpNo := CreateOutputLp(ProdOrderRoutingLine, OutputQty, NewLpTemplate, BinCode);

        OnAfterOutput(ProdOrderRoutingLine, ItemJournalLine, NewLpNo);
        exit(NewLpNo);
    end;

    procedure ReportOutputByProdOrder(ProdOrderNo: Code[20]; RoutingLineNo: Integer; OutputQty: Decimal; ScrapQty: Decimal; Runtime: Decimal; NewLpTemplate: Code[20]; BinCode: Code[20]): Code[20]
    var
        ProdOrderRoutingLine: Record "Prod. Order Routing Line";
    begin
        ProdOrderRoutingLine.SetRange(Status, ProdOrderRoutingLine.Status::Released);
        ProdOrderRoutingLine.SetRange("Prod. Order No.", ProdOrderNo);
        ProdOrderRoutingLine.SetRange("Routing Reference No.", RoutingLineNo);
        if not ProdOrderRoutingLine.FindFirst() then begin
            ProdOrderRoutingLine.SetRange("Routing Reference No.");
            // TODO Sprint H+ post-deploy: restore alternate routing line lookup if target symbols expose a line number.
            ProdOrderRoutingLine.FindFirst();
        end;
        exit(ReportOutputInternal(ProdOrderRoutingLine, OutputQty, ScrapQty, Runtime, NewLpTemplate, BinCode));
    end;

    procedure FindComponentForLp(ProdOrderNo: Code[20]; ItemNo: Code[20]; LpNo: Code[20]; var ProdOrderComponent: Record "Prod. Order Component")
    var
        LPLine: Record "DOPSWHS LP Line";
        MatchedItemNo: Code[20];
        MatchCount: Integer;
    begin
        MatchedItemNo := ItemNo;
        if MatchedItemNo = '' then begin
            LPLine.SetRange("LP No.", LpNo);
            LPLine.FindFirst();
            MatchedItemNo := LPLine."Item No.";
        end;

        ProdOrderComponent.Reset();
        ProdOrderComponent.SetRange(Status, ProdOrderComponent.Status::Released);
        ProdOrderComponent.SetRange("Prod. Order No.", ProdOrderNo);
        ProdOrderComponent.SetRange("Item No.", MatchedItemNo);
        if ProdOrderComponent.FindSet() then
            repeat
                MatchCount += 1;
            until ProdOrderComponent.Next() = 0;

        if MatchCount = 0 then
            Error('No production component matches item %1 for order %2.', MatchedItemNo, ProdOrderNo);
        if MatchCount > 1 then
            Error('Multiple production components match item %1 for order %2. Select a component line.', MatchedItemNo, ProdOrderNo);

        ProdOrderComponent.FindFirst();
    end;

    local procedure CreateConsumptionLine(var ProdOrderComponent: Record "Prod. Order Component"; ItemNo: Code[20]; Qty: Decimal; LpNo: Code[20]; LotNo: Code[50]; SerialNo: Code[50]; BinCode: Code[20]; var ItemJournalLine: Record "Item Journal Line")
    var
        TemplateName: Code[10];
        BatchName: Code[10];
    begin
        EnsureItemJournalBatch(TemplateName, BatchName);
        InitItemJournalLine(TemplateName, BatchName, ItemJournalLine);
        // Order context BEFORE Item No.: validating Item No. first clears the order link, leaving the
        // posting to reject the line with "Order Type must be Production".
        ItemJournalLine.Validate("Entry Type", ItemJournalLine."Entry Type"::Consumption);
        ItemJournalLine.Validate("Order Type", ItemJournalLine."Order Type"::Production);
        ItemJournalLine.Validate("Order No.", ProdOrderComponent."Prod. Order No.");
        ItemJournalLine.Validate("Order Line No.", ProdOrderComponent."Prod. Order Line No.");
        ItemJournalLine.Validate("Item No.", ItemNo);
        ItemJournalLine.Validate("Prod. Order Comp. Line No.", ProdOrderComponent."Line No.");
        ItemJournalLine.Validate("Location Code", ProdOrderComponent."Location Code");
        if BinCode <> '' then
            ItemJournalLine.Validate("Bin Code", BinCode)
        else
            if ProdOrderComponent."Bin Code" <> '' then
                ItemJournalLine.Validate("Bin Code", ProdOrderComponent."Bin Code");
        ItemJournalLine.Validate(Quantity, Qty);
        ItemJournalLine."Package No." := LpNo;
        ItemJournalLine."Lot No." := LotNo;
        ItemJournalLine."Serial No." := SerialNo;
        ItemJournalLine.Insert(true);
    end;

    local procedure CreateOutputLine(var ProdOrderRoutingLine: Record "Prod. Order Routing Line"; OutputQty: Decimal; ScrapQty: Decimal; Runtime: Decimal; BinCode: Code[20]; var ItemJournalLine: Record "Item Journal Line")
    var
        ProdOrderLine: Record "Prod. Order Line";
        TemplateName: Code[10];
        BatchName: Code[10];
    begin
        ProdOrderLine.Get(ProdOrderRoutingLine.Status, ProdOrderRoutingLine."Prod. Order No.", ProdOrderRoutingLine."Routing Reference No.");
        EnsureItemJournalBatch(TemplateName, BatchName);
        InitItemJournalLine(TemplateName, BatchName, ItemJournalLine);
        ItemJournalLine.Validate("Entry Type", ItemJournalLine."Entry Type"::Output);
        ItemJournalLine.Validate("Order Type", ItemJournalLine."Order Type"::Production);
        ItemJournalLine.Validate("Order No.", ProdOrderRoutingLine."Prod. Order No.");
        ItemJournalLine.Validate("Order Line No.", ProdOrderRoutingLine."Routing Reference No.");
        ItemJournalLine.Validate("Item No.", ProdOrderLine."Item No.");
        ItemJournalLine.Validate("Routing No.", ProdOrderRoutingLine."Routing No.");
        ItemJournalLine.Validate("Operation No.", ProdOrderRoutingLine."Operation No.");
        ItemJournalLine.Validate("Location Code", ProdOrderLine."Location Code");
        if BinCode <> '' then
            ItemJournalLine.Validate("Bin Code", BinCode)
        else
            if ProdOrderLine."Bin Code" <> '' then
                ItemJournalLine.Validate("Bin Code", ProdOrderLine."Bin Code");
        ItemJournalLine.Validate("Output Quantity", OutputQty);
        ItemJournalLine.Validate("Scrap Quantity", ScrapQty);
        ItemJournalLine.Validate("Run Time", Runtime);
        ItemJournalLine.Insert(true);
    end;

    local procedure CreateOutputLp(var ProdOrderRoutingLine: Record "Prod. Order Routing Line"; OutputQty: Decimal; NewLpTemplate: Code[20]; BinCode: Code[20]): Code[20]
    var
        ProdOrderLine: Record "Prod. Order Line";
        Setup: Record "DOPSWHS Setup";
        LP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
        LocationCode: Code[10];
        EffectiveBinCode: Code[20];
    begin
        ProdOrderLine.Get(ProdOrderRoutingLine.Status, ProdOrderRoutingLine."Prod. Order No.", ProdOrderRoutingLine."Routing Reference No.");
        LocationCode := ProdOrderLine."Location Code";
        EffectiveBinCode := BinCode;
        if EffectiveBinCode = '' then
            EffectiveBinCode := ProdOrderLine."Bin Code";
        if LocationCode = '' then
            if Setup.Get('') then
                LocationCode := Setup."Default Location Code";

        LPMgt.Build(NewLpTemplate, LocationCode, EffectiveBinCode, LP);
        LPMgt.AddLine(LP, ProdOrderLine."Item No.", ProdOrderLine."Unit of Measure Code", OutputQty, '', '', 0D);
        LPMgt.Stop(LP, false);
        exit(LP."No.");
    end;

    local procedure ResolveLpQuantity(LpNo: Code[20]; ItemNo: Code[20]; var LotNo: Code[50]; var SerialNo: Code[50]): Decimal
    var
        LPLine: Record "DOPSWHS LP Line";
        Qty: Decimal;
    begin
        LPLine.SetRange("LP No.", LpNo);
        LPLine.SetRange("Item No.", ItemNo);
        if LPLine.FindSet() then
            repeat
                Qty += LPLine.Quantity;
                if LotNo = '' then
                    LotNo := LPLine."Lot No.";
                if SerialNo = '' then
                    SerialNo := LPLine."Serial No.";
            until LPLine.Next() = 0;
        if Qty = 0 then
            Error('LP %1 does not contain item %2.', LpNo, ItemNo);
        exit(Qty);
    end;

    local procedure EnsureItemJournalBatch(var TemplateName: Code[10]; var BatchName: Code[10])
    var
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
    begin
        ItemJournalTemplate.SetRange(Type, ItemJournalTemplate.Type::Item);
        if not ItemJournalTemplate.FindFirst() then begin
            ItemJournalTemplate.Init();
            ItemJournalTemplate.Name := 'ITEM';
            ItemJournalTemplate.Type := ItemJournalTemplate.Type::Item;
            ItemJournalTemplate.Description := 'Item Journal';
            ItemJournalTemplate.Insert(true);
        end;

        TemplateName := ItemJournalTemplate.Name;
        BatchName := 'DOPSPROD';
        if not ItemJournalBatch.Get(TemplateName, BatchName) then begin
            ItemJournalBatch.Init();
            ItemJournalBatch."Journal Template Name" := TemplateName;
            ItemJournalBatch.Name := BatchName;
            ItemJournalBatch.Description := 'DOPSWHS production';
            ItemJournalBatch.Insert(true);
        end;
    end;

    local procedure InitItemJournalLine(TemplateName: Code[10]; BatchName: Code[10]; var ItemJournalLine: Record "Item Journal Line")
    var
        ExistingLine: Record "Item Journal Line";
        NextLineNo: Integer;
    begin
        ExistingLine.SetRange("Journal Template Name", TemplateName);
        ExistingLine.SetRange("Journal Batch Name", BatchName);
        if ExistingLine.FindLast() then
            NextLineNo := ExistingLine."Line No." + 10000
        else
            NextLineNo := 10000;

        ItemJournalLine.Init();
        ItemJournalLine."Journal Template Name" := TemplateName;
        ItemJournalLine."Journal Batch Name" := BatchName;
        ItemJournalLine."Line No." := NextLineNo;
        ItemJournalLine."Posting Date" := WorkDate();
        ItemJournalLine."Document No." := CopyStr('DOPS-PROD-' + Format(Today(), 0, '<Year4><Month,2><Day,2>'), 1, MaxStrLen(ItemJournalLine."Document No."));
    end;

    local procedure LogTelemetry(EventName: Text; DocumentNo: Code[20])
    var
        Telemetry: Codeunit "DOPSWHS Telemetry";
    begin
        Telemetry.LogInfo(EventName, DocumentNo);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeConsume(var ProdOrderComponent: Record "Prod. Order Component"; ItemNo: Code[20]; Qty: Decimal; LpNo: Code[20]; LotNo: Code[50]; SerialNo: Code[50]; BinCode: Code[20])
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterConsume(var ProdOrderComponent: Record "Prod. Order Component"; var ItemJournalLine: Record "Item Journal Line")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeOutput(var ProdOrderRoutingLine: Record "Prod. Order Routing Line"; OutputQty: Decimal; ScrapQty: Decimal; Runtime: Decimal; NewLpTemplate: Code[20]; BinCode: Code[20])
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterOutput(var ProdOrderRoutingLine: Record "Prod. Order Routing Line"; var ItemJournalLine: Record "Item Journal Line"; NewLpNo: Code[20])
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeFinishProductionOrder(var ProductionOrder: Record "Production Order"; var UpdateUnitCost: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterFinishProductionOrder(var ProductionOrder: Record "Production Order")
    begin
    end;
}
