page 72356 "DOPSWHS Picking Order Card"
{
    // Tek bir toplama grubunun kartı. Aramada GÖRÜNMEZ (UsageCategory = None):
    // eskiden liste sayfasıyla AYNI adı ve UsageCategory=Tasks taşıyordu, bu
    // yüzden aramada iki "Toplanacak Siparişler" çıkıyor, kart seçilince tek
    // boş kayıt açılıyordu. Kart yalnızca listeden açılır.
    PageType = Card;
    Caption = 'Toplama Grubu';
    SourceTable = "DOPSWHS Picking Order Header";
    ApplicationArea = All;
    UsageCategory = None;
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'Genel';

                field(SummaryText; SummaryText)
                {
                    ApplicationArea = All;
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                    Style = Strong;
                    ToolTip = 'Bu gruptaki sipariş/ürün özeti ve sıradaki adım.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Caption = 'Açıklama';
                    Editable = Rec.Status = Rec.Status::Open;
                    ToolTip = 'Bu toplama grubunu tanımlayan kısa not (ör. "Sabah sevkiyatı").';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    Caption = 'Lokasyon';
                    Editable = Rec.Status = Rec.Status::Open;
                }
                field("Order Flow Mode"; Rec."Order Flow Mode")
                {
                    ApplicationArea = All;
                    Caption = 'Akış Tipi';
                    Editable = false;
                    ToolTip = 'Toplamanın V2 terminalde Multi, Mono veya Tek SKU olarak hangi akışla yürütüleceğini gösterir.';
                }
                field("Assigned User ID"; Rec."Assigned User ID")
                {
                    ApplicationArea = All;
                    Caption = 'Atanan Toplayıcı';
                    Editable = false;
                    ToolTip = 'Toplamayı üstlenen WMS operatörü. Pick oluşturmadan önce "Toplayıcı Ata" aksiyonuyla seçilmesi zorunludur.';
                }
                field(Status; Rec.Status) { ApplicationArea = All; Caption = 'Durum'; StyleExpr = StatusStyle; }
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; Caption = 'Kayıt No.'; Editable = false; }
            }
            group(Result)
            {
                Caption = 'Oluşan Belgeler';
                Visible = Rec."Warehouse Pick No." <> '';

                field("Warehouse Pick No."; Rec."Warehouse Pick No.")
                {
                    ApplicationArea = All;
                    Caption = 'Toplama Belgesi';
                    ToolTip = 'Bu gruptan oluşturulan warehouse pick. Terminalde toplayıcıya bu numarayla görünür.';
                }
                field("Warehouse Shipment No."; Rec."Warehouse Shipment No.")
                {
                    ApplicationArea = All;
                    Caption = 'Ambar Sevkiyatı';
                }
            }
            part(Lines; "DOPSWHS Picking Order Lines")
            {
                Caption = 'Gruptaki Siparişler';
                ApplicationArea = All;
                SubPageLink = "Header Entry No." = field("Entry No.");
                UpdatePropagation = Both;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SuggestOrders)
            {
                Caption = 'Öner';
                ApplicationArea = All;
                Image = Suggest;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Enabled = Rec.Status = Rec.Status::Open;
                ToolTip = 'Bu gruba uygun siparişleri önerir: gruptakilerle ORTAK ÜRÜNÜ olanlar (aynı raflardan toplanır) ve SEVK TARİHİ YAKIN olanlar öncelikli sıralanır. Öneriler onay penceresinde gösterilir; istemediğinizi çıkarıp ekleyebilirsiniz.';

                trigger OnAction()
                var
                    TempSugg: Record "DOPSWHS Picking Order Sugg." temporary;
                    TempChosen: Record "DOPSWHS Picking Order Sugg." temporary;
                    PickingOrderMgmt: Codeunit "DOPSWHS Picking Order Mgmt";
                    SuggPage: Page "DOPSWHS Picking Order Sugg.";
                    AddedCount: Integer;
                begin
                    Rec.TestField(Status, Rec.Status::Open);
                    PickingOrderMgmt.BuildSuggestions(Rec, TempSugg, 7, 25);
                    if TempSugg.IsEmpty() then begin
                        Message('Uygun öneri bulunamadı. "Satış Siparişlerini Seç" ile elle ekleyebilirsiniz.');
                        exit;
                    end;

                    SuggPage.LoadSuggestions(TempSugg);
                    SuggPage.LookupMode(true);
                    if SuggPage.RunModal() <> Action::LookupOK then
                        exit;

                    SuggPage.GetSelected(TempChosen);
                    if TempChosen.IsEmpty() then
                        exit;

                    AddedCount := PickingOrderMgmt.AddSuggestedOrders(Rec, TempChosen);
                    CurrPage.Update(false);
                    UpdateSummary();
                    Message('%1 sipariş gruba eklendi.', AddedCount);
                end;
            }
            action(SelectSalesOrders)
            {
                Caption = 'Satış Siparişlerini Seç';
                ApplicationArea = All;
                Image = SelectEntries;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = Rec.Status = Rec.Status::Open;

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                    SalesOrderList: Page "Sales Order List";
                    PickingOrderMgmt: Codeunit "DOPSWHS Picking Order Mgmt";
                begin
                    // ELOG "toplanacak siparişler": yalnızca OPS Status = Pending ve
                    // açık pick'i olmayan siparişler seçilebilir (BADE akışı Pending
                    // üzerinden yürür; Released şartı yok — çoğu sipariş Open).
                    // Refunded/Canceled/Returned OPS Status'leri ve zaten toplanmışlar gizlenir.
                    SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
                    PickingOrderMgmt.ApplyOpsPendingFilter(SalesHeader);
                    PickingOrderMgmt.FilterToPickable(SalesHeader);
                    SalesOrderList.SetTableView(SalesHeader);
                    SalesOrderList.LookupMode(true);
                    if SalesOrderList.RunModal() = Action::LookupOK then begin
                        SalesOrderList.SetSelectionFilter(SalesHeader);
                        PickingOrderMgmt.AddSelectedOrders(Rec, SalesHeader);
                        CurrPage.Update(false);
                        UpdateSummary();
                    end;
                end;
            }
            action(PostPick)
            {
                Caption = 'Pick Oluştur / Post Et';
                ApplicationArea = All;
                Image = CreateMovement;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Enabled = Rec.Status = Rec.Status::Open;
                ToolTip = 'Gruptaki siparişlerden warehouse pick oluşturur. İşlemi kullanmadan önce "Toplayıcı Ata" ile operatör seçilmesi zorunludur.';

                trigger OnAction()
                var
                    FreshHeader: Record "DOPSWHS Picking Order Header";
                    PickingOrderMgmt: Codeunit "DOPSWHS Picking Order Mgmt";
                    PickNo: Code[20];
                begin
                    // Eş zamanlılık: bu kart açıkken başka bir sorumlu aynı grup için
                    // pick oluşturmuş olabilir. PostPickingOrder durumu ekrandaki
                    // (stale) kayıttan okuyor; o yüzden veritabanından yeniden okuyup
                    // karar veriyoruz — aksi halde AYNI grup için ikinci bir pick
                    // oluşuyordu.
                    if not FreshHeader.Get(Rec."Entry No.") then
                        Error(GroupGoneErr, Rec."Entry No.");
                    if FreshHeader.Status <> FreshHeader.Status::Open then
                        Error(GroupAlreadyPostedErr, FreshHeader."Warehouse Pick No.");

                    // Atamasız pick oluşturulmaz; iş terminalde yalnızca seçilen
                    // operatörün "Bana atanan" listesine gitmelidir.
                    if FreshHeader."Assigned User ID" = '' then
                        Error(PickerRequiredErr);

                    PickNo := PickingOrderMgmt.PostPickingOrder(FreshHeader);
                    if Rec.Get(FreshHeader."Entry No.") then;
                    CurrPage.Update(false);
                    UpdateSummary();

                    Message(PickCreatedMsg, PickNo, FreshHeader."Assigned User ID");
                end;
            }
            action(AssignPicker)
            {
                Caption = 'Toplayıcı Ata';
                ApplicationArea = All;
                Image = UserSetup;
                Promoted = true;
                PromotedCategory = Category4;
                Enabled = Rec.Status <> Rec.Status::Completed;
                ToolTip = 'Bu grubu bir WMS operatörüne atar. Pick oluşturulmuşsa toplama belgesine de yazılır; operatör terminalde "bana atanan" listesinde görür. Atanmış bir toplamayı başka operatör terminalden üstüne alamaz — devir yalnızca buradan yapılır.';

                trigger OnAction()
                var
                    LocalUser: Record "DOPSWHS Local User";
                    PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
                    HeaderEntryNo: Integer;
                begin
                    LocalUser.SetRange(Disabled, false);
                    if Page.RunModal(Page::"DOPSWHS Local User List", LocalUser) <> Action::LookupOK then
                        exit;

                    // Grup başkasındaysa bu bir DEVİR'dir: sorumlu bilerek yapsın.
                    // (Yönetici zorla devredebilir; kural kontrolü terminal tarafında.)
                    if (Rec."Assigned User ID" <> '') and (Rec."Assigned User ID" <> LocalUser.Username) then
                        if not Confirm(TakeOverQst, false, PickMgmt.OperatorLabel(Rec."Assigned User ID"), LocalUser."Display Name") then
                            exit;

                    // Kilitli yeniden okuma + pick belgesine yansıtma PickMgmt'te.
                    HeaderEntryNo := Rec."Entry No.";
                    PickMgmt.SetPickingOrderPicker(Rec, LocalUser.Username, AssignedFromCardLbl);
                    if not Rec.Get(HeaderEntryNo) then
                        Error(GroupGoneErr, HeaderEntryNo);
                    if Rec."Assigned User ID" <> LocalUser.Username then
                        Error(AssignmentNotSavedErr, LocalUser.Username);

                    CurrPage.Update(false);
                    UpdateSummary();
                end;
            }
            action(OpenWarehousePick)
            {
                Caption = 'Toplama Belgesini Aç';
                ApplicationArea = All;
                Image = Open;
                Promoted = true;
                PromotedCategory = Category4;
                Enabled = Rec."Warehouse Pick No." <> '';
                ToolTip = 'Bu gruptan oluşan warehouse pick belgesini açar.';

                trigger OnAction()
                var
                    PickHeader: Record "Warehouse Activity Header";
                begin
                    if not PickHeader.Get(PickHeader.Type::Pick, Rec."Warehouse Pick No.") then
                        Error('Toplama %1 artık açık değil (kaydedilmiş olabilir).', Rec."Warehouse Pick No.");
                    Page.Run(Page::"Warehouse Pick", PickHeader);
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        UpdateSummary();
    end;

    trigger OnAfterGetRecord()
    begin
        UpdateSummary();
        case Rec.Status of
            Rec.Status::Open:
                StatusStyle := 'Attention';
            Rec.Status::"Pick Created":
                StatusStyle := 'Favorable';
            else
                StatusStyle := 'Standard';
        end;
    end;

    /// <summary>Başlıktaki özet: kaç sipariş, kaç satır, sıradaki adım ne.</summary>
    local procedure UpdateSummary()
    var
        PickingLine: Record "DOPSWHS Picking Order Line";
        OrderCount: Integer;
        LineCount: Integer;
        TotalQty: Decimal;
        EarliestDate: Date;
    begin
        PickingLine.SetRange("Header Entry No.", Rec."Entry No.");
        if PickingLine.FindSet() then
            repeat
                OrderCount += 1;
                LineCount += PickingLine."Item Line Count";
                TotalQty += PickingLine."Total Quantity";
                if PickingLine."Shipment Date" <> 0D then
                    if (EarliestDate = 0D) or (PickingLine."Shipment Date" < EarliestDate) then
                        EarliestDate := PickingLine."Shipment Date";
            until PickingLine.Next() = 0;

        if Rec."Warehouse Pick No." <> '' then begin
            SummaryText := StrSubstNo(
                '%1 sipariş · %2 ürün satırı · toplama %3 oluşturuldu',
                OrderCount, LineCount, Rec."Warehouse Pick No.");
            // Atama durumu özete taşındı: atanmamış bir toplamayı terminalde herkes
            // üstlenebiliyor; sorumlu bunu bir bakışta görsün.
            if Rec."Assigned User ID" = '' then
                SummaryText += ' — TOPLAYICI ATANMADI: terminalde ilk üstlenen alır. "Toplayıcı Ata" ile kime ait olacağını belirleyin.'
            else
                SummaryText += StrSubstNo(' — toplayıcı: %1.', Rec."Assigned User ID");
            exit;
        end;

        if OrderCount = 0 then begin
            SummaryText := 'Grup boş. "Öner" ile sistem uygun siparişleri sıralasın ya da "Satış Siparişlerini Seç" ile elle ekleyin.';
            exit;
        end;

        SummaryText := StrSubstNo('%1 sipariş · %2 ürün satırı · %3 adet', OrderCount, LineCount, TotalQty);
        if EarliestDate <> 0D then
            SummaryText += StrSubstNo(' · en erken sevk %1', Format(EarliestDate));
        if Rec."Assigned User ID" = '' then
            SummaryText += '. Önce "Toplayıcı Ata", sonra "Pick Oluştur / Post Et" deyin.'
        else
            SummaryText += StrSubstNo('. Toplayıcı %1. Hazırsanız "Pick Oluştur / Post Et" deyin.', Rec."Assigned User ID");
    end;

    var
        SummaryText: Text;
        StatusStyle: Text;
        PickerRequiredErr: Label 'Pick oluşturmadan önce "Toplayıcı Ata" ile bir operatör seçin.';
        TakeOverQst: Label 'Bu grup %1 kullanıcısında. %2 kullanıcısına devredilsin mi?', Comment = '%1 = mevcut operatör, %2 = yeni operatör';
        GroupGoneErr: Label 'Toplama grubu %1 bulunamadı — silinmiş olabilir. Listeyi yenileyin.', Comment = '%1 = Kayıt No.';
        GroupAlreadyPostedErr: Label 'Bu grup için toplama zaten oluşturulmuş (%1). Sayfayı yenileyin.', Comment = '%1 = Toplama belgesi no.';
        PickCreatedMsg: Label 'Toplama %1 oluşturuldu — terminalde %2 kullanıcısına görünüyor.', Comment = '%1 = Toplama no., %2 = operatör';
        AssignmentNotSavedErr: Label '%1 kullanıcısına yapılan atama kayda yazılamadı.', Comment = '%1 = operatör';
        AssignedFromCardLbl: Label 'Toplama grubu kartından atandı.';
}
