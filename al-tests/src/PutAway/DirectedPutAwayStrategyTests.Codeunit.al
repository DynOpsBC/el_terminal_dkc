codeunit 72129 "DOPSWHS PutAway Strategy Tests"
{
    Subtype = Test;

    [Test]
    procedure HigherZoneRankPreferred()
    var
        Item: Record Item;
        BinCode: Code[20];
        Reason: Text;
    begin
        CreateItem(Item, 'ITEM-S4-ZONE', 'CAT-A', 1);
        CreateBin('BLUE', 'LOW', 'LOW-01', 10, 100);
        CreateBin('BLUE', 'HIGH', 'HIGH-01', 100, 100);

        Assert.IsTrue(DirectedPutAway.SuggestBin(Item, 1, 'BLUE', BinCode, Reason), Reason);
        Assert.AreEqual('HIGH-01', BinCode, 'Highest ranked zone must be preferred.');
    end;

    [Test]
    procedure BinRankWithinZonePreferred()
    var
        Item: Record Item;
        BinCode: Code[20];
        Reason: Text;
    begin
        CreateItem(Item, 'ITEM-S4-BIN', 'CAT-A', 1);
        CreateBin('BLUE', 'PUT', 'PUT-LOW', 10, 100);
        CreateBin('BLUE', 'PUT', 'PUT-HIGH', 100, 100);

        Assert.IsTrue(DirectedPutAway.SuggestBin(Item, 1, 'BLUE', BinCode, Reason), Reason);
        Assert.AreEqual('PUT-HIGH', BinCode, 'Highest ranked bin inside the zone must be preferred.');
    end;

    [Test]
    procedure CapacityExclusionSkipsFullBin()
    var
        Item: Record Item;
        BinCode: Code[20];
        Reason: Text;
    begin
        CreateItem(Item, 'ITEM-S4-CAP', 'CAT-A', 10);
        CreateBin('BLUE', 'PUT', 'FULL-01', 100, 10);
        CreateBin('BLUE', 'PUT', 'OPEN-01', 90, 100);
        CreateBinContent('BLUE', 'FULL-01', 'ITEM-S4-CAP', 1);

        Assert.IsTrue(DirectedPutAway.SuggestBin(Item, 1, 'BLUE', BinCode, Reason), Reason);
        Assert.AreEqual('OPEN-01', BinCode, 'A bin at max capacity must be skipped.');
    end;

    [Test]
    procedure ItemMixingSkipsDifferentCategory()
    var
        Item: Record Item;
        BinCode: Code[20];
        Reason: Text;
    begin
        CreateItem(Item, 'ITEM-S4-MIX-A', 'CAT-A', 1);
        CreateItemByNo('ITEM-S4-MIX-B', 'CAT-B', 1);
        CreateBin('BLUE', 'PUT', 'MIXED-01', 100, 100);
        CreateBin('BLUE', 'PUT', 'EMPTY-01', 90, 100);
        CreateBinContent('BLUE', 'MIXED-01', 'ITEM-S4-MIX-B', 1);

        Assert.IsTrue(DirectedPutAway.SuggestBin(Item, 1, 'BLUE', BinCode, Reason), Reason);
        Assert.AreEqual('EMPTY-01', BinCode, 'A bin with a different item category must be skipped.');
    end;

    local procedure CreateItem(var Item: Record Item; ItemNo: Code[20]; CategoryCode: Code[20]; UnitVolume: Decimal)
    begin
        CreateItemByNo(ItemNo, CategoryCode, UnitVolume);
        Item.Get(ItemNo);
    end;

    local procedure CreateItemByNo(ItemNo: Code[20]; CategoryCode: Code[20]; UnitVolume: Decimal)
    var
        Item: Record Item;
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

    local procedure CreateBinContent(LocationCode: Code[10]; BinCode: Code[20]; ItemNo: Code[20]; Qty: Decimal)
    var
        BinContent: Record "Bin Content";
    begin
        BinContent.Init();
        BinContent."Location Code" := LocationCode;
        BinContent."Bin Code" := BinCode;
        BinContent."Item No." := ItemNo;
        BinContent."Unit of Measure Code" := 'PCS';
        BinContent.Quantity := Qty;
        BinContent.Insert(true);
    end;

    var
        Assert: Codeunit Assert;
        DirectedPutAway: Codeunit "DOPSWHS Directed PutAway";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        LibraryInventory: Codeunit "Library - Inventory";
}
