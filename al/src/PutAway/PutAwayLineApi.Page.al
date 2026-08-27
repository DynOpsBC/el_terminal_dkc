page 72228 "DOPSWHS PutAway Line API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'putAwayLine';
    EntitySetName = 'putAwayLines';
    SourceTable = "Warehouse Activity Line";
    DelayedInsert = true;
    ODataKeyFields = "Activity Type", "No.", "Line No.";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(activityType; Rec."Activity Type") { Caption = 'activityType'; Editable = false; }
                field(actionType; Rec."Action Type") { Caption = 'actionType'; Editable = false; }
                field(no; Rec."No.") { Caption = 'no'; Editable = false; }
                field(lineNo; Rec."Line No.") { Caption = 'lineNo'; Editable = false; }
                field(sourceNo; Rec."Source No.") { Caption = 'sourceNo'; Editable = false; }
                field(sourceLineNo; Rec."Source Line No.") { Caption = 'sourceLineNo'; Editable = false; }
                field(whseDocumentNo; Rec."Whse. Document No.") { Caption = 'whseDocumentNo'; Editable = false; }
                field(whseDocumentLineNo; Rec."Whse. Document Line No.") { Caption = 'whseDocumentLineNo'; Editable = false; }
                field(itemNo; Rec."Item No.") { Caption = 'itemNo'; Editable = false; }
                // Ek alanlar (müşteri isteği: ürün no+isim yetmiyor).
                field(description; Rec.Description) { Caption = 'description'; Editable = false; }
                field(description2; Rec."Description 2") { Caption = 'description2'; Editable = false; }
                field(unitOfMeasureCode; Rec."Unit of Measure Code") { Caption = 'unitOfMeasureCode'; Editable = false; }
                field(variantCode; Rec."Variant Code") { Caption = 'variantCode'; Editable = false; }
                field(gtin; ItemGtin) { Caption = 'gtin'; Editable = false; }
                field(zoneCode; Rec."Zone Code") { Caption = 'zoneCode'; Editable = false; }
                field(binCode; Rec."Bin Code") { Caption = 'binCode'; }
                // Kısmi register görünürlüğü: toplam / kalan / konan — mobil bu
                // üçlü olmadan parçalı yerleştirmede kalan miktarı gösteremiyor.
                field(quantity; Rec.Quantity) { Caption = 'quantity'; Editable = false; }
                field(qtyOutstanding; Rec."Qty. Outstanding") { Caption = 'qtyOutstanding'; Editable = false; }
                field(qtyToHandle; Rec."Qty. to Handle") { Caption = 'qtyToHandle'; }
                field(qtyHandled; Rec."Qty. Handled") { Caption = 'qtyHandled'; Editable = false; }
                field(lpNo; Rec."LP No.") { Caption = 'lpNo'; }
                field(targetLpNo; Rec."Target LP No.") { Caption = 'targetLpNo'; Editable = false; }
            }
        }
    }
    trigger OnOpenPage()
    var
        FilterMgmt: Codeunit "DOPSWHS App Role Filter Mgmt";
        RecRef: RecordRef;
    begin
        RecRef.GetTable(Rec);
        FilterMgmt.ApplyForCurrentUser(RecRef, Enum::"DOPSWHS App Filter Entity"::PutAwayLine);
        RecRef.SetTable(Rec);
    end;

    trigger OnAfterGetRecord()
    var
        Item: Record Item;
    begin
        Clear(ItemGtin);
        if (Rec."Item No." <> '') and Item.Get(Rec."Item No.") then
            ItemGtin := Item.GTIN;
    end;

    /// <summary>
    /// Mobil yerleştirme için hedef raf ve miktarı tek işlemde doğrular ve
    /// Place satırına kalıcı olarak yazar. Genel API PATCH'i bazı BC
    /// sürümlerinde Warehouse Activity Line'ın raf doğrulamasını güvenilir
    /// biçimde çalıştırmadığı için register önerilen eski rafla devam
    /// edebiliyordu.
    /// </summary>
    [ServiceEnabled]
    procedure setPlacement(targetBinCode: Code[20]; qtyToHandle: Decimal)
    var
        TargetBin: Record Bin;
    begin
        Rec.TestField("Action Type", Rec."Action Type"::Place);
        if targetBinCode = '' then
            Error('Hedef raf zorunludur.');
        if not TargetBin.Get(Rec."Location Code", targetBinCode) then
            Error('%1 hedef rafı %2 lokasyonunda bulunamadı.', targetBinCode, Rec."Location Code");
        if qtyToHandle <= 0 then
            Error('Yerleştirme miktarı sıfırdan büyük olmalıdır.');
        if qtyToHandle > Rec."Qty. Outstanding" then
            Error('Yerleştirme miktarı %1, kalan %2 miktarını aşamaz.', qtyToHandle, Rec."Qty. Outstanding");

        // Önerilen raftan farklı bir hedef başka zone'da olabilir. Yalnız Bin
        // Code'u doğrulamak, Place satırındaki eski öneri zone'unu korur ve BC
        // geçerli hedef rafı reddeder. Önce hedef binin gerçek zone'unu uygula;
        // standart Validate yine bin tipi/blokaj gibi depo kurallarını korur.
        Rec.Validate("Zone Code", TargetBin."Zone Code");
        Rec.Validate("Bin Code", targetBinCode);
        Rec.Validate("Qty. to Handle", qtyToHandle);
        Rec.Modify(true);
    end;

    var
        ItemGtin: Code[14];
}
