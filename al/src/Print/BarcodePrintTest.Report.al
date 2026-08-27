report 72373 "DOPSWHS Barcode Print Test"
{
    Caption = 'Barcode Print Test';
    UsageCategory = None;
    DefaultLayout = RDLC;
    RDLCLayout = './src/Print/BarcodePrintTest.rdlc';

    dataset
    {
        dataitem(PageLoop; Integer)
        {
            column(EncodedBarcode; EncodedBarcode) { }
            column(BarcodeValue; BarcodeValue) { }
            column(PrintedAt; Format(CurrentDateTime())) { }

            trigger OnPreDataItem()
            var
                BarcodeFontProvider: Interface "Barcode Font Provider";
                BarcodeSymbology: Enum "Barcode Symbology";
            begin
                SetRange(Number, 1, 1);
                BarcodeFontProvider := Enum::"Barcode Font Provider"::IDAutomation1D;
                BarcodeSymbology := Enum::"Barcode Symbology"::Code128;
                BarcodeFontProvider.ValidateInput(BarcodeValue, BarcodeSymbology);
                EncodedBarcode := BarcodeFontProvider.EncodeFont(BarcodeValue, BarcodeSymbology);
            end;
        }
    }

    procedure SetBarcodeValue(Value: Text)
    begin
        BarcodeValue := CopyStr(Value, 1, MaxStrLen(BarcodeValue));
    end;

    var
        BarcodeValue: Text[100];
        EncodedBarcode: Text;
}
