codeunit 72107 "DOPSWHS E2E Receive Tests"
{
    Subtype = Test;

    [Test]
    procedure PurchaseOrderToMobileReceiptToPostedIleChain()
    var
        TestHelper: Codeunit "DOPSWHS Test Helper";
        WhseReceiptHeader: Record "Warehouse Receipt Header";
        WhseReceiptLine: Record "Warehouse Receipt Line";
        PostedWhseReceiptLine: Record "Posted Whse. Receipt Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        WarehouseEntry: Record "Warehouse Entry";
        ReceiptMgmt: Codeunit "DOPSWHS Receipt Mgmt";
        LpNo: Code[20];
    begin
        TestHelper.EnsureSetup();
        CreateReceipt(WhseReceiptHeader, WhseReceiptLine, 'PO-S3-E2E', 5);

        ReceiptMgmt.AssignUser(WhseReceiptHeader, CopyStr(UserId(), 1, 50));
        LpNo := ReceiptMgmt.StartLP(WhseReceiptHeader, 'PALLET-EUR');
        ReceiptMgmt.ConfirmLine(WhseReceiptLine, 5, 'LOT-S3', '', CalcDate('<+30D>', WorkDate()), LpNo, 'RECEIVE');
        ReceiptMgmt.StopLP(WhseReceiptHeader, LpNo, true);
        ReceiptMgmt.PostReceipt(WhseReceiptHeader, false, false);

        PostedWhseReceiptLine.SetRange("Whse. Receipt No.", WhseReceiptHeader."No.");
        Assert.IsFalse(PostedWhseReceiptLine.IsEmpty(), 'Posted warehouse receipt line must exist.');
        ItemLedgerEntry.SetRange("Document No.", WhseReceiptHeader."No.");
        Assert.IsFalse(ItemLedgerEntry.IsEmpty(), 'Item ledger entry must exist.');
        WarehouseEntry.SetRange("Reference No.", WhseReceiptHeader."No.");
        Assert.IsFalse(WarehouseEntry.IsEmpty(), 'Warehouse entry must exist.');
    end;

    local procedure CreateReceipt(var Header: Record "Warehouse Receipt Header"; var Line: Record "Warehouse Receipt Line"; SourceNo: Code[20]; Qty: Decimal)
    begin
        Header.Init();
        Header."No." := SourceNo + '-RCPT';
        Header."Location Code" := 'BLUE';
        Header.Insert(true);

        Line.Init();
        Line."No." := Header."No.";
        Line."Line No." := 10000;
        Line."Source No." := SourceNo;
        Line."Item No." := 'ITEM-S3';
        Line.Description := 'Sprint 3 end-to-end receipt item';
        Line."Unit of Measure Code" := 'PCS';
        Line.Quantity := Qty;
        Line."Qty. to Receive" := Qty;
        Line."Bin Code" := 'RECEIVE';
        Line.Insert(true);
    end;

    var
        Assert: Codeunit Assert;
}
