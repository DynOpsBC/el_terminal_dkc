page 72226 "DOPSWHS Barcode Parse API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'barcode';
    EntitySetName = 'barcodes';
    SourceTable = "DOPSWHS Barcode Rule";
    DelayedInsert = true;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(code; Rec."Code") { Caption = 'code'; }
                field(description; Rec.Description) { Caption = 'description'; }
            }
        }
    }

    [ServiceEnabled]
    procedure Parse(raw: Text): Text
    var
        Parser: Codeunit "DOPSWHS Barcode Parser";
        Result: JsonObject;
    begin
        Parser.ParseBarcode(raw, Result);
        exit(Format(Result));
    end;
}
