page 72357 "DOPSWHS Picking Order List"
{
    // Depo sorumlusunun "toplanacak siparişler" takip ekranı.
    // Terminalden "Üzerime Al" yapılınca atama buraya da yansır
    // (PickMgmt.SyncPickingOrderAssignment).
    PageType = List;
    Caption = 'Toplanacak Siparişler';
    SourceTable = "DOPSWHS Picking Order Header";
    CardPageId = "DOPSWHS Picking Order Card";
    ApplicationArea = All;
    UsageCategory = Tasks;
    Editable = false;
    InsertAllowed = false;
    SourceTableView = sorting("Entry No.") order(descending);

    layout
    {
        area(Content)
        {
            repeater(Headers)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    Caption = 'Kayıt No.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Caption = 'Açıklama';
                }
                field("Order Flow Mode"; Rec."Order Flow Mode")
                {
                    ApplicationArea = All;
                    Caption = 'Akış Tipi';
                    ToolTip = 'Sistemin sipariş içeriğine göre belirlediği Multi, Mono veya Tek SKU toplama akışı.';
                }
                field(OrderCountText; OrderCountText)
                {
                    ApplicationArea = All;
                    Caption = 'Sipariş';
                    ToolTip = 'Bu gruptaki satış siparişi sayısı ve toplam ürün satırı.';
                }
                field(StatusText; StatusText)
                {
                    ApplicationArea = All;
                    Caption = 'Durum';
                    StyleExpr = StatusStyle;
                    ToolTip = 'Açık: henüz pick oluşturulmadı. Pick Oluşturuldu: terminalde toplayıcıya görünüyor. Tamamlandı: toplama bitti.';
                }
                field("Assigned User ID"; Rec."Assigned User ID")
                {
                    ApplicationArea = All;
                    Caption = 'Toplayıcı';
                    StyleExpr = AssignedStyle;
                    ToolTip = 'Toplamayı üstlenen operatör. Terminalden "Üzerime Al" yapılınca burası otomatik dolar.';
                }
                field(ProgressText; ProgressText)
                {
                    ApplicationArea = All;
                    Caption = 'İlerleme';
                    StyleExpr = ProgressStyle;
                    ToolTip = 'Toplanan / toplam satır (pick oluşturulduysa).';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    Caption = 'Lokasyon';
                }
                field("Warehouse Pick No."; Rec."Warehouse Pick No.")
                {
                    ApplicationArea = All;
                    Caption = 'Toplama Belgesi';
                }
                field("Warehouse Shipment No."; Rec."Warehouse Shipment No.")
                {
                    ApplicationArea = All;
                    Caption = 'Ambar Sevkiyatı';
                    Visible = false;
                }
                field("Created DateTime"; Rec."Created DateTime")
                {
                    ApplicationArea = All;
                    Caption = 'Oluşturulma';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AutoSeparateOrders)
            {
                Caption = 'Siparişleri Seç ve Otomatik Grupla';
                ApplicationArea = All;
                Image = Suggest;
                Promoted = true;
                PromotedCategory = New;
                PromotedIsBig = true;
                ToolTip = 'Seçtiğiniz toplanabilir satış siparişlerini lokasyon ve ürün içeriğine göre Multi, Mono ve Tek SKU gruplarına otomatik ayırır.';

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                    SalesOrderList: Page "Sales Order List";
                    PickingOrderMgmt: Codeunit "DOPSWHS Picking Order Mgmt";
                    MultiGroupCount: Integer;
                    MonoGroupCount: Integer;
                    SingleSkuGroupCount: Integer;
                    OrderCount: Integer;
                    SkippedOrderCount: Integer;
                begin
                    SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
                    PickingOrderMgmt.ApplyOpsPendingFilter(SalesHeader);
                    PickingOrderMgmt.FilterToPickable(SalesHeader);
                    SalesOrderList.SetTableView(SalesHeader);
                    SalesOrderList.LookupMode(true);
                    if SalesOrderList.RunModal() <> Action::LookupOK then
                        exit;

                    SalesOrderList.SetSelectionFilter(SalesHeader);
                    PickingOrderMgmt.AutoCreatePickingGroups(
                        SalesHeader, MultiGroupCount, MonoGroupCount,
                        SingleSkuGroupCount, OrderCount, SkippedOrderCount);
                    Rec.SetRange(Status);
                    Rec.SetRange("Assigned User ID");
                    Rec.SetRange("Order Flow Mode");
                    CurrPage.Update(false);
                    if SkippedOrderCount > 0 then
                        Message(
                            '%1 sipariş otomatik ayrıldı. Oluşan gruplar: %2 Multi, %3 Mono, %4 Tek SKU. Zaten başka bir toplama grubunda veya pick''te bulunan %5 sipariş atlandı.',
                            OrderCount, MultiGroupCount, MonoGroupCount, SingleSkuGroupCount, SkippedOrderCount)
                    else
                        Message(
                            '%1 sipariş otomatik ayrıldı. Oluşan gruplar: %2 Multi, %3 Mono, %4 Tek SKU. Sıradaki adım: grubu açıp toplayıcı atayın ve pick oluşturun.',
                            OrderCount, MultiGroupCount, MonoGroupCount, SingleSkuGroupCount);
                end;
            }
            group(Filters)
            {
                Caption = 'Görünüm';
                Image = FilterLines;

                action(ShowOpen)
                {
                    ApplicationArea = All;
                    Caption = 'Bekleyenler';
                    Image = List;
                    Promoted = true;
                    PromotedCategory = Process;
                    ToolTip = 'Henüz pick oluşturulmamış grupları gösterir.';

                    trigger OnAction()
                    begin
                        Rec.SetRange(Status, Rec.Status::Open);
                        CurrPage.Update(false);
                    end;
                }
                action(ShowInPicking)
                {
                    ApplicationArea = All;
                    Caption = 'Toplanmakta';
                    Image = PickLines;
                    Promoted = true;
                    PromotedCategory = Process;
                    ToolTip = 'Pick oluşturulmuş, terminalde toplanmayı bekleyen ya da toplanan grupları gösterir.';

                    trigger OnAction()
                    begin
                        Rec.SetRange(Status, Rec.Status::"Pick Created");
                        CurrPage.Update(false);
                    end;
                }
                action(ShowUnassigned)
                {
                    ApplicationArea = All;
                    Caption = 'Atanmamışlar';
                    Image = UserSetup;
                    Promoted = true;
                    PromotedCategory = Process;
                    ToolTip = 'Henüz kimsenin üstlenmediği toplama gruplarını gösterir.';

                    trigger OnAction()
                    begin
                        Rec.SetRange("Assigned User ID", '');
                        Rec.SetFilter(Status, '<>%1', Rec.Status::Completed);
                        CurrPage.Update(false);
                    end;
                }
                action(ShowMulti)
                {
                    ApplicationArea = All;
                    Caption = 'Multi';
                    Image = FilterLines;
                    ToolTip = 'Yalnızca Multi toplama gruplarını gösterir.';

                    trigger OnAction()
                    begin
                        Rec.SetRange("Order Flow Mode", Rec."Order Flow Mode"::Multi);
                        CurrPage.Update(false);
                    end;
                }
                action(ShowMono)
                {
                    ApplicationArea = All;
                    Caption = 'Mono';
                    Image = FilterLines;
                    ToolTip = 'Yalnızca Mono toplama gruplarını gösterir.';

                    trigger OnAction()
                    begin
                        Rec.SetRange("Order Flow Mode", Rec."Order Flow Mode"::Batch);
                        CurrPage.Update(false);
                    end;
                }
                action(ShowSingleSku)
                {
                    ApplicationArea = All;
                    Caption = 'Tek SKU';
                    Image = FilterLines;
                    ToolTip = 'Yalnızca Tek SKU toplama gruplarını gösterir.';

                    trigger OnAction()
                    begin
                        Rec.SetRange("Order Flow Mode", Rec."Order Flow Mode"::Bulk);
                        CurrPage.Update(false);
                    end;
                }
                action(ShowAll)
                {
                    ApplicationArea = All;
                    Caption = 'Tümü';
                    Image = ShowList;
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    begin
                        Rec.SetRange(Status);
                        Rec.SetRange("Assigned User ID");
                        Rec.SetRange("Order Flow Mode");
                        CurrPage.Update(false);
                    end;
                }
            }
            group(Manage)
            {
                Caption = 'Yönet';

                action(CreatePick)
                {
                    ApplicationArea = All;
                    Caption = 'Pick Oluştur / Post Et';
                    Image = CreateMovement;
                    Promoted = true;
                    PromotedCategory = Category4;
                    PromotedIsBig = true;
                    Enabled = Rec.Status = Rec.Status::Open;
                    ToolTip = 'Seçili otomatik grubun ambar sevkiyatını ve toplama belgesini oluşturur; iş terminalde görünür.';

                    trigger OnAction()
                    var
                        FreshHeader: Record "DOPSWHS Picking Order Header";
                        PickingOrderMgmt: Codeunit "DOPSWHS Picking Order Mgmt";
                        PickNo: Code[20];
                    begin
                        if Rec."Entry No." = 0 then
                            exit;
                        if not FreshHeader.Get(Rec."Entry No.") then
                            Error(GroupGoneErr, Rec."Entry No.");
                        if FreshHeader.Status <> FreshHeader.Status::Open then
                            Error(GroupAlreadyPostedErr, FreshHeader."Warehouse Pick No.");
                        if FreshHeader."Assigned User ID" = '' then
                            Error(PickerRequiredErr);

                        PickNo := PickingOrderMgmt.PostPickingOrder(FreshHeader);
                        if Rec.Get(FreshHeader."Entry No.") then;
                        CurrPage.Update(false);
                        Message(PickCreatedMsg, PickNo, FreshHeader."Assigned User ID");
                    end;
                }

                action(PostSelectedGroups)
                {
                    ApplicationArea = All;
                    Caption = 'Seçili Grupları Terminale Gönder';
                    Image = SendTo;
                    Promoted = true;
                    PromotedCategory = Category4;
                    ToolTip = 'İşaretlenen Mono, Multi veya Tek SKU gruplarını kontrollü şekilde post eder. Sistem kendiliğinden post etmez.';

                    trigger OnAction()
                    var
                        SelectedHeader: Record "DOPSWHS Picking Order Header";
                        PickingOrderMgmt: Codeunit "DOPSWHS Picking Order Mgmt";
                        SelectedCount: Integer;
                        PostedCount: Integer;
                    begin
                        CurrPage.SetSelectionFilter(SelectedHeader);
                        SelectedCount := SelectedHeader.Count();
                        if SelectedCount = 0 then
                            Error(NoGroupsSelectedErr);

                        // Ön kontrolün tamamı post başlamadan yapılır; yarım toplu
                        // işlem yerine kullanıcıya eksik atama/grup açıkça gösterilir.
                        if SelectedHeader.FindSet() then
                            repeat
                                if SelectedHeader.Status <> SelectedHeader.Status::Open then
                                    Error(GroupNotOpenErr, SelectedHeader."Entry No.");
                                if SelectedHeader."Assigned User ID" = '' then
                                    Error(GroupPickerMissingErr, SelectedHeader."Entry No.");
                            until SelectedHeader.Next() = 0;

                        if not Confirm(PostSelectedGroupsQst, false, SelectedCount) then
                            exit;

                        if SelectedHeader.FindSet() then
                            repeat
                                PickingOrderMgmt.PostPickingOrder(SelectedHeader);
                                PostedCount += 1;
                            until SelectedHeader.Next() = 0;

                        CurrPage.Update(false);
                        Message(SelectedGroupsPostedMsg, PostedCount);
                    end;
                }

                action(AssignPicker)
                {
                    ApplicationArea = All;
                    Caption = 'Toplayıcı Ata';
                    Image = UserSetup;
                    Promoted = true;
                    PromotedCategory = Category4;
                    ToolTip = 'Seçili grubu bir WMS operatörüne atar. Pick oluşturulmuşsa toplama belgesine de yazılır; operatör terminalde görür.';

                    trigger OnAction()
                    var
                        LocalUser: Record "DOPSWHS Local User";
                        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
                        HeaderEntryNo: Integer;
                    begin
                        if Rec."Entry No." = 0 then
                            exit;
                        if Rec.Status = Rec.Status::Completed then
                            Error(CompletedNotAssignableErr);
                        LocalUser.SetRange(Disabled, false);
                        if Page.RunModal(Page::"DOPSWHS Local User List", LocalUser) <> Action::LookupOK then
                            exit;

                        // Grup başkasındaysa bu bir DEVİR'dir: yanlışlıkla iş elinden
                        // alınmasın diye sorumluya onaylatılır.
                        if (Rec."Assigned User ID" <> '') and (Rec."Assigned User ID" <> LocalUser.Username) then
                            if not Confirm(TakeOverQst, false, PickMgmt.OperatorLabel(Rec."Assigned User ID"), LocalUser."Display Name") then
                                exit;

                        // Kilitli yeniden okuma + pick belgesine yansıtma PickMgmt'te:
                        // eskiden ekrandaki (stale) kayıt doğrudan Modify ediliyordu,
                        // iki sorumlu aynı anda atarsa biri diğerini sessizce eziyordu.
                        HeaderEntryNo := Rec."Entry No.";
                        PickMgmt.SetPickingOrderPicker(Rec, LocalUser.Username, AssignedFromListLbl);
                        if not Rec.Get(HeaderEntryNo) then
                            Error(GroupGoneErr, HeaderEntryNo);
                        if Rec."Assigned User ID" <> LocalUser.Username then
                            Error(AssignmentNotSavedErr, LocalUser.Username);

                        CurrPage.Update(false);
                    end;
                }
                action(ClearPicker)
                {
                    ApplicationArea = All;
                    Caption = 'Atamayı Kaldır';
                    Image = UnApply;
                    ToolTip = 'Grubu atanmamış duruma döndürür; terminalde başka bir operatör üstlenebilir.';

                    trigger OnAction()
                    var
                        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
                    begin
                        if Rec."Entry No." = 0 then
                            exit;
                        if Rec.Status = Rec.Status::Completed then
                            Error(CompletedNotAssignableErr);
                        if Rec."Assigned User ID" = '' then
                            exit;
                        // Atama kaldırılınca belge terminalde tekrar herkese açılır;
                        // toplamaya başlamış operatörün işi yarıda kalabilir.
                        if not Confirm(ClearPickerQst, false, PickMgmt.OperatorLabel(Rec."Assigned User ID")) then
                            exit;
                        PickMgmt.SetPickingOrderPicker(Rec, '', ClearedFromListLbl);
                        CurrPage.Update(false);
                    end;
                }
            }
            group(Navigate)
            {
                Caption = 'İlgili';

                action(OpenPick)
                {
                    ApplicationArea = All;
                    Caption = 'Toplama Belgesini Aç';
                    Image = Open;
                    Promoted = true;
                    PromotedCategory = Category5;
                    Enabled = Rec."Warehouse Pick No." <> '';

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
    }

    trigger OnAfterGetRecord()
    var
        PickingLine: Record "DOPSWHS Picking Order Line";
        WhseActivityLine: Record "Warehouse Activity Line";
        OrderCount: Integer;
        ItemLines: Integer;
        TotalLines: Integer;
        DoneLines: Integer;
    begin
        case Rec.Status of
            Rec.Status::Open:
                begin
                    StatusText := 'Açık';
                    StatusStyle := 'Attention';
                end;
            Rec.Status::"Pick Created":
                begin
                    StatusText := 'Toplanmakta';
                    StatusStyle := 'Ambiguous';
                end;
            Rec.Status::Completed:
                begin
                    StatusText := 'Tamamlandı';
                    StatusStyle := 'Favorable';
                end;
            else begin
                StatusText := Format(Rec.Status);
                StatusStyle := 'Standard';
            end;
        end;

        // Atanmamış gruplar göze çarpsın.
        if Rec."Assigned User ID" = '' then
            AssignedStyle := 'Unfavorable'
        else
            AssignedStyle := 'Favorable';

        // Gruptaki sipariş / ürün satırı sayısı.
        PickingLine.SetRange("Header Entry No.", Rec."Entry No.");
        if PickingLine.FindSet() then
            repeat
                OrderCount += 1;
                ItemLines += PickingLine."Item Line Count";
            until PickingLine.Next() = 0;
        if OrderCount = 0 then
            OrderCountText := '—'
        else
            OrderCountText := StrSubstNo('%1 sipariş · %2 satır', OrderCount, ItemLines);

        // İlerleme: pick satırlarından toplanan / toplam.
        ProgressText := '';
        ProgressStyle := 'Standard';
        if Rec."Warehouse Pick No." <> '' then begin
            WhseActivityLine.SetRange("Activity Type", WhseActivityLine."Activity Type"::Pick);
            WhseActivityLine.SetRange("No.", Rec."Warehouse Pick No.");
            WhseActivityLine.SetRange("Action Type", WhseActivityLine."Action Type"::Take);
            if WhseActivityLine.FindSet() then
                repeat
                    TotalLines += 1;
                    if WhseActivityLine."Qty. to Handle" >= WhseActivityLine.Quantity then
                        DoneLines += 1;
                until WhseActivityLine.Next() = 0;
            if TotalLines > 0 then begin
                ProgressText := StrSubstNo('%1 / %2', DoneLines, TotalLines);
                if DoneLines >= TotalLines then
                    ProgressStyle := 'Favorable'
                else if DoneLines > 0 then
                    ProgressStyle := 'Ambiguous'
                else
                    ProgressStyle := 'Attention';
            end else
                // Register edilince açık satırlar silinir toplama bitmiş demektir.
                if Rec.Status = Rec.Status::"Pick Created" then begin
                    ProgressText := 'Toplandı';
                    ProgressStyle := 'Favorable';
                end;
        end;
    end;

    var
        StatusStyle: Text;
        StatusText: Text;
        AssignedStyle: Text;
        OrderCountText: Text;
        ProgressText: Text;
        ProgressStyle: Text;
        CompletedNotAssignableErr: Label 'Tamamlanmış grubun ataması değiştirilemez.';
        TakeOverQst: Label 'Bu grup %1 kullanıcısında. %2 kullanıcısına devredilsin mi?', Comment = '%1 = mevcut operatör, %2 = yeni operatör';
        ClearPickerQst: Label '%1 kullanıcısının ataması kaldırılsın mı? Toplama terminalde yeniden herkese açılır.', Comment = '%1 = mevcut operatör';
        AssignedFromListLbl: Label 'Toplanacak Siparişler ekranından atandı.';
        ClearedFromListLbl: Label 'Toplanacak Siparişler ekranından atama kaldırıldı.';
        GroupGoneErr: Label 'Toplama grubu %1 bulunamadı — silinmiş olabilir. Listeyi yenileyin.', Comment = '%1 = Kayıt No.';
        GroupAlreadyPostedErr: Label 'Bu grup için toplama zaten oluşturulmuş (%1). Sayfayı yenileyin.', Comment = '%1 = Toplama belgesi no.';
        PickerRequiredErr: Label 'Pick oluşturmadan önce "Toplayıcı Ata" ile bir operatör seçin.';
        PickCreatedMsg: Label 'Toplama %1 oluşturuldu — terminalde %2 kullanıcısına görünüyor.', Comment = '%1 = Toplama no., %2 = operatör';
        AssignmentNotSavedErr: Label '%1 kullanıcısına yapılan atama kayda yazılamadı.', Comment = '%1 = operatör';
        NoGroupsSelectedErr: Label 'Terminale göndermek için en az bir toplama grubu seçin.';
        GroupNotOpenErr: Label '%1 numaralı grup açık değil. Yalnız açık gruplar toplu gönderilebilir.', Comment = '%1 = group entry no.';
        GroupPickerMissingErr: Label '%1 numaralı grupta toplayıcı atanmamış. Önce Toplayıcı Ata işlemini tamamlayın.', Comment = '%1 = group entry no.';
        PostSelectedGroupsQst: Label 'Seçilen %1 toplama grubu terminale gönderilsin mi?', Comment = '%1 = count';
        SelectedGroupsPostedMsg: Label '%1 toplama grubu terminale gönderildi.', Comment = '%1 = count';
}
