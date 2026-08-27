codeunit 72118 "DOPSWHS Directed Move Tests"
{
    Subtype = Test;

    [Test]
    procedure RegisterDirectedMovementCreatesWarehouseEntries()
    var
        TestHelper: Codeunit "DOPSWHS Test Helper";
        WhseActivityHeader: Record "Warehouse Activity Header";
        WarehouseEntry: Record "Warehouse Entry";
        MovementMgmt: Codeunit "DOPSWHS Movement Mgmt";
    begin
        TestHelper.EnsureSetup();
        WhseActivityHeader.Init();
        WhseActivityHeader.Type := WhseActivityHeader.Type::Movement;
        WhseActivityHeader."No." := 'MV-S4-001';
        WhseActivityHeader."Location Code" := 'BLUE';
        WhseActivityHeader.Insert(true);

        MovementMgmt.RegisterDirected(WhseActivityHeader);

        WarehouseEntry.SetRange("Reference No.", WhseActivityHeader."No.");
        Assert.IsFalse(WarehouseEntry.IsEmpty(), 'Registering a directed movement must create warehouse entries.');
    end;

    [Test]
    procedure ConfirmLineUpdatesOnlyMatchingTrackedPair()
    var
        WhseActivityHeader: Record "Warehouse Activity Header";
        TakeLine: Record "Warehouse Activity Line";
        CheckLine: Record "Warehouse Activity Line";
        MovementMgmt: Codeunit "DOPSWHS Movement Mgmt";
    begin
        WhseActivityHeader.Init();
        WhseActivityHeader.Type := WhseActivityHeader.Type::Movement;
        WhseActivityHeader."No." := 'MV-PAIR-01';
        WhseActivityHeader."Assigned User ID" := 'USER1';
        WhseActivityHeader.Insert(true);

        InsertMovementLine('MV-PAIR-01', 10000, TakeLine."Action Type"::Take, 'LOT-A', 10);
        InsertMovementLine('MV-PAIR-01', 20000, TakeLine."Action Type"::Place, 'LOT-A', 10);
        InsertMovementLine('MV-PAIR-01', 30000, TakeLine."Action Type"::Take, 'LOT-B', 10);
        InsertMovementLine('MV-PAIR-01', 40000, TakeLine."Action Type"::Place, 'LOT-B', 10);

        TakeLine.Get(TakeLine."Activity Type"::Movement, 'MV-PAIR-01', 10000);
        MovementMgmt.ConfirmDirectedLineFor(TakeLine, 4, 'LOT-A', '', 'USER1');

        CheckLine.Get(CheckLine."Activity Type"::Movement, 'MV-PAIR-01', 20000);
        Assert.AreEqual(4, CheckLine."Qty. to Handle", 'The matching Place line must receive the confirmed quantity.');
        CheckLine.Get(CheckLine."Activity Type"::Movement, 'MV-PAIR-01', 30000);
        Assert.AreEqual(0, CheckLine."Qty. to Handle", 'A different tracked Take line must remain unchanged.');
        CheckLine.Get(CheckLine."Activity Type"::Movement, 'MV-PAIR-01', 40000);
        Assert.AreEqual(0, CheckLine."Qty. to Handle", 'A different tracked Place line must remain unchanged.');
    end;

    [Test]
    procedure ConfirmLineWritesSelectedTrackingToBothLines()
    var
        WhseActivityHeader: Record "Warehouse Activity Header";
        TakeLine: Record "Warehouse Activity Line";
        CheckLine: Record "Warehouse Activity Line";
        MovementMgmt: Codeunit "DOPSWHS Movement Mgmt";
    begin
        WhseActivityHeader.Init();
        WhseActivityHeader.Type := WhseActivityHeader.Type::Movement;
        WhseActivityHeader."No." := 'MV-LOT-01';
        WhseActivityHeader."Assigned User ID" := 'USER1';
        WhseActivityHeader.Insert(true);

        InsertMovementLine('MV-LOT-01', 10000, TakeLine."Action Type"::Take, '', 10);
        InsertMovementLine('MV-LOT-01', 20000, TakeLine."Action Type"::Place, '', 10);

        TakeLine.Get(TakeLine."Activity Type"::Movement, 'MV-LOT-01', 10000);
        MovementMgmt.ConfirmDirectedLineFor(TakeLine, 4, 'LOT-NEW', 'SERIAL-NEW', 'USER1');

        CheckLine.Get(CheckLine."Activity Type"::Movement, 'MV-LOT-01', 10000);
        Assert.AreEqual('LOT-NEW', CheckLine."Lot No.", 'The Take line must receive the selected lot.');
        Assert.AreEqual('SERIAL-NEW', CheckLine."Serial No.", 'The Take line must receive the selected serial number.');
        Assert.AreEqual(4, CheckLine."Qty. to Handle", 'The Take line must receive the confirmed quantity.');
        CheckLine.Get(CheckLine."Activity Type"::Movement, 'MV-LOT-01', 20000);
        Assert.AreEqual('LOT-NEW', CheckLine."Lot No.", 'The Place line must receive the selected lot.');
        Assert.AreEqual('SERIAL-NEW', CheckLine."Serial No.", 'The Place line must receive the selected serial number.');
        Assert.AreEqual(4, CheckLine."Qty. to Handle", 'The Place line must receive the confirmed quantity.');
    end;

    local procedure InsertMovementLine(DocumentNo: Code[20]; LineNo: Integer; ActionType: Enum "Warehouse Action Type"; LotNo: Code[50]; Quantity: Decimal)
    var
        WhseActivityLine: Record "Warehouse Activity Line";
    begin
        WhseActivityLine.Init();
        WhseActivityLine."Activity Type" := WhseActivityLine."Activity Type"::Movement;
        WhseActivityLine."No." := DocumentNo;
        WhseActivityLine."Line No." := LineNo;
        WhseActivityLine."Action Type" := ActionType;
        WhseActivityLine."Item No." := 'ITEM-MOVE';
        WhseActivityLine."Unit of Measure Code" := 'PCS';
        WhseActivityLine.Quantity := Quantity;
        WhseActivityLine."Qty. Outstanding" := Quantity;
        WhseActivityLine."Lot No." := LotNo;
        WhseActivityLine.Insert(true);
    end;

    var
        Assert: Codeunit Assert;
        LibraryWarehouse: Codeunit "Library - Warehouse";
        LibraryInventory: Codeunit "Library - Inventory";
}
