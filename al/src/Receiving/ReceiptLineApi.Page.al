page 72227 "DOPSWHS Receipt Line API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'receiptLine';
    EntitySetName = 'receiptLines';
    SourceTable = "Warehouse Receipt Line";
    DelayedInsert = true;
    ODataKeyFields = "No.", "Line No.";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(no; Rec."No.") { Caption = 'no'; }
                field(lineNo; Rec."Line No.") { Caption = 'lineNo'; }
                field(sourceNo; Rec."Source No.") { Caption = 'sourceNo'; }
                field(sourceLineNo; Rec."Source Line No.") { Caption = 'sourceLineNo'; }
                field(itemNo; Rec."Item No.") { Caption = 'itemNo'; }
                field(description; Rec.Description) { Caption = 'description'; }
                field(description2; Rec."Description 2") { Caption = 'description2'; Editable = false; }
                field(unitOfMeasureCode; Rec."Unit of Measure Code") { Caption = 'unitOfMeasureCode'; }
                field(variantCode; Rec."Variant Code") { Caption = 'variantCode'; Editable = false; }
                field(gtin; ItemGtin) { Caption = 'gtin'; Editable = false; }
                field(quantity; Rec.Quantity) { Caption = 'quantity'; }
                field(qtyToReceive; Rec."Qty. to Receive") { Caption = 'qtyToReceive'; }
                field(qtyReceived; Rec."Qty. Received") { Caption = 'qtyReceived'; }
                field(binCode; Rec."Bin Code") { Caption = 'binCode'; }
                field(lotNo; LotNo) { Caption = 'lotNo'; }
                field(lotRequired; LotRequired) { Caption = 'lotRequired'; Editable = false; }
                field(supplierLotNo; SupplierLotNo) { Caption = 'supplierLotNo'; }
                field(supplierLotRequired; SupplierLotRequired) { Caption = 'supplierLotRequired'; Editable = false; }
                field(serialNo; SerialNo) { Caption = 'serialNo'; }
                field(serialRequired; SerialRequired) { Caption = 'serialRequired'; Editable = false; }
                field(expiryDate; ExpiryDate) { Caption = 'expiryDate'; }
                field(expirationDateEnabled; ExpirationDateEnabled) { Caption = 'expirationDateEnabled'; Editable = false; }
                field(expirationDateRequired; ExpirationDateRequired) { Caption = 'expirationDateRequired'; Editable = false; }
                field(licensePlateNo; LicensePlateNo) { Caption = 'licensePlateNo'; }
            }
        }
    }

    trigger OnOpenPage()
    var
        FilterMgmt: Codeunit "DOPSWHS App Role Filter Mgmt";
        RecRef: RecordRef;
    begin
        RecRef.GetTable(Rec);
        FilterMgmt.ApplyForCurrentUser(RecRef, Enum::"DOPSWHS App Filter Entity"::ReceiptLine);
        RecRef.SetTable(Rec);
    end;

    trigger OnAfterGetRecord()
    var
        Item: Record Item;
        ReceiptMgmt: Codeunit "DOPSWHS Receipt Mgmt";
    begin
        // GTIN kolonu için Item'dan çöz (WI Receiving grid'inde GTIN kolonu var).
        Clear(ItemGtin);
        if (Rec."Item No." <> '') and Item.Get(Rec."Item No.") then
            ItemGtin := Item.GTIN;
        // GET yalnız mevcut BC item-tracking bilgisini okur. İç lot numarası
        // satır açılırken üretilmez; operatör terminalde "Lot No Ata" dediğinde
        // aşağıdaki bound action standart Item."Lot Nos." serisini tüketir.
        ReceiptMgmt.GetItemTracking(Rec, LotNo, SerialNo, ExpiryDate);
        LotRequired := ReceiptMgmt.ReceiptLineRequiresLot(Rec);
        SupplierLotRequired := ReceiptMgmt.ReceiptLineRequiresSupplierLot(Rec);
        SerialRequired := ReceiptMgmt.ReceiptLineRequiresSerial(Rec);
        ExpirationDateEnabled := ReceiptMgmt.ReceiptLineUsesExpirationDates(Rec);
        ExpirationDateRequired := ReceiptMgmt.ReceiptLineRequiresExpirationDate(Rec);
        ReceiptMgmt.GetSupplierLot(Rec, LotNo, SupplierLotNo);
    end;

    trigger OnModifyRecord(): Boolean
    var
        ReceiptMgmt: Codeunit "DOPSWHS Receipt Mgmt";
    begin
        ReceiptMgmt.ConfirmLine(
            Rec, Rec."Qty. to Receive", LotNo, SerialNo, ExpiryDate,
            LicensePlateNo, Rec."Bin Code", SupplierLotNo, '');
        exit(false);
    end;

    [ServiceEnabled]
    procedure assignLotNo(): Text
    var
        ReceiptMgmt: Codeunit "DOPSWHS Receipt Mgmt";
    begin
        exit(ReceiptMgmt.AssignInboundLotNo(Rec));
    end;

    var
        LotNo: Code[50];
        SupplierLotNo: Code[50];
        SupplierLotRequired: Boolean;
        LotRequired: Boolean;
        SerialNo: Code[50];
        SerialRequired: Boolean;
        ExpiryDate: Date;
        ExpirationDateEnabled: Boolean;
        ExpirationDateRequired: Boolean;
        LicensePlateNo: Code[20];
        ItemGtin: Code[14];
}
