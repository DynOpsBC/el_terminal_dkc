codeunit 72131 "DOPSWHS PutAway Register Tests"
{
    Subtype = Test;

    [Test]
    procedure RegisterPutAwayCreatesWarehouseEntries()
    var
        TestHelper: Codeunit "DOPSWHS Test Helper";
        WhseActivityHeader: Record "Warehouse Activity Header";
        WarehouseEntry: Record "Warehouse Entry";
        MovementMgmt: Codeunit "DOPSWHS Movement Mgmt";
    begin
        TestHelper.EnsureSetup();
        CreateActivityHeader(WhseActivityHeader, WhseActivityHeader.Type::"Put-away", 'PA-S4-001', 'BLUE');

        MovementMgmt.RegisterDirected(WhseActivityHeader);

        WarehouseEntry.SetRange("Reference No.", WhseActivityHeader."No.");
        Assert.IsFalse(WarehouseEntry.IsEmpty(), 'Registering a put-away must create warehouse entries.');
    end;

    [Test]
    procedure SuggestBinReturnsBinCode()
    var
        TestHelper: Codeunit "DOPSWHS Test Helper";
        Item: Record Item;
        DirectedPutAway: Codeunit "DOPSWHS Directed PutAway";
        BinCode: Code[20];
        Reason: Text;
    begin
        TestHelper.EnsureSetup();
        CreateItem(Item, 'ITEM-S4-SUG', 'CAT-A', 1);
        CreateBin('BLUE', 'PUT', 'A-01', 100, 100);

        Assert.IsTrue(DirectedPutAway.SuggestBin(Item, 5, 'BLUE', BinCode, Reason), Reason);
        Assert.AreEqual('A-01', BinCode, 'Suggested bin must be returned.');
    end;

    local procedure CreateActivityHeader(var Header: Record "Warehouse Activity Header"; ActivityType: Enum "Warehouse Activity Type"; No: Code[20]; LocationCode: Code[10])
    begin
        Header.Init();
        Header.Type := ActivityType;
        Header."No." := No;
        Header."Location Code" := LocationCode;
        Header."Assigned User ID" := CopyStr(UserId(), 1, MaxStrLen(Header."Assigned User ID"));
        Header.Insert(true);
    end;

    local procedure CreateItem(var Item: Record Item; ItemNo: Code[20]; CategoryCode: Code[20]; UnitVolume: Decimal)
    begin
        if Item.Get(ItemNo) then
            Item.Delete(true);
        Item.Init();
        Item."No." := ItemNo;
        Item.Description := ItemNo;
        Item."Base Unit of Measure" := 'PCS';
        Item."Item Category Code" := CategoryCode;
        Item."Unit Volume" := UnitVolume;
        Item.Insert(true);
    end;

    local procedure CreateBin(LocationCode: Code[10]; ZoneCode: Code[10]; BinCode: Code[20]; BinRanking: Integer; MaximumCubage: Decimal)
    var
        Location: Record Location;
        Zone: Record Zone;
        Bin: Record Bin;
    begin
        if not Location.Get(LocationCode) then begin
            Location.Init();
            Location.Code := LocationCode;
            Location.Insert(true);
        end;
        if not Zone.Get(LocationCode, ZoneCode) then begin
            Zone.Init();
            Zone."Location Code" := LocationCode;
            Zone.Code := ZoneCode;
            Zone."Zone Ranking" := BinRanking;
            Zone.Insert(true);
        end;
        if Bin.Get(LocationCode, BinCode) then
            Bin.Delete(true);
        Bin.Init();
        Bin."Location Code" := LocationCode;
        Bin.Code := BinCode;
        Bin."Zone Code" := ZoneCode;
        Bin."Bin Ranking" := BinRanking;
        Bin."Maximum Cubage" := MaximumCubage;
        Bin.Insert(true);
    end;

    var
        Assert: Codeunit Assert;
        LibraryWarehouse: Codeunit "Library - Warehouse";
        LibraryInventory: Codeunit "Library - Inventory";
}
