page 72337 "DOPSWHS Pack Session Line API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'packSessionLine';
    EntitySetName = 'packSessionLines';
    SourceTable = "DOPSWHS Pack Session Line";
    DelayedInsert = true;
    ODataKeyFields = "Session Entry No.", "Line No.";
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(sessionEntryNo; Rec."Session Entry No.") { Caption = 'sessionEntryNo'; Editable = false; }
                field(lineNo; Rec."Line No.") { Caption = 'lineNo'; Editable = false; }
                field(sourceOrderNo; Rec."Source Order No.") { Caption = 'sourceOrderNo'; Editable = false; }
                field(itemNo; Rec."Item No.") { Caption = 'itemNo'; Editable = false; }
                field(variantCode; Rec."Variant Code") { Caption = 'variantCode'; Editable = false; }
                field(unitOfMeasureCode; Rec."Unit of Measure Code") { Caption = 'unitOfMeasureCode'; Editable = false; }
                field(description; Rec.Description) { Caption = 'description'; Editable = false; }
                field(gtin; Rec.GTIN) { Caption = 'gtin'; Editable = false; }
                field(qtyExpected; Rec."Qty. Expected") { Caption = 'qtyExpected'; Editable = false; }
                field(qtyPacked; Rec."Qty. Packed") { Caption = 'qtyPacked'; Editable = false; }
                field(orderCompleted; Rec."Order Completed") { Caption = 'orderCompleted'; Editable = false; }
                field(boxLpNo; Rec."Box LP No.") { Caption = 'boxLpNo'; Editable = false; }
                // Kargo kolisi kayıtlı LP OLMAK ZORUNDA DEĞİL (kargo etiketi /
                // SSCC / matbu koli barkodu). Bu alan yayınlanmadan terminal
                // koliyi bağlanmış saymıyor ve sipariş kapanmıyordu.
                field(boxBarcode; Rec."Box Barcode") { Caption = 'boxBarcode'; Editable = false; }
            }
        }
    }
}
