codeunit 72338 "DOPSWHS Multi Order Pick"
{
    // ELOG "multi" akışı: ofis kullanıcısı ~20 satış siparişini seçer, hepsi
    // TEK ambar sevkiyatında birleştirilir, sevkiyattan TEK pick oluşturulur
    // (bin/raf sırasına göre) ve depo çalışanına atanır. Çalışan raftan rafa
    // yürüyerek toplar; paketleme istasyonu sipariş bazında sevk+fatura eder
    // (bkz. "DOPSWHS Pack Station Mgmt").
    Access = Public;

    /// <summary>Geriye dönük sarmalayıcı — mod belirtilmezse Multi.</summary>
    procedure CreateGroupedPick(OrderNosCsv: Text; AssignToUserId: Code[50]; var ShipmentNo: Code[20]): Code[20]
    begin
        exit(CreateGroupedPick(OrderNosCsv, AssignToUserId, ShipmentNo, 'multi'));
    end;

    procedure CreateGroupedPick(OrderNosCsv: Text; AssignToUserId: Code[50]; var ShipmentNo: Code[20]; ModeTxt: Text): Code[20]
    var
        SalesHeader: Record "Sales Header";
        WhseShptHeader: Record "Warehouse Shipment Header";
        OrderList: List of [Text];
        OrderNo: Text;
        OrderCode: Code[20];
        LocationCode: Code[10];
        ExistingShipmentNo: Code[20];
        SelectedOrders: Dictionary of [Code[20], Boolean];
        AnyLines: Boolean;
        PickNo: Code[20];
    begin
        if OrderNosCsv.Trim() = '' then
            Error(NoOrdersErr);
        OrderList := OrderNosCsv.Split(',');
        BuildSelectedOrderSet(OrderList, SelectedOrders);

        // Tüm siparişleri doğrula/serbest bırak; lokasyonu ilk satırdan belirle.
        foreach OrderNo in OrderList do begin
            OrderCode := CopyStr(OrderNo.Trim(), 1, MaxStrLen(OrderCode));
            if OrderCode <> '' then begin
                SalesHeader.Get(SalesHeader."Document Type"::Order, OrderCode);
                EnsureReleased(SalesHeader);
                if LocationCode = '' then
                    LocationCode := FirstItemLocation(OrderCode);
            end;
        end;

        // Sipariş satırları daha önce bir warehouse shipment'a alınmış,
        // ancak pick oluşmamış olabilir. Bu durumda ikinci, boş bir sevkiyat
        // yaratmak yerine mevcut belgeyi kullan. Birden fazla mevcut sevkiyat
        // tek picking order başlığıyla izlenemeyeceği için açıkça reddedilir.
        ExistingShipmentNo := FindExistingShipmentNo(OrderList);
        if ExistingShipmentNo <> '' then begin
            if not WhseShptHeader.Get(ExistingShipmentNo) then
                Error(ShipmentNotFoundErr, ExistingShipmentNo);
            if WhseShptHeader."Location Code" <> LocationCode then
                Error(ShipmentLocationErr, ExistingShipmentNo, WhseShptHeader."Location Code", LocationCode);
            EnsureShipmentContainsOnlySelectedOrders(ExistingShipmentNo, SelectedOrders);
            ReopenShipment(WhseShptHeader);
        end else begin
            Clear(WhseShptHeader);
            WhseShptHeader.Init();
            WhseShptHeader."No." := '';
            WhseShptHeader.Insert(true);
            WhseShptHeader.Validate("Location Code", LocationCode);
            WhseShptHeader.Modify(true);
        end;
        ShipmentNo := WhseShptHeader."No.";

        foreach OrderNo in OrderList do begin
            OrderCode := CopyStr(OrderNo.Trim(), 1, MaxStrLen(OrderCode));
            if OrderCode <> '' then
                if AddOrderToShipment(WhseShptHeader, OrderCode) then
                    AnyLines := true;
        end;
        if not AnyLines then
            Error(NoShippableLinesErr);

        ReleaseShipment(WhseShptHeader);
        PickNo := CreatePickFromShipment(WhseShptHeader, AssignToUserId);
        StampPickMode(PickNo, ModeTxt);
        Log('MultiPick.Created', PickNo);
        exit(PickNo);
    end;

    // Terminal pick listesindeki Multi/Bulk/Batch sekmeleri bu damgaya göre
    // filtreler; standart BC pick'leri boş kalır ("Tümü"nde görünür).
    local procedure StampPickMode(PickNo: Code[20]; ModeTxt: Text)
    var
        PickHeader: Record "Warehouse Activity Header";
    begin
        if not PickHeader.Get(PickHeader.Type::Pick, PickNo) then
            exit;
        case LowerCase(ModeTxt) of
            'bulk':
                PickHeader."DOPSWHS Pick Mode" := PickHeader."DOPSWHS Pick Mode"::Bulk;
            'batch', 'mono', 'mono-sku':
                PickHeader."DOPSWHS Pick Mode" := PickHeader."DOPSWHS Pick Mode"::Batch;
            else
                PickHeader."DOPSWHS Pick Mode" := PickHeader."DOPSWHS Pick Mode"::Multi;
        end;
        PickHeader.Modify(true);
    end;

    local procedure EnsureReleased(var SalesHeader: Record "Sales Header")
    var
        ReleaseSalesDoc: Codeunit "Release Sales Document";
    begin
        if SalesHeader.Status <> SalesHeader.Status::Released then
            ReleaseSalesDoc.PerformManualRelease(SalesHeader);
    end;

    local procedure FirstItemLocation(OrderNo: Code[20]): Code[10]
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange("Document No.", OrderNo);
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetFilter("Outstanding Quantity", '>0');
        if SalesLine.FindFirst() then
            exit(SalesLine."Location Code");
        exit('');
    end;

    local procedure AddOrderToShipment(var WhseShptHeader: Record "Warehouse Shipment Header"; OrderNo: Code[20]): Boolean
    var
        SalesLine: Record "Sales Line";
        SalesWhseMgt: Codeunit "Sales Warehouse Mgt.";
        Added: Boolean;
    begin
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange("Document No.", OrderNo);
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetFilter("Outstanding Quantity", '>0');
        SalesLine.SetRange("Location Code", WhseShptHeader."Location Code");
        SalesLine.SetRange("Drop Shipment", false);
        if SalesLine.FindSet() then
            repeat
                if ShipmentLineExistsOn(SalesLine, WhseShptHeader."No.") then
                    // Mevcut shipment yeniden kullanılıyor; satır zaten bu
                    // belgedeyse sevk edilebilir satır olarak kabul et.
                    Added := true
                else begin
                    EnsureLineNotOnAnotherShipment(SalesLine, WhseShptHeader."No.");
                    // FromSalesLine2ShptLine kendi içinde Warehouse Shipment Line'ı
                    // oluşturur. Boolean sonucu satır oluşmasa da true olabildiği
                    // için gerçek sonucu kaynak satırı tekrar arayarak doğrula.
                    SalesWhseMgt.FromSalesLine2ShptLine(WhseShptHeader, SalesLine);
                    if ShipmentLineExistsOn(SalesLine, WhseShptHeader."No.") then
                        Added := true;
                end;
            until SalesLine.Next() = 0;
        exit(Added);
    end;

    local procedure ShipmentLineExistsOn(SalesLine: Record "Sales Line"; ShipmentNo: Code[20]): Boolean
    var
        WhseShptLine: Record "Warehouse Shipment Line";
    begin
        WhseShptLine.SetRange("No.", ShipmentNo);
        WhseShptLine.SetRange("Source Type", Database::"Sales Line");
        WhseShptLine.SetRange("Source Subtype", SalesLine."Document Type".AsInteger());
        WhseShptLine.SetRange("Source No.", SalesLine."Document No.");
        WhseShptLine.SetRange("Source Line No.", SalesLine."Line No.");
        exit(not WhseShptLine.IsEmpty());
    end;

    local procedure EnsureLineNotOnAnotherShipment(SalesLine: Record "Sales Line"; ShipmentNo: Code[20])
    var
        WhseShptLine: Record "Warehouse Shipment Line";
    begin
        WhseShptLine.SetRange("Source Type", Database::"Sales Line");
        WhseShptLine.SetRange("Source Subtype", SalesLine."Document Type".AsInteger());
        WhseShptLine.SetRange("Source No.", SalesLine."Document No.");
        WhseShptLine.SetRange("Source Line No.", SalesLine."Line No.");
        WhseShptLine.SetFilter("No.", '<>%1', ShipmentNo);
        if WhseShptLine.FindFirst() then
            Error(LineOnAnotherShipmentErr, SalesLine."Document No.", SalesLine."Line No.", WhseShptLine."No.");
    end;

    local procedure BuildSelectedOrderSet(var OrderList: List of [Text]; var SelectedOrders: Dictionary of [Code[20], Boolean])
    var
        OrderNoText: Text;
        OrderNo: Code[20];
    begin
        foreach OrderNoText in OrderList do begin
            OrderNo := CopyStr(OrderNoText.Trim(), 1, MaxStrLen(OrderNo));
            if (OrderNo <> '') and (not SelectedOrders.ContainsKey(OrderNo)) then
                SelectedOrders.Add(OrderNo, true);
        end;
    end;

    local procedure FindExistingShipmentNo(var OrderList: List of [Text]): Code[20]
    var
        WhseShptLine: Record "Warehouse Shipment Line";
        OrderNoText: Text;
        OrderNo: Code[20];
        ExistingShipmentNo: Code[20];
    begin
        foreach OrderNoText in OrderList do begin
            OrderNo := CopyStr(OrderNoText.Trim(), 1, MaxStrLen(OrderNo));
            if OrderNo <> '' then begin
                WhseShptLine.Reset();
                WhseShptLine.SetRange("Source Type", Database::"Sales Line");
                WhseShptLine.SetRange("Source Subtype", 1); // Sales Order
                WhseShptLine.SetRange("Source No.", OrderNo);
                WhseShptLine.SetLoadFields("No.");
                if WhseShptLine.FindSet() then
                    repeat
                        if ExistingShipmentNo = '' then
                            ExistingShipmentNo := WhseShptLine."No."
                        else
                            if ExistingShipmentNo <> WhseShptLine."No." then
                                Error(OrdersOnMultipleShipmentsErr, ExistingShipmentNo, WhseShptLine."No.");
                    until WhseShptLine.Next() = 0;
            end;
        end;
        exit(ExistingShipmentNo);
    end;

    local procedure EnsureShipmentContainsOnlySelectedOrders(ShipmentNo: Code[20]; var SelectedOrders: Dictionary of [Code[20], Boolean])
    var
        WhseShptLine: Record "Warehouse Shipment Line";
    begin
        WhseShptLine.SetRange("No.", ShipmentNo);
        WhseShptLine.SetLoadFields("Source Type", "Source Subtype", "Source No.");
        if WhseShptLine.FindSet() then
            repeat
                if (WhseShptLine."Source Type" <> Database::"Sales Line") or
                   (WhseShptLine."Source Subtype" <> 1)
                then
                    Error(ShipmentHasOtherSourceErr, ShipmentNo);
                if not SelectedOrders.ContainsKey(WhseShptLine."Source No.") then
                    Error(ShipmentHasOtherOrderErr, ShipmentNo, WhseShptLine."Source No.");
            until WhseShptLine.Next() = 0;
    end;

    local procedure ReopenShipment(var WhseShptHeader: Record "Warehouse Shipment Header")
    var
        WhseShipmentRelease: Codeunit "Whse.-Shipment Release";
    begin
        if WhseShptHeader.Status = WhseShptHeader.Status::Open then
            exit;
        WhseShipmentRelease.SetSuppressCommit(true);
        WhseShipmentRelease.Reopen(WhseShptHeader);
    end;

    local procedure ReleaseShipment(var WhseShptHeader: Record "Warehouse Shipment Header")
    var
        WhseShipmentRelease: Codeunit "Whse.-Shipment Release";
    begin
        if WhseShptHeader.Status <> WhseShptHeader.Status::Released then begin
            // Pick oluşturma daha sonra hata verirse yeni/reopen edilen shipment
            // yetim kalmasın; tüm işlem tek transaction olarak geri alınsın.
            WhseShipmentRelease.SetSuppressCommit(true);
            WhseShipmentRelease.Release(WhseShptHeader);
            WhseShptHeader.Get(WhseShptHeader."No.");
        end;
    end;

    local procedure CreatePickFromShipment(var WhseShptHeader: Record "Warehouse Shipment Header"; AssignToUserId: Code[50]): Code[20]
    var
        WhseShptLine: Record "Warehouse Shipment Line";
        WhseActivityLine: Record "Warehouse Activity Line";
        PickHeader: Record "Warehouse Activity Header";
        CreatePick: Report "Whse.-Shipment - Create Pick";
        PickNo: Code[20];
    begin
        WhseShptLine.SetRange("No.", WhseShptHeader."No.");
        if not WhseShptLine.FindFirst() then
            Error(NoShippableLinesErr);

        // Raf/bin sırasına göre sıralı pick — ELOG: "1. raftan son rafa yürüyor".
        CreatePick.SetWhseShipmentLine(WhseShptLine, WhseShptHeader);
        CreatePick.SetHideValidationDialog(true);
        // Qty. to Handle boş başlar: el terminalinde raf ve ürün okutulmadan
        // satır tamamlanmış görünmez.
        // Standart rapor, Initialize ile verilen kullanıcıyı "Warehouse Employee"
        // tablosunda doğrular. WMS'in yerel operatörleri (ör. KAANODABAS) bu
        // tabloda bulunmak zorunda değildir. Pick'i önce atamasız oluşturup
        // aşağıda WMS kullanıcı kimliğini doğrudan başlığa yazarız.
        CreatePick.Initialize('', Enum::"Whse. Activity Sorting Method"::"Shelf or Bin", false, true, false);
        CreatePick.UseRequestPage(false);
        CreatePick.RunModal();

        WhseActivityLine.SetRange("Activity Type", WhseActivityLine."Activity Type"::Pick);
        WhseActivityLine.SetRange("Whse. Document Type", WhseActivityLine."Whse. Document Type"::Shipment);
        WhseActivityLine.SetRange("Whse. Document No.", WhseShptHeader."No.");
        if not WhseActivityLine.FindLast() then
            Error(PickNotCreatedErr, WhseShptHeader."No.");
        PickNo := WhseActivityLine."No.";

        EnsurePickHasSourceBins(PickNo, WhseShptHeader."Location Code");

        // Yerel WMS kullanıcısını pick başlığına yaz; terminalde "Bana atanan"
        // filtresi bu alanı kullanır. Doğrudan atama TableRelation doğrulamasını
        // tetiklemez ve yerel kullanıcı modelini standart BC çalışanına bağlamaz.
        if (AssignToUserId <> '') and PickHeader.Get(PickHeader.Type::Pick, PickNo) then
            if PickHeader."Assigned User ID" <> AssignToUserId then begin
                PickHeader."Assigned User ID" := CopyStr(AssignToUserId, 1, MaxStrLen(PickHeader."Assigned User ID"));
                PickHeader.Modify(true);
            end;
        exit(PickNo);
    end;

    local procedure EnsurePickHasSourceBins(PickNo: Code[20]; LocationCode: Code[10])
    var
        Location: Record Location;
        WhseActivityLine: Record "Warehouse Activity Line";
    begin
        Location.Get(LocationCode);
        if not Location."Bin Mandatory" then
            Error(LocationRequiresBinsErr, LocationCode);

        WhseActivityLine.SetRange("Activity Type", WhseActivityLine."Activity Type"::Pick);
        WhseActivityLine.SetRange("No.", PickNo);
        WhseActivityLine.SetRange("Action Type", WhseActivityLine."Action Type"::Take);
        if WhseActivityLine.FindSet() then
            repeat
                if WhseActivityLine."Bin Code" = '' then
                    Error(PickSourceBinMissingErr, PickNo, WhseActivityLine."Item No.");
            until WhseActivityLine.Next() = 0;
    end;

    local procedure Log(Category: Text; DocNo: Code[20])
    var
        Telemetry: Codeunit "DOPSWHS Telemetry";
    begin
        Telemetry.LogInfo(Category, DocNo);
    end;

    var
        NoOrdersErr: Label 'En az bir satış siparişi seçilmelidir.';
        NoShippableLinesErr: Label 'Seçilen siparişlerde ambar sevkiyatına aktarılabilecek satır bulunamadı. Bekleyen miktarı, lokasyonu ve mevcut ambar sevkiyatlarını kontrol edin.';
        PickNotCreatedErr: Label '%1 ambar sevkiyatı için pick oluşturulamadı. Raf/bin içeriğini ve kullanılabilir stok miktarını kontrol edin.', Comment = '%1 = Warehouse Shipment No.';
        LocationRequiresBinsErr: Label '%1 lokasyonunda Zorunlu Raf (Bin Mandatory) etkin değildir. El terminaline toplama göndermeden önce lokasyonun raf/bin yapısını tamamlayın.', Comment = '%1 = location';
        PickSourceBinMissingErr: Label '%1 toplamasında %2 ürünü için kaynak raf/bin bulunamadı. Ürünün bin içeriğini ve varsayılan rafını düzeltmeden toplama terminale gönderilemez.', Comment = '%1 = pick, %2 = item';
        ShipmentNotFoundErr: Label 'Mevcut ambar sevkiyatı %1 bulunamadı.', Comment = '%1 = Warehouse Shipment No.';
        ShipmentLocationErr: Label 'Ambar sevkiyatı %1, %2 lokasyonunda; toplama grubu ise %3 lokasyonunda.', Comment = '%1 = shipment, %2/%3 = location';
        OrdersOnMultipleShipmentsErr: Label 'Seçilen siparişler birden fazla ambar sevkiyatında (%1 ve %2). Tek pick oluşturmak için önce siparişleri aynı sevkiyatta birleştirin.', Comment = '%1/%2 = shipment';
        ShipmentHasOtherOrderErr: Label 'Ambar sevkiyatı %1, toplama grubunda bulunmayan %2 siparişini de içeriyor. Yanlış siparişi toplamamak için pick oluşturulmadı.', Comment = '%1 = shipment, %2 = sales order';
        ShipmentHasOtherSourceErr: Label 'Ambar sevkiyatı %1 satış siparişi dışında başka kaynak satırları da içeriyor; bu toplama grubunda kullanılamaz.', Comment = '%1 = shipment';
        LineOnAnotherShipmentErr: Label '%1 siparişinin %2 numaralı satırı %3 ambar sevkiyatında bulunuyor.', Comment = '%1 = order, %2 = line, %3 = shipment';
}
