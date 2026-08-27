codeunit 72354 "DOPSWHS Picking Order Mgmt"
{
    Access = Public;

    procedure AddSelectedOrders(var PickingHeader: Record "DOPSWHS Picking Order Header"; var SalesHeader: Record "Sales Header")
    begin
        PickingHeader.TestField(Status, PickingHeader.Status::Open);
        if SalesHeader.FindSet() then
            repeat
                AddOrder(PickingHeader, SalesHeader);
            until SalesHeader.Next() = 0;
    end;

    /// <summary>
    /// Seçili satış siparişlerini lokasyon ve sipariş içeriğine göre otomatik
    /// toplama gruplarına ayırır. Aynı lokasyondaki:
    /// - iki veya daha fazla bekleyen ürün satırı içeren siparişler Multi,
    /// - tek ürün satırı içeren ve SKU'su seçimde benzersiz olan siparişler Mono,
    /// - aynı SKU'lu tek ürün satırını içeren birden fazla sipariş Tek SKU grubuna alınır.
    /// Pick oluşturmaz; depo sorumlusu oluşan grupları listeden kontrol eder,
    /// toplayıcıyı atar ve karttan pick oluşturur.
    /// </summary>
    procedure AutoCreatePickingGroups(var SalesHeader: Record "Sales Header"; var MultiGroupCount: Integer; var MonoGroupCount: Integer; var SingleSkuGroupCount: Integer; var OrderCount: Integer; var SkippedOrderCount: Integer)
    var
        PickingHeader: Record "DOPSWHS Picking Order Header";
        PickingLineGuard: Record "DOPSWHS Picking Order Line";
        FlowMode: Enum "DOPSWHS Pick Mode";
        SingleSkuCounts: Dictionary of [Text, Integer];
        HeaderEntryNos: Dictionary of [Text, Integer];
        LocationCode: Code[10];
        SingleSkuNo: Text;
        GroupKey: Text;
        SkuProfileKey: Text;
        ItemLineCount: Integer;
        ExistingSkuOrderCount: Integer;
        IsNewGroup: Boolean;
    begin
        Clear(MultiGroupCount);
        Clear(MonoGroupCount);
        Clear(SingleSkuGroupCount);
        Clear(OrderCount);
        Clear(SkippedOrderCount);

        if SalesHeader.IsEmpty() then
            Error('Otomatik ayırma için en az bir satış siparişi seçin.');

        // Seçim açıkken başka bir oturum aynı siparişi gruplamasın.
        // Böylece ilk ve ikinci sınıflandırma geçişi aynı veri kümesini görür.
        PickingLineGuard.LockTable();

        // İlk geçiş: tek SKU siparişlerinde aynı lokasyon + SKU tekrarını
        // say. Tekrar edenler Tek SKU, benzersiz kalanlar Mono olacaktır.
        if SalesHeader.FindSet() then
            repeat
                if IsOrderAvailableForAutoGrouping(SalesHeader."No.") then begin
                    GetOrderProfile(SalesHeader, LocationCode, ItemLineCount, SingleSkuNo);
                    if ItemLineCount = 1 then begin
                        SkuProfileKey := BuildGroupKey('SKU', LocationCode, SingleSkuNo);
                        if SingleSkuCounts.Get(SkuProfileKey, ExistingSkuOrderCount) then
                            SingleSkuCounts.Set(SkuProfileKey, ExistingSkuOrderCount + 1)
                        else
                            SingleSkuCounts.Add(SkuProfileKey, 1);
                    end;
                end;
            until SalesHeader.Next() = 0;

        // İkinci geçiş: her siparişi uygun otomatik gruba ekle. Grup anahtarı
        // lokasyonu da içerir; farklı depolar aynı pick'e karışmaz.
        if SalesHeader.FindSet() then
            repeat
                if IsOrderAvailableForAutoGrouping(SalesHeader."No.") then begin
                    GetOrderProfile(SalesHeader, LocationCode, ItemLineCount, SingleSkuNo);
                    if ItemLineCount > 1 then begin
                        FlowMode := FlowMode::Multi;
                        GroupKey := BuildGroupKey('MULTI', LocationCode, '');
                    end else begin
                        SkuProfileKey := BuildGroupKey('SKU', LocationCode, SingleSkuNo);
                        SingleSkuCounts.Get(SkuProfileKey, ExistingSkuOrderCount);
                        if ExistingSkuOrderCount > 1 then begin
                            FlowMode := FlowMode::Bulk;
                            GroupKey := BuildGroupKey('BULK', LocationCode, SingleSkuNo);
                        end else begin
                            FlowMode := FlowMode::Batch;
                            GroupKey := BuildGroupKey('BATCH', LocationCode, '');
                        end;
                    end;

                    IsNewGroup := not HeaderEntryNos.ContainsKey(GroupKey);
                    GetOrCreateAutoHeader(
                        GroupKey, FlowMode, LocationCode, SingleSkuNo,
                        HeaderEntryNos, PickingHeader);
                    if IsNewGroup then
                        case FlowMode of
                            FlowMode::Multi:
                                MultiGroupCount += 1;
                            FlowMode::Batch:
                                MonoGroupCount += 1;
                            FlowMode::Bulk:
                                SingleSkuGroupCount += 1;
                        end;

                    AddOrder(PickingHeader, SalesHeader);
                    OrderCount += 1;
                end else
                    SkippedOrderCount += 1;
            until SalesHeader.Next() = 0;
    end;

    local procedure IsOrderAvailableForAutoGrouping(SalesOrderNo: Code[20]): Boolean
    begin
        exit(
            (not SalesOrderHasOpenPick(SalesOrderNo)) and
            (not SalesOrderHasActivePickingGroup(SalesOrderNo)));
    end;

    local procedure GetOrderProfile(var SalesHeader: Record "Sales Header"; var LocationCode: Code[10]; var ItemLineCount: Integer; var SingleSkuNo: Text)
    var
        SalesLine: Record "Sales Line";
        SkuKey: Text;
        FirstLocationRead: Boolean;
    begin
        Clear(LocationCode);
        Clear(ItemLineCount);
        Clear(SingleSkuNo);

        SalesHeader.TestField("Document Type", SalesHeader."Document Type"::Order);
        if SalesOrderHasOpenPick(SalesHeader."No.") then
            Error('Satış siparişi %1 için zaten açık veya kaydedilmiş bir toplama var.', SalesHeader."No.");

        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetFilter("Outstanding Quantity", '>0');
        SalesLine.SetFilter("No.", '<>%1', '');
        SalesLine.SetLoadFields("No.", "Variant Code", "Location Code");
        if SalesLine.FindSet() then
            repeat
                ItemLineCount += 1;
                if not FirstLocationRead then begin
                    LocationCode := SalesLine."Location Code";
                    FirstLocationRead := true;
                end else
                    if SalesLine."Location Code" <> LocationCode then
                        Error(
                            'Satış siparişi %1 birden fazla lokasyon içeriyor. Otomatik ayırma için sipariş satırları tek lokasyonda olmalıdır.',
                            SalesHeader."No.");

                SkuKey := SalesLine."No.";
                if SalesLine."Variant Code" <> '' then
                    SkuKey += '/' + SalesLine."Variant Code";
                if ItemLineCount = 1 then
                    SingleSkuNo := SkuKey;
            until SalesLine.Next() = 0;

        if ItemLineCount = 0 then
            Error('Satış siparişi %1 için bekleyen ürün satırı bulunamadı.', SalesHeader."No.");
        if LocationCode = '' then
            Error('Satış siparişi %1 için lokasyon belirtilmemiş. Otomatik ayırmadan önce sipariş satırlarına lokasyon girin.', SalesHeader."No.");
        if ItemLineCount <> 1 then
            Clear(SingleSkuNo);
    end;

    local procedure GetOrCreateAutoHeader(GroupKey: Text; FlowMode: Enum "DOPSWHS Pick Mode"; LocationCode: Code[10]; SingleSkuNo: Text; var HeaderEntryNos: Dictionary of [Text, Integer]; var PickingHeader: Record "DOPSWHS Picking Order Header")
    var
        HeaderEntryNo: Integer;
        DescriptionText: Text;
    begin
        if HeaderEntryNos.Get(GroupKey, HeaderEntryNo) then begin
            PickingHeader.Get(HeaderEntryNo);
            exit;
        end;

        case FlowMode of
            FlowMode::Multi:
                DescriptionText := 'Otomatik Multi';
            FlowMode::Batch:
                DescriptionText := 'Otomatik Mono';
            FlowMode::Bulk:
                DescriptionText := StrSubstNo('Otomatik Tek SKU - %1', SingleSkuNo);
        end;
        if LocationCode <> '' then
            DescriptionText += StrSubstNo(' - %1', LocationCode);

        // Init(), AutoIncrement olan birincil anahtarı temizlemez. Bu değişken
        // daha önce oluşturulan/okunan grubu taşıyorsa aynı Entry No. ile ikinci
        // Insert denenir. Clear ile PK dahil kayıt durumunu tamamen sıfırla.
        Clear(PickingHeader);
        PickingHeader.Init();
        PickingHeader."Entry No." := 0;
        PickingHeader.Description := CopyStr(DescriptionText, 1, MaxStrLen(PickingHeader.Description));
        PickingHeader."Location Code" := LocationCode;
        PickingHeader."Order Flow Mode" := FlowMode;
        PickingHeader.Insert(true);
        HeaderEntryNos.Add(GroupKey, PickingHeader."Entry No.");
    end;

    local procedure BuildGroupKey(Prefix: Text; LocationCode: Code[10]; ItemNo: Text): Text
    begin
        // ASCII birim ayıracına gerek yok; Code alanlarında '|' normalde
        // kullanılmadığı için okunabilir ve deterministik bir anahtar yeterli.
        exit(Prefix + '|' + LocationCode + '|' + ItemNo);
    end;

    procedure AddOrder(var PickingHeader: Record "DOPSWHS Picking Order Header"; SalesHeader: Record "Sales Header")
    var
        PickingLine: Record "DOPSWHS Picking Order Line";
        OtherLine: Record "DOPSWHS Picking Order Line";
        OtherHeader: Record "DOPSWHS Picking Order Header";
        SalesLine: Record "Sales Line";
        LocationCode: Code[10];
        LineCount: Integer;
        NextLineNo: Integer;
        TotalQty: Decimal;
    begin
        PickingHeader.TestField(Status, PickingHeader.Status::Open);
        SalesHeader.TestField("Document Type", SalesHeader."Document Type"::Order);

        // ELOG: zaten pick'i olan (açık veya toplanmış) sipariş yeniden gruba eklenmez.
        if SalesOrderHasOpenPick(SalesHeader."No.") then
            Error('Sales order %1 already has a warehouse pick (open or completed).', SalesHeader."No.");

        PickingLine.SetRange("Header Entry No.", PickingHeader."Entry No.");
        PickingLine.SetRange("Sales Order No.", SalesHeader."No.");
        if not PickingLine.IsEmpty() then
            exit;

        OtherLine.SetRange("Sales Order No.", SalesHeader."No.");
        if OtherLine.FindSet() then
            repeat
                if (OtherLine."Header Entry No." <> PickingHeader."Entry No.") and
                   OtherHeader.Get(OtherLine."Header Entry No.") and
                   (OtherHeader.Status <> OtherHeader.Status::Completed)
                then
                    Error('Sales order %1 is already in picking order %2.', SalesHeader."No.", OtherHeader."Entry No.");
            until OtherLine.Next() = 0;

        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetFilter("Outstanding Quantity", '>0');
        if SalesLine.FindSet() then
            repeat
                if LocationCode = '' then
                    LocationCode := SalesLine."Location Code";
                if SalesLine."Location Code" <> LocationCode then
                    Error('Sales order %1 contains more than one location.', SalesHeader."No.");
                LineCount += 1;
                TotalQty += SalesLine."Outstanding Quantity";
            until SalesLine.Next() = 0;
        if LineCount = 0 then
            Error('Sales order %1 has no outstanding item lines.', SalesHeader."No.");

        if PickingHeader."Location Code" = '' then begin
            PickingHeader.Validate("Location Code", LocationCode);
            PickingHeader.Modify(true);
        end else
            if PickingHeader."Location Code" <> LocationCode then
                Error('Sales order %1 belongs to location %2. This picking order uses %3.', SalesHeader."No.", LocationCode, PickingHeader."Location Code");

        PickingLine.Reset();
        PickingLine.SetRange("Header Entry No.", PickingHeader."Entry No.");
        if PickingLine.FindLast() then
            NextLineNo := PickingLine."Line No." + 10000
        else
            NextLineNo := 10000;
        PickingLine.Init();
        PickingLine."Header Entry No." := PickingHeader."Entry No.";
        PickingLine."Line No." := NextLineNo;
        PickingLine."Sales Order No." := SalesHeader."No.";
        PickingLine."Sell-to Customer No." := SalesHeader."Sell-to Customer No.";
        PickingLine."Sell-to Customer Name" := SalesHeader."Sell-to Customer Name";
        PickingLine."Location Code" := LocationCode;
        PickingLine."Shipment Date" := SalesHeader."Shipment Date";
        PickingLine."Item Line Count" := LineCount;
        PickingLine."Total Quantity" := TotalQty;
        PickingLine.Insert(true);
    end;

    // Bir satış siparişinin depo toplama (pick) durumunu döndürür.
    // 0 = Pick Yok (hiç açık warehouse pick yok, register da edilmemiş),
    // 1 = Pick Açık (register edilmemiş pick satırı mevcut),
    // 2 = Toplandı (pick register edilmiş — Registered Whse. Activity Line var).
    // NOT: Register edilince açık Warehouse Activity Line silinir; tamamlanma
    // ancak Registered Whse. Activity Line'dan anlaşılır.
    // ELOG: "Toplanacak Siparişler" ekranında sipariş satırında gösterilir.
    procedure GetSalesOrderPickStatus(SalesOrderNo: Code[20]): Integer
    var
        WhseActivityLine: Record "Warehouse Activity Line";
        RegisteredLine: Record "Registered Whse. Activity Line";
    begin
        if SalesOrderNo = '' then
            exit(0);

        // Açık (register edilmemiş) pick satırları Warehouse Activity Line'da durur.
        WhseActivityLine.SetRange("Activity Type", WhseActivityLine."Activity Type"::Pick);
        WhseActivityLine.SetRange("Source Type", Database::"Sales Line");
        WhseActivityLine.SetRange("Source Subtype", 1); // Sales Order
        WhseActivityLine.SetRange("Source No.", SalesOrderNo);
        if not WhseActivityLine.IsEmpty() then
            exit(1);

        // Açık pick yok — register edilmiş mi diye Registered satırlara bak.
        RegisteredLine.SetRange("Activity Type", RegisteredLine."Activity Type"::Pick);
        RegisteredLine.SetRange("Source Type", Database::"Sales Line");
        RegisteredLine.SetRange("Source Subtype", 1);
        RegisteredLine.SetRange("Source No.", SalesOrderNo);
        if not RegisteredLine.IsEmpty() then
            exit(2);

        exit(0);
    end;

    // Satış siparişinin zaten bir warehouse pick'i var mı (açık VEYA register edilmiş)?
    // "Satış Siparişlerini Seç" listesini filtrelemek için kullanılır
    // (Released + pick yok yalnızca gerçekten toplanmayı bekleyenler).
    procedure SalesOrderHasOpenPick(SalesOrderNo: Code[20]): Boolean
    begin
        exit(GetSalesOrderPickStatus(SalesOrderNo) <> 0);
    end;

    /// <summary>
    /// Sipariş henüz warehouse pick'e dönüşmemiş olsa bile açık bir
    /// DOPSWHS toplama grubundaysa yeniden seçilemez.
    /// </summary>
    procedure SalesOrderHasActivePickingGroup(SalesOrderNo: Code[20]): Boolean
    var
        PickingLine: Record "DOPSWHS Picking Order Line";
        PickingHeader: Record "DOPSWHS Picking Order Header";
    begin
        if SalesOrderNo = '' then
            exit(false);

        PickingLine.SetRange("Sales Order No.", SalesOrderNo);
        PickingLine.SetLoadFields("Header Entry No.");
        if PickingLine.FindSet() then
            repeat
                if PickingHeader.Get(PickingLine."Header Entry No.") then
                    if PickingHeader.Status <> PickingHeader.Status::Completed then
                        exit(true);
            until PickingLine.Next() = 0;
        exit(false);
    end;

    // Sales Header kümesini yalnızca "toplanabilir" siparişlere daraltır:
    // pick'i (açık VEYA register edilmiş) olan siparişler hariç tutulur.
    // ÖLÇEKLENEBİLİRLİK: 5000+ satış siparişini tek tek dolaşmak yerine, PICK
    // SATIRLARINI (sayıca az) tarayıp pick'i olan sipariş No.'larını toplarız,
    // sonra tek <>...& filtresiyle eleriz. AddOrder guard'ı yine son savunma.
    procedure FilterToPickable(var SalesHeader: Record "Sales Header")
    var
        WhseActivityLine: Record "Warehouse Activity Line";
        RegisteredLine: Record "Registered Whse. Activity Line";
        PickingLine: Record "DOPSWHS Picking Order Line";
        PickingHeader: Record "DOPSWHS Picking Order Header";
        PickedOrders: Dictionary of [Code[20], Boolean];
        ExcludeFilter: Text;
        OrderNo: Code[20];
    begin
        // Açık pick satırları.
        WhseActivityLine.SetRange("Activity Type", WhseActivityLine."Activity Type"::Pick);
        WhseActivityLine.SetRange("Source Type", Database::"Sales Line");
        WhseActivityLine.SetRange("Source Subtype", 1);
        WhseActivityLine.SetLoadFields("Source No.");
        if WhseActivityLine.FindSet() then
            repeat
                if not PickedOrders.ContainsKey(WhseActivityLine."Source No.") then
                    PickedOrders.Add(WhseActivityLine."Source No.", true);
            until WhseActivityLine.Next() = 0;

        // Register edilmiş pick satırları.
        RegisteredLine.SetRange("Activity Type", RegisteredLine."Activity Type"::Pick);
        RegisteredLine.SetRange("Source Type", Database::"Sales Line");
        RegisteredLine.SetRange("Source Subtype", 1);
        RegisteredLine.SetLoadFields("Source No.");
        if RegisteredLine.FindSet() then
            repeat
                if not PickedOrders.ContainsKey(RegisteredLine."Source No.") then
                    PickedOrders.Add(RegisteredLine."Source No.", true);
            until RegisteredLine.Next() = 0;

        // Warehouse pick henüz oluşturulmamış olsa da açık bir toplama
        // grubuna eklenmiş sipariş tekrar seçilmemelidir. HB.0001315 gibi
        // kayıtların ikinci bir otomatik gruba alınmasını burada engelleriz.
        PickingLine.SetLoadFields("Sales Order No.", "Header Entry No.");
        if PickingLine.FindSet() then
            repeat
                if PickingHeader.Get(PickingLine."Header Entry No.") then
                    if PickingHeader.Status <> PickingHeader.Status::Completed then
                        if not PickedOrders.ContainsKey(PickingLine."Sales Order No.") then
                            PickedOrders.Add(PickingLine."Sales Order No.", true);
            until PickingLine.Next() = 0;

        foreach OrderNo in PickedOrders.Keys() do begin
            if ExcludeFilter <> '' then
                ExcludeFilter += '&';
            ExcludeFilter += '<>' + OrderNo;
            // BC filtre metni sınırı (~2048). Aşarsa dur; AddOrder guard'ı kalanı yakalar.
            if StrLen(ExcludeFilter) > 1900 then
                break;
        end;

        if ExcludeFilter <> '' then
            SalesHeader.SetFilter("No.", ExcludeFilter);
    end;

    // Sales Header kümesini yalnız OPS Status = 'Pending' siparişlere daraltır.
    // "OPS Status" başka bir eklentinin alanı (field 60000, Option); derleme-zamanı
    // bağımlılığı olmasın diye RecordRef/FieldRef ile ID üzerinden erişilir ve
    // 'Pending' option üyesinin ordinal'i OptionMembers'tan çözülür. Alan yoksa
    // (o eklenti kurulu değilse) filtre atlanır — hata verilmez.
    procedure ApplyOpsPendingFilter(var SalesHeader: Record "Sales Header")
    var
        RecRef: RecordRef;
        FldRef: FieldRef;
        Members: Text;
        Ordinal: Integer;
        OpsStatusFieldNo: Integer;
    begin
        OpsStatusFieldNo := 60000;
        RecRef.GetTable(SalesHeader);
        if not RecRef.FieldExist(OpsStatusFieldNo) then
            exit;

        FldRef := RecRef.Field(OpsStatusFieldNo);
        if FldRef.Type <> FieldType::Option then
            exit;

        Members := FldRef.OptionMembers();
        Ordinal := OptionOrdinal(Members, 'Pending');
        if Ordinal < 0 then
            exit; // 'Pending' üyesi bulunamadı — filtreleme yapma (güvenli taraf).

        FldRef.SetRange(Ordinal);
        RecRef.SetTable(SalesHeader);
    end;

    // Virgülle ayrılmış OptionMembers içinde verilen üyenin sıra numarasını (0-based)
    // döndürür; yoksa -1. Boş üyeler de sayılır (BC ordinal davranışı).
    local procedure OptionOrdinal(Members: Text; Target: Text): Integer
    var
        Part: Text;
        Idx: Integer;
        Remaining: Text;
        CommaPos: Integer;
    begin
        Remaining := Members;
        Idx := 0;
        while StrLen(Remaining) >= 0 do begin
            CommaPos := StrPos(Remaining, ',');
            if CommaPos = 0 then begin
                Part := Remaining;
                if Part.Trim() = Target then
                    exit(Idx);
                exit(-1);
            end;
            Part := CopyStr(Remaining, 1, CommaPos - 1);
            if Part.Trim() = Target then
                exit(Idx);
            Remaining := CopyStr(Remaining, CommaPos + 1);
            Idx += 1;
        end;
        exit(-1);
    end;

    procedure PostPickingOrder(var PickingHeader: Record "DOPSWHS Picking Order Header"): Code[20]
    var
        LockedHeader: Record "DOPSWHS Picking Order Header";
        PickingLine: Record "DOPSWHS Picking Order Line";
        MultiOrderPick: Codeunit "DOPSWHS Multi Order Pick";
        OrderNosCsv: Text;
        ShipmentNo: Code[20];
        PickNo: Code[20];
    begin
        // Aynı grubun iki terminal/oturum tarafından paralel post edilmesini
        // engelle; sunucu tamamlayıp istemci timeout alırsa mevcut pick'i dön.
        LockedHeader.LockTable();
        if not LockedHeader.Get(PickingHeader."Entry No.") then
            Error('Picking order %1 no longer exists.', PickingHeader."Entry No.");
        if LockedHeader."Warehouse Pick No." <> '' then begin
            PickingHeader := LockedHeader;
            exit(LockedHeader."Warehouse Pick No.");
        end;

        LockedHeader.TestField(Status, LockedHeader.Status::Open);
        LockedHeader.TestField("Location Code");
        if LockedHeader."Assigned User ID" = '' then
            Error('Pick oluşturmadan önce "Toplayıcı Ata" ile bir operatör seçin. Atamasız pick oluşturulamaz.');

        PickingLine.SetRange("Header Entry No.", LockedHeader."Entry No.");
        if PickingLine.FindSet() then
            repeat
                if OrderNosCsv <> '' then
                    OrderNosCsv += ',';
                OrderNosCsv += PickingLine."Sales Order No.";
            until PickingLine.Next() = 0;
        if OrderNosCsv = '' then
            Error('Select at least one sales order.');

        PickNo := MultiOrderPick.CreateGroupedPick(
            OrderNosCsv,
            LockedHeader."Assigned User ID",
            ShipmentNo,
            PickModeToText(LockedHeader."Order Flow Mode"));
        LockedHeader."Warehouse Pick No." := PickNo;
        LockedHeader."Warehouse Shipment No." := ShipmentNo;
        LockedHeader.Status := LockedHeader.Status::"Pick Created";
        LockedHeader.Modify(true);
        PickingHeader := LockedHeader;
        exit(PickNo);
    end;

    local procedure PickModeToText(PickMode: Enum "DOPSWHS Pick Mode"): Text
    begin
        case PickMode of
            PickMode::Bulk:
                exit('bulk');
            PickMode::Batch:
                exit('batch');
            else
                exit('multi');
        end;
    end;

    // ------------------------------------------------------------------
    // ÖNERİ MOTORU
    // Depo sorumlusu "Öner" deyince: gruptaki siparişlerle BENZER ÜRÜNLERİ olan
    // ve SEVK TARİHİ YAKIN olan toplanabilir siparişleri puanlayıp döndürür.
    // Amaç: aynı raflardan toplanacak siparişleri tek pick'te birleştirmek —
    // toplayıcının yürüme yolu kısalır.
    //
    // Puanlama (ortak ürün baskın):
    //   ortak ürün    : +50 / ürün, 2+ ortak ürüne ayrıca +25
    //                   (tek ortak ürün bile en iyi tarih uyumunu geçer)
    //   tarih yakınlığı: aynı gün +30, 1 gün +20, 2-3 gün +10, 4-7 gün +5
    //   aynı müşteri  : +15 (tek sevkiyatta birleşebilir)
    //   küçük sipariş : +5  (3 satır veya altı — gruba ucuz eklenir)
    // Liste kırpılırken de ortak ürünü olmayanlar önce elenir.
    // Grup boşsa ürün/tarih karşılaştırması yapılamaz; bu durumda en erken
    // sevk tarihli toplanabilir siparişler önerilir (işe buradan başlanır).
    // ------------------------------------------------------------------
    procedure BuildSuggestions(var PickingHeader: Record "DOPSWHS Picking Order Header"; var TempSugg: Record "DOPSWHS Picking Order Sugg." temporary; MaxDateGapDays: Integer; MaxSuggestions: Integer)
    var
        SalesHeader: Record "Sales Header";
        GroupItems: Dictionary of [Code[20], Boolean];
        GroupCustomers: Dictionary of [Code[20], Boolean];
        EarliestShipment: Date;
        GroupLocation: Code[10];
        HasGroupLines: Boolean;
        Considered: Integer;
    begin
        TempSugg.Reset();
        TempSugg.DeleteAll();
        if MaxDateGapDays <= 0 then
            MaxDateGapDays := 7;
        if MaxSuggestions <= 0 then
            MaxSuggestions := 25;

        HasGroupLines := CollectGroupProfile(PickingHeader, GroupItems, GroupCustomers, EarliestShipment, GroupLocation);

        // Aday havuzu: toplanabilir (OPS Pending + açık pick'i olmayan) siparişler.
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        if GroupLocation <> '' then
            SalesHeader.SetRange("Location Code", GroupLocation);
        ApplyOpsPendingFilter(SalesHeader);
        FilterToPickable(SalesHeader);

        // SEVK TARİHİNE GÖRE SIRALA. Aday taraması 500 ile sınırlı; sırasız
        // taramada rastgele (çok ileri tarihli) siparişler öne geçiyordu.
        // En erken sevk tarihliler önce değerlendirilir.
        SalesHeader.SetCurrentKey("Document Type", "Shipment Date");
        SalesHeader.SetAscending("Shipment Date", true);

        if SalesHeader.FindSet() then
            repeat
                // Zaten bu gruptaysa aday değil.
                if not OrderAlreadyInGroup(PickingHeader."Entry No.", SalesHeader."No.") then begin
                    Considered += 1;
                    // Çok büyük şirketlerde tüm siparişleri puanlamak pahalı;
                    // makul bir tavanla sınırla (en erken tarihliler önce gelir).
                    if Considered <= 500 then
                        EvaluateCandidate(
                            SalesHeader, TempSugg, GroupItems, GroupCustomers,
                            EarliestShipment, HasGroupLines, MaxDateGapDays);
                end;
            until (SalesHeader.Next() = 0) or (Considered > 500);

        // ORTAK ÜRÜNÜ OLANLARA ÖNCELİK: liste MaxSuggestions'a indirilirken
        // ortak ürünü olmayanlar önce elenir (grup doluyken). Böylece "aynı
        // raflardan toplanır" adayları listede kalır.
        TrimSuggestions(TempSugg, MaxSuggestions, HasGroupLines);
    end;

    /// <summary>Gruptaki siparişlerin ürün/müşteri/tarih profilini çıkarır.</summary>
    local procedure CollectGroupProfile(var PickingHeader: Record "DOPSWHS Picking Order Header"; var GroupItems: Dictionary of [Code[20], Boolean]; var GroupCustomers: Dictionary of [Code[20], Boolean]; var EarliestShipment: Date; var GroupLocation: Code[10]): Boolean
    var
        PickingLine: Record "DOPSWHS Picking Order Line";
        SalesLine: Record "Sales Line";
        Found: Boolean;
    begin
        GroupLocation := PickingHeader."Location Code";
        EarliestShipment := 0D;
        PickingLine.SetRange("Header Entry No.", PickingHeader."Entry No.");
        if PickingLine.FindSet() then
            repeat
                Found := true;
                if PickingLine."Sell-to Customer No." <> '' then
                    if not GroupCustomers.ContainsKey(PickingLine."Sell-to Customer No.") then
                        GroupCustomers.Add(PickingLine."Sell-to Customer No.", true);
                if PickingLine."Shipment Date" <> 0D then
                    if (EarliestShipment = 0D) or (PickingLine."Shipment Date" < EarliestShipment) then
                        EarliestShipment := PickingLine."Shipment Date";
                if (GroupLocation = '') and (PickingLine."Location Code" <> '') then
                    GroupLocation := PickingLine."Location Code";

                // Gruptaki siparişin ürünleri — ortak ürün sayımı buna göre yapılır.
                SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
                SalesLine.SetRange("Document No.", PickingLine."Sales Order No.");
                SalesLine.SetRange(Type, SalesLine.Type::Item);
                SalesLine.SetFilter("No.", '<>%1', '');
                SalesLine.SetLoadFields("No.");
                if SalesLine.FindSet() then
                    repeat
                        if not GroupItems.ContainsKey(SalesLine."No.") then
                            GroupItems.Add(SalesLine."No.", true);
                    until SalesLine.Next() = 0;
            until PickingLine.Next() = 0;
        exit(Found);
    end;

    local procedure OrderAlreadyInGroup(HeaderEntryNo: Integer; SalesOrderNo: Code[20]): Boolean
    var
        PickingLine: Record "DOPSWHS Picking Order Line";
    begin
        PickingLine.SetRange("Header Entry No.", HeaderEntryNo);
        PickingLine.SetRange("Sales Order No.", SalesOrderNo);
        exit(not PickingLine.IsEmpty());
    end;

    /// <summary>Tek bir adayı puanlar; eşik üstündeyse öneri listesine ekler.</summary>
    local procedure EvaluateCandidate(var SalesHeader: Record "Sales Header"; var TempSugg: Record "DOPSWHS Picking Order Sugg." temporary; var GroupItems: Dictionary of [Code[20], Boolean]; var GroupCustomers: Dictionary of [Code[20], Boolean]; EarliestShipment: Date; HasGroupLines: Boolean; MaxDateGapDays: Integer)
    var
        SalesLine: Record "Sales Line";
        SharedItems: Integer;
        LineCount: Integer;
        TotalQty: Decimal;
        DateGap: Integer;
        Score: Integer;
        SameCustomer: Boolean;
        Reason: Text;
    begin
        // Aday siparişin ürünleri: ortak ürün sayısı + satır/miktar özeti.
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetFilter("No.", '<>%1', '');
        SalesLine.SetLoadFields("No.", Quantity);
        if SalesLine.FindSet() then
            repeat
                LineCount += 1;
                TotalQty += SalesLine.Quantity;
                if GroupItems.ContainsKey(SalesLine."No.") then
                    SharedItems += 1;
            until SalesLine.Next() = 0;
        if LineCount = 0 then
            exit;

        // Sevk tarihi yakınlığı (grup boşsa bugüne göre).
        DateGap := 0;
        if SalesHeader."Shipment Date" <> 0D then
            if EarliestShipment <> 0D then
                DateGap := Abs(SalesHeader."Shipment Date" - EarliestShipment)
            else
                DateGap := Abs(SalesHeader."Shipment Date" - Today());

        SameCustomer := GroupCustomers.ContainsKey(SalesHeader."Sell-to Customer No.");

        // --- Puan ---
        // ORTAK ÜRÜN EN AĞIR KRİTER: aynı raflardan toplanacağı için asıl
        // kazancı o sağlar. Tek bir ortak ürün (+50) bile en iyi tarih
        // uyumunu (+30) geçer; ortak ürünlü aday hep üstte kalır.
        Score := SharedItems * 50;
        // Birden çok ortak ürün ek prim alır (2 ortak ürün = aynı rafta iki iş).
        if SharedItems >= 2 then
            Score += 25;
        case true of
            DateGap = 0:
                Score += 30;
            DateGap = 1:
                Score += 20;
            DateGap <= 3:
                Score += 10;
            DateGap <= 7:
                Score += 5;
        end;
        if SameCustomer then
            Score += 15;
        if LineCount <= 3 then
            Score += 5;

        // Grup doluyken alakasız siparişleri önerme: ortak ürün de yok,
        // tarih de uzaksa listeye alma (sorumlu boş öneriyle uğraşmasın).
        if HasGroupLines and (SharedItems = 0) and (DateGap > MaxDateGapDays) then
            exit;

        Reason := BuildReason(SharedItems, DateGap, SameCustomer, HasGroupLines);

        TempSugg.Init();
        TempSugg."Sales Order No." := SalesHeader."No.";
        TempSugg."Sell-to Customer No." := SalesHeader."Sell-to Customer No.";
        TempSugg."Sell-to Customer Name" := SalesHeader."Sell-to Customer Name";
        TempSugg."Location Code" := SalesHeader."Location Code";
        TempSugg."Shipment Date" := SalesHeader."Shipment Date";
        TempSugg."Item Line Count" := LineCount;
        TempSugg."Total Quantity" := TotalQty;
        TempSugg."Shared Item Count" := SharedItems;
        TempSugg."Date Gap Days" := DateGap;
        TempSugg."Same Customer" := SameCustomer;
        TempSugg.Score := Score;
        TempSugg.Reason := CopyStr(Reason, 1, MaxStrLen(TempSugg.Reason));
        TempSugg."Selected" := true;   // varsayılan işaretli — sorumlu istemediğini kaldırır
        if TempSugg.Insert() then;
    end;

    local procedure BuildReason(SharedItems: Integer; DateGap: Integer; SameCustomer: Boolean; HasGroupLines: Boolean): Text
    var
        Parts: Text;
    begin
        // Grup boşken kıyaslanacak ürün/tarih yok; sevk tarihi bilgisi ver.
        if not HasGroupLines then
            case true of
                DateGap = 0:
                    exit('Bugün sevk edilecek');
                DateGap = 1:
                    exit('Yarın sevk edilecek');
                DateGap <= 7:
                    exit(StrSubstNo('%1 gün içinde sevk', DateGap));
                else
                    exit(StrSubstNo('Sevke %1 gün var', DateGap));
            end;

        if SharedItems > 0 then
            Parts := StrSubstNo('%1 ortak ürün (aynı raflar)', SharedItems);

        case true of
            DateGap = 0:
                Parts := AppendPart(Parts, 'aynı gün sevk');
            DateGap = 1:
                Parts := AppendPart(Parts, '1 gün fark');
            DateGap > 1:
                Parts := AppendPart(Parts, StrSubstNo('%1 gün fark', DateGap));
        end;

        if SameCustomer then
            Parts := AppendPart(Parts, 'aynı müşteri');

        if Parts = '' then
            exit('Toplanabilir sipariş');
        exit(Parts);
    end;

    local procedure AppendPart(Existing: Text; NewPart: Text): Text
    begin
        if Existing = '' then
            exit(NewPart);
        exit(Existing + ' · ' + NewPart);
    end;

    /// <summary>
    /// Listeyi MaxSuggestions'a indirir. Grup doluysa ÖNCE ortak ürünü
    /// OLMAYANLAR elenir (ortak ürünlü adaylar aynı raflardan toplanacağı için
    /// asıl kazancı onlar sağlar); yer kalmazsa kalanlar puana göre elenir.
    /// </summary>
    local procedure TrimSuggestions(var TempSugg: Record "DOPSWHS Picking Order Sugg." temporary; MaxSuggestions: Integer; HasGroupLines: Boolean)
    var
        ToDelete: Integer;
    begin
        TempSugg.Reset();
        if TempSugg.Count() <= MaxSuggestions then
            exit;

        // 1) Grup doluyken: ortak ürünü olmayanları puanı düşükten başlayarak ele.
        if HasGroupLines then begin
            ToDelete := TempSugg.Count() - MaxSuggestions;
            TempSugg.SetCurrentKey(Score);
            TempSugg.SetRange("Shared Item Count", 0);
            ToDelete := DeleteLowestScored(TempSugg, ToDelete);
            TempSugg.SetRange("Shared Item Count");
        end;

        // 2) Hâlâ fazlaysa (ya da grup boşsa) puanı en düşükleri ele.
        TempSugg.Reset();
        ToDelete := TempSugg.Count() - MaxSuggestions;
        if ToDelete > 0 then begin
            TempSugg.SetCurrentKey(Score);
            DeleteLowestScored(TempSugg, ToDelete);
        end;
        TempSugg.Reset();
    end;

    /// <summary>
    /// Geçerli filtre/sıra altındaki ilk [Count] kaydı siler; silinemeyen
    /// (yani kalan) adet döner. Silinecekler önce toplanır: FindSet döngüsü
    /// içinde silmek imleç davranışını bozabiliyor.
    /// </summary>
    local procedure DeleteLowestScored(var TempSugg: Record "DOPSWHS Picking Order Sugg." temporary; Count: Integer): Integer
    var
        DeleteSugg: Record "DOPSWHS Picking Order Sugg." temporary;
        Remaining: Integer;
    begin
        Remaining := Count;
        if Remaining <= 0 then
            exit(0);
        if TempSugg.FindSet() then
            repeat
                DeleteSugg := TempSugg;
                if DeleteSugg.Insert() then;
                Remaining -= 1;
            until (Remaining = 0) or (TempSugg.Next() = 0);

        if DeleteSugg.FindSet() then
            repeat
                if TempSugg.Get(DeleteSugg."Sales Order No.") then
                    TempSugg.Delete();
            until DeleteSugg.Next() = 0;
        exit(Remaining);
    end;

    /// <summary>Öneri listesinde işaretlenenleri gruba ekler; eklenen sayıyı döndürür.</summary>
    procedure AddSuggestedOrders(var PickingHeader: Record "DOPSWHS Picking Order Header"; var TempSugg: Record "DOPSWHS Picking Order Sugg." temporary): Integer
    var
        SalesHeader: Record "Sales Header";
        Added: Integer;
    begin
        PickingHeader.TestField(Status, PickingHeader.Status::Open);
        TempSugg.Reset();
        TempSugg.SetRange("Selected", true);
        if TempSugg.FindSet() then
            repeat
                if SalesHeader.Get(SalesHeader."Document Type"::Order, TempSugg."Sales Order No.") then
                    // Aday listelendikten sonra başka biri pick oluşturmuş olabilir;
                    // AddOrder bu durumda Error verir tek siparişi atla, akış sürsün.
                    if TryAddOrder(PickingHeader, SalesHeader) then
                        Added += 1;
            until TempSugg.Next() = 0;
        TempSugg.Reset();
        exit(Added);
    end;

    [TryFunction]
    local procedure TryAddOrder(var PickingHeader: Record "DOPSWHS Picking Order Header"; var SalesHeader: Record "Sales Header")
    begin
        AddOrder(PickingHeader, SalesHeader);
    end;
}
