codeunit 72141 "DOPSWHS LP Label Tests"
{
    Subtype = Test;

    [Test]
    procedure LabelContainsScannableLpQr()
    var
        LP: Record "DOPSWHS LP Header" temporary;
        LabelReport: Report "DOPSWHS LP Label";
        Assert: Codeunit "Library Assert";
        Zpl: Text;
    begin
        LP.Init();
        LP."No." := 'LP00042';
        LP.SSCC := '123456789012345675';

        Zpl := LabelReport.BuildZpl(LP);

        Assert.IsTrue(StrPos(Zpl, '^BQN,2,6') > 0, 'LP label must contain a Zebra QR command.');
        Assert.IsTrue(StrPos(Zpl, '^FDLA,LP00042^FS') > 0, 'QR payload must contain the exact LP number.');
        Assert.IsTrue(StrPos(Zpl, '^FD123456789012345675^FS') > 0, 'Linear barcode must keep the SSCC value.');
    end;

    [Test]
    procedure OpenLpWithoutSsccStillPrintsQr()
    var
        LP: Record "DOPSWHS LP Header" temporary;
        LabelReport: Report "DOPSWHS LP Label";
        Assert: Codeunit "Library Assert";
        Zpl: Text;
    begin
        LP.Init();
        LP."No." := 'LP00043';

        Zpl := LabelReport.BuildZpl(LP);

        Assert.IsTrue(StrPos(Zpl, '^FDLA,LP00043^FS') > 0, 'An open LP must be printable before SSCC generation.');
    end;

    [Test]
    procedure PalletItemLabelShowsReceiptTotalAndPalletQuantity()
    var
        LP: Record "DOPSWHS LP Header" temporary;
        LPLine: Record "DOPSWHS LP Line" temporary;
        Dispatcher: Codeunit "DOPSWHS Print Dispatcher";
        Assert: Codeunit "Library Assert";
        Zpl: Text;
    begin
        LP.Init();
        LP."No." := 'LP00044';
        LPLine.Init();
        LPLine."LP No." := LP."No.";
        LPLine."Item No." := 'AB.01939';
        LPLine."Unit of Measure" := 'ADET';
        LPLine.Quantity := 250;
        LPLine."Lot No." := 'A100171';
        LPLine."Source Document Quantity" := 500;

        Zpl := Dispatcher.BuildPalletItemZpl(LP, LPLine);

        Assert.IsTrue(StrPos(Zpl, 'TOPLAM MAL KABUL: 500 ADET') > 0, 'MTE must keep the total receipt quantity.');
        Assert.IsTrue(StrPos(Zpl, 'PALET MIKTARI: 250 ADET') > 0, 'MTE must show the quantity assigned to this LP.');
        Assert.IsTrue(StrPos(Zpl, '^FDLA,LP00044^FS') > 0, 'A pallet-bound MTE QR must identify the LP.');
        Assert.IsTrue(StrPos(Zpl, 'LP: LP00044') > 0, 'MTE must visibly identify its LP.');
    end;

    [Test]
    procedure MteQrFallsBackToLotAndThenItemWithoutLp()
    var
        LP: Record "DOPSWHS LP Header" temporary;
        LPLine: Record "DOPSWHS LP Line" temporary;
        Dispatcher: Codeunit "DOPSWHS Print Dispatcher";
        Assert: Codeunit "Library Assert";
        Zpl: Text;
    begin
        LP.Init();
        LPLine.Init();
        LPLine."Item No." := 'AB.01939';
        LPLine."Lot No." := 'A100171';

        Zpl := Dispatcher.BuildPalletItemZpl(LP, LPLine);
        Assert.IsTrue(StrPos(Zpl, '^FDLA,A100171^FS') > 0, 'An LP-free MTE QR must identify the lot when present.');

        LPLine."Lot No." := '';
        Zpl := Dispatcher.BuildPalletItemZpl(LP, LPLine);
        Assert.IsTrue(StrPos(Zpl, '^FDLA,AB.01939^FS') > 0, 'An LP-free MTE QR must fall back to the item number.');
    end;
}
