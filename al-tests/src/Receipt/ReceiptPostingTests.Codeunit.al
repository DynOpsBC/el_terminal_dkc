codeunit 72132 "DOPSWHS Receipt Posting Tests"
{
    Subtype = Test;

    [Test]
    procedure POWhseReceiptPartialPostCreatesPostedChain()
    var
        TestHelper: Codeunit "DOPSWHS Test Helper";
        WhseReceiptHeader: Record "Warehouse Receipt Header";
        WhseReceiptLine: Record "Warehouse Receipt Line";
        PostedWhseReceiptLine: Record "Posted Whse. Receipt Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        WarehouseEntry: Record "Warehouse Entry";
        ReceiptMgmt: Codeunit "DOPSWHS Receipt Mgmt";
    begin
        TestHelper.EnsureSetup();
        CreateReceipt(WhseReceiptHeader, WhseReceiptLine, 'PO-S3-001', 100);

        ReceiptMgmt.ConfirmLine(WhseReceiptLine, 40, '', '', 0D, '', 'RECEIVE');
        ReceiptMgmt.PostReceipt(WhseReceiptHeader, false, false);

        PostedWhseReceiptLine.SetRange("Whse. Receipt No.", WhseReceiptHeader."No.");
        Assert.IsFalse(PostedWhseReceiptLine.IsEmpty(), 'Posted warehouse receipt line must be created.');
        ItemLedgerEntry.SetRange("Document No.", WhseReceiptHeader."No.");
        Assert.IsFalse(ItemLedgerEntry.IsEmpty(), 'Item ledger entry chain must exist.');
        WarehouseEntry.SetRange("Reference No.", WhseReceiptHeader."No.");
        Assert.IsFalse(WarehouseEntry.IsEmpty(), 'Warehouse entry chain must exist.');
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
        Line.Description := 'Sprint 3 receipt item';
        Line."Unit of Measure Code" := 'PCS';
        Line.Quantity := Qty;
        Line."Qty. to Receive" := Qty;
        Line."Bin Code" := 'RECEIVE';
        Line.Insert(true);
    end;

    var
        Assert: Codeunit Assert;
}
