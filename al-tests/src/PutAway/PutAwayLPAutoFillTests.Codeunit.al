codeunit 72130 "DOPSWHS PutAway LP Auto Tests"
{
    Subtype = Test;

    [Test]
    procedure ScanLpOnFirstLineFillsMatchingActivityLines()
    var
        TestHelper: Codeunit "DOPSWHS Test Helper";
        LP: Record "DOPSWHS LP Header";
        FirstLine: Record "Warehouse Activity Line";
        SecondLine: Record "Warehouse Activity Line";
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        TestHelper.EnsureSetup();
        LPMgt.Build('PALLET-EUR', 'BLUE', 'RECEIVE', LP);
        CreateLpLine(LP."No.", 'ITEM-S4-LP-A', 10);
        CreateLpLine(LP."No.", 'ITEM-S4-LP-B', 20);

        CreateActivityLine(FirstLine, 10000, 'ITEM-S4-LP-A');
        CreateActivityLine(SecondLine, 20000, 'ITEM-S4-LP-B');

        FirstLine.Validate("LP No.", LP."No.");
        FirstLine.Modify(true);

        SecondLine.Get(SecondLine."Activity Type", SecondLine."No.", SecondLine."Line No.");
        Assert.AreEqual(LP."No.", SecondLine."LP No.", 'Scanning an LP on one line must fill all activity lines for items on that LP.');
    end;

    local procedure CreateLpLine(LpNo: Code[20]; ItemNo: Code[20]; Qty: Decimal)
    var
        LPLine: Record "DOPSWHS LP Line";
    begin
        LPLine.Init();
        LPLine."LP No." := LpNo;
        LPLine.Validate("Item No.", ItemNo);
        LPLine."Unit of Measure" := 'PCS';
        LPLine.Validate(Quantity, Qty);
        LPLine.Insert(true);
    end;

    local procedure CreateActivityLine(var Line: Record "Warehouse Activity Line"; LineNo: Integer; ItemNo: Code[20])
    begin
        Line.Init();
        Line."Activity Type" := Line."Activity Type"::"Put-away";
        Line."No." := 'PA-S4-LP';
        Line."Line No." := LineNo;
        Line."Location Code" := 'BLUE';
        Line."Item No." := ItemNo;
        Line."Qty. to Handle" := 1;
        Line.Insert(true);
    end;

    var
        Assert: Codeunit Assert;
        LibraryWarehouse: Codeunit "Library - Warehouse";
        LibraryInventory: Codeunit "Library - Inventory";
}
