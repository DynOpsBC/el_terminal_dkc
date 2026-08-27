report 72374 "DOPSWHS LP QR Document"
{
    Caption = 'LP QR Document';
    UsageCategory = None;
    DefaultLayout = RDLC;
    RDLCLayout = './src/LicensePlate/LPQrDocument.rdlc';

    dataset
    {
        dataitem(LicensePlate; "DOPSWHS LP Header")
        {
            RequestFilterFields = "No.";

            column(LpNo; "No.") { }
            column(TemplateCode; "LP Template Code") { }
            column(LocationCode; "Location Code") { }
            column(BinCode; "Bin Code") { }
            column(StatusText; Format(Status)) { }
            column(SSCCValue; SSCC) { }
            column(QrImageBase64; QrImageBase64) { }
            column(PrintedAt; Format(CurrentDateTime())) { }

            trigger OnAfterGetRecord()
            var
                BarcodeImageProvider: Interface "Barcode Image Provider 2D";
                BarcodeImage: Codeunit "Temp Blob";
                Base64Convert: Codeunit "Base64 Convert";
                ImageInStream: InStream;
            begin
                BarcodeImageProvider := Enum::"Barcode Image Provider 2D"::Dynamics2D;
                BarcodeImage := BarcodeImageProvider.EncodeImage("No.", Enum::"Barcode Symbology 2D"::"QR-Code");
                if not BarcodeImage.HasValue() then
                    Error('The QR image for LP %1 could not be generated.', "No.");
                BarcodeImage.CreateInStream(ImageInStream);
                QrImageBase64 := Base64Convert.ToBase64(ImageInStream);
            end;
        }
    }

    var
        QrImageBase64: Text;
}
