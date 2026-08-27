codeunit 72255 "DOPSWHS Quality Mgmt"
{
    // Quality inspection orders, managed from the mobile app. A quality order gates goods (typically
    // received or produced) until an inspector passes/fails them; failing routes to a quarantine bin.
    Access = Public;

    /// <summary>Creates an open quality order and returns its No.</summary>
    procedure CreateOrder(SourceTypeOpt: Integer; SourceNo: Code[20]; ItemNo: Code[20]; Qty: Decimal; LocationCode: Code[10]; BinCode: Code[20]; LpNo: Code[20]): Code[20]
    var
        QualityOrder: Record "DOPSWHS Quality Order";
        Item: Record Item;
    begin
        QualityOrder.Init();
        QualityOrder."No." := NextNo();
        QualityOrder."Source Type" := SourceTypeOpt;
        QualityOrder."Source No." := SourceNo;
        QualityOrder."Item No." := ItemNo;
        if Item.Get(ItemNo) then
            QualityOrder."Item Description" := CopyStr(Item.Description, 1, MaxStrLen(QualityOrder."Item Description"));
        QualityOrder."Quantity" := Qty;
        QualityOrder."Sample Size" := SampleSizeFor(Qty);
        QualityOrder."Location Code" := LocationCode;
        QualityOrder."Bin Code" := BinCode;
        QualityOrder."LP No." := LpNo;
        QualityOrder."Status" := QualityOrder."Status"::Open;
        QualityOrder."Created DateTime" := CurrentDateTime();
        QualityOrder."Due Date" := Today();
        QualityOrder.Insert(true);
        exit(QualityOrder."No.");
    end;

    /// <summary>Records a PASS result; goods are released for normal handling.</summary>
    procedure Pass(var QualityOrder: Record "DOPSWHS Quality Order"; Inspector: Code[50]; Notes: Text[250])
    begin
        QualityOrder.TestField(Status, QualityOrder.Status::Open);
        QualityOrder."Status" := QualityOrder."Status"::Passed;
        QualityOrder."Inspector" := Inspector;
        QualityOrder."Inspected DateTime" := CurrentDateTime();
        QualityOrder."Result Notes" := Notes;
        QualityOrder.Modify(true);
        LogTelemetry('AdvWMS.Quality.Passed', QualityOrder."No.");
    end;

    /// <summary>Records a FAIL result with a reason; goods are routed to the quarantine bin.</summary>
    procedure Fail(var QualityOrder: Record "DOPSWHS Quality Order"; Inspector: Code[50]; ReasonCode: Code[20]; Notes: Text[250]; QuarantineBin: Code[20])
    begin
        QualityOrder.TestField(Status, QualityOrder.Status::Open);
        QualityOrder."Status" := QualityOrder."Status"::Failed;
        QualityOrder."Inspector" := Inspector;
        QualityOrder."Inspected DateTime" := CurrentDateTime();
        QualityOrder."Reject Reason" := ReasonCode;
        QualityOrder."Result Notes" := Notes;
        QualityOrder."Quarantine Bin" := QuarantineBin;
        QualityOrder.Modify(true);
        LogTelemetry('AdvWMS.Quality.Failed', QualityOrder."No.");
    end;

    /// <summary>Seeds a couple of demo quality orders so the mobile screen is testable out of the box.</summary>
    procedure SeedDemoOrders()
    var
        QualityOrder: Record "DOPSWHS Quality Order";
        Item: Record Item;
        Setup: Record "DOPSWHS Setup";
        LocationCode: Code[10];
    begin
        if not QualityOrder.IsEmpty() then
            exit;
        if Setup.Get('') then
            LocationCode := Setup."Default Location Code";
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetRange(Blocked, false);
        if Item.FindSet() then
            repeat
                CreateOrder(1, 'DEMO', Item."No.", 10, LocationCode, '', '');  // 1 = Source Type::Receipt
            until (Item.Next() = 0) or (QualityOrder.Count() >= 3);
    end;

    local procedure NextNo(): Code[20]
    var
        QualityOrder: Record "DOPSWHS Quality Order";
        Base: Text;
        Candidate: Code[20];
        Suffix: Integer;
    begin
        // Timestamp-based number (no No. Series dependency); add a suffix so multiple orders created in
        // the same second don't collide.
        Base := 'QO-' + Format(CurrentDateTime(), 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>');
        Candidate := CopyStr(Base, 1, 20);
        while QualityOrder.Get(Candidate) do begin
            Suffix += 1;
            Candidate := CopyStr(Base + '-' + Format(Suffix), 1, 20);
        end;
        exit(Candidate);
    end;

    local procedure SampleSizeFor(Qty: Decimal) Sample: Decimal
    begin
        // Simple ANSI-style sampling: ~10% of the lot, min 1, capped at 20.
        if Qty <= 0 then
            exit(0);
        Sample := Round(Qty * 0.1, 1, '>');
        if Sample < 1 then Sample := 1;
        if Sample > 20 then Sample := 20;
    end;

    local procedure LogTelemetry(EventId: Text; QoNo: Code[20])
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Dimensions.Add('qualityOrderNo', QoNo);
        Session.LogMessage(EventId, StrSubstNo('Quality order %1', QoNo), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dimensions);
    end;
}
