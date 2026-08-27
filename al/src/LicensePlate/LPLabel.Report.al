report 72091 "DOPSWHS LP Label"
{
    Caption = 'LP Label';
    UsageCategory = None;
    DefaultLayout = RDLC;
    RDLCLayout = './LPLabel.rdlc';

    dataset
    {
        dataitem(LP; "DOPSWHS LP Header")
        {
            column(No_; "No.") { }
            column(SSCC; SSCC) { }
            column(Location_Code; "Location Code") { }
            column(Bin_Code; "Bin Code") { }
            column(Built_DateTime; "Built DateTime") { }
            column(Weight_kg; "Weight kg") { }
            column(Length_cm; "Length cm") { }
            column(Width_cm; "Width cm") { }
            column(Height_cm; "Height cm") { }
            column(ZplText; BuildZpl(LP)) { }
        }
    }

    procedure BuildZpl(var LP: Record "DOPSWHS LP Header"): Text
    var
        LPLine: Record "DOPSWHS LP Line";
        Item: Record Item;
        ZplEncoder: Codeunit "DOPSWHS ZPL Encoder";
        Dimensions: Text;
        ItemText: Text;
        LotText: Text;
        QtyText: Text;
        BarcodeData: Text;
        QrData: Text;
        ExtraLinesText: Text;
        LineCount: Integer;
    begin
        LPLine.SetRange("LP No.", LP."No.");
        LPLine.SetFilter("Item No.", '<>%1', '');
        if LPLine.FindSet() then begin
            repeat
                LineCount += 1;
                if LineCount = 1 then begin
                    ItemText := LPLine."Item No.";
                    if Item.Get(LPLine."Item No.") then
                        ItemText += ' - ' + Item.Description;
                    QtyText := StrSubstNo('PALET MIKTARI: %1 %2', LPLine.Quantity, LPLine."Unit of Measure");
                    if LPLine."Lot No." <> '' then
                        LotText := 'LOT: ' + LPLine."Lot No.";
                end;
            until LPLine.Next() = 0;
            if LineCount > 1 then
                ExtraLinesText := StrSubstNo('+%1 DIGER URUN SATIRI', LineCount - 1);
        end;
        // ^CI28 = UTF-8 character set so Turkish characters (ç ğ ş ü ö İ) and
        // any non-ASCII Item/Bin descriptions print correctly. Without this
        // the printer falls back to its default code page and outputs mojibake.
        Dimensions := Format(LP."Built DateTime") + ' ' + Format(LP."Weight kg") + 'kg ' +
            Format(LP."Length cm") + 'x' + Format(LP."Width cm") + 'x' + Format(LP."Height cm");
        BarcodeData := LP.SSCC;
        if BarcodeData = '' then
            BarcodeData := LP."No.";
        // The QR always carries the actual LP number. SSCC remains available in
        // the linear barcode, while scanning the QR reopens the exact LP record
        // even before Stop has generated an SSCC.
        QrData := LP."No.";
        exit(
            '^XA^CI28^PW812^LL406' +
            '^FO40,30^A0N,36,36^FH_^FDLP ' + ZplEncoder.EncodeFieldData(LP."No.") + '^FS' +
            '^FO40,72^BY2^BCN,82,Y,N,N^FH_^FD' + ZplEncoder.EncodeFieldData(BarcodeData) + '^FS' +
            '^FO590,24^BQN,2,6^FH_^FDLA,' + ZplEncoder.EncodeFieldData(QrData) + '^FS' +
            '^FO40,185^A0N,25,25^FH_^FD' + ZplEncoder.EncodeFieldData(LP."Location Code" + ' / ' + LP."Bin Code") + '^FS' +
            '^FO40,220^A0N,25,25^FH_^FD' + ZplEncoder.EncodeFieldData(CopyStr(ItemText, 1, 52)) + '^FS' +
            '^FO40,258^A0N,34,34^FH_^FD' + ZplEncoder.EncodeFieldData(CopyStr(QtyText, 1, 42)) + '^FS' +
            '^FO40,304^A0N,22,22^FH_^FD' + ZplEncoder.EncodeFieldData(CopyStr(LotText + ' ' + ExtraLinesText, 1, 65)) + '^FS' +
            '^FO40,350^A0N,18,18^FH_^FD' + ZplEncoder.EncodeFieldData(CopyStr(Dimensions, 1, 75)) + '^FS' +
            '^XZ');
    end;
}
