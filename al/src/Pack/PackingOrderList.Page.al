page 72361 "DOPSWHS Packing Order List"
{
    // Depo sorumlusunun paketleme takip ekranı. Terminal pick bazlı çalışır
    // (bir pick = N sipariş), bu yüzden liste varsayılan olarak Pick No.'ya
    // göre gruplanmış gelir ve hangi pick'in kaç siparişinin kaldığı görünür.
    PageType = List;
    Caption = 'Paketleme Siparişleri';
    SourceTable = "DOPSWHS Packing Order";
    CardPageId = "DOPSWHS Packing Order Card";
    ApplicationArea = All;
    UsageCategory = Tasks;
    Editable = false;
    SourceTableView = sorting("Pick No.", "Sales Order No.");

    layout
    {
        area(Content)
        {
            repeater(Orders)
            {
                field("Pick No."; Rec."Pick No.")
                {
                    ApplicationArea = All;
                    Caption = 'Toplama No.';
                    ToolTip = 'Bu siparişin geldiği toplama (pick) belgesi. Terminalde paketleme pick bazlı yapılır: aynı pick''in tüm siparişleri arka arkaya paketlenir.';
                    StyleExpr = RowStyle;
                }
                field("Sales Order No."; Rec."Sales Order No.")
                {
                    ApplicationArea = All;
                    Caption = 'Satış Siparişi';
                    StyleExpr = RowStyle;
                }
                field("Customer Name"; Rec."Customer Name")
                {
                    ApplicationArea = All;
                    Caption = 'Müşteri';
                    StyleExpr = RowStyle;
                }
                field(StatusText; StatusText)
                {
                    ApplicationArea = All;
                    Caption = 'Durum';
                    StyleExpr = RowStyle;
                    ToolTip = 'Hazır: paketleme bekliyor. Paketleniyor: bir operatör başladı. Tamamlandı: sevk + fatura kesildi.';
                }
                field(ProgressText; ProgressText)
                {
                    ApplicationArea = All;
                    Caption = 'İlerleme';
                    ToolTip = 'Paketlenen / toplam ürün adedi.';
                    StyleExpr = ProgressStyle;
                }
                field("Started By User"; Rec."Started By User")
                {
                    ApplicationArea = All;
                    Caption = 'Paketleyen';
                    ToolTip = 'Paketlemeyi üstlenen WMS operatörü. Terminalde paketlemeye başlayan kişi otomatik yazılır.';
                }
                field(WaitingText; WaitingText)
                {
                    ApplicationArea = All;
                    Caption = 'Bekleme';
                    ToolTip = 'Sipariş ne kadar süredir paketleme kuyruğunda bekliyor.';
                    StyleExpr = WaitingStyle;
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    Caption = 'Lokasyon';
                }
                field("Warehouse Shipment No."; Rec."Warehouse Shipment No.")
                {
                    ApplicationArea = All;
                    Caption = 'Ambar Sevkiyatı';
                    Visible = false;
                }
                field("Ready DateTime"; Rec."Ready DateTime")
                {
                    ApplicationArea = All;
                    Caption = 'Kuyruğa Giriş';
                    Visible = false;
                }
                field("Started DateTime"; Rec."Started DateTime")
                {
                    ApplicationArea = All;
                    Caption = 'Başlama';
                    Visible = false;
                }
                field("Completed DateTime"; Rec."Completed DateTime")
                {
                    ApplicationArea = All;
                    Caption = 'Tamamlanma';
                    Visible = false;
                }
            }
        }
        area(FactBoxes)
        {
            systempart(Notes; Notes) { ApplicationArea = All; }
        }
    }

    actions
    {
        area(Processing)
        {
            group(Filters)
            {
                Caption = 'Görünüm';
                Image = FilterLines;

                action(ShowOpen)
                {
                    ApplicationArea = All;
                    Caption = 'Bekleyenler';
                    Image = List;
                    ToolTip = 'Sadece paketlenmeyi bekleyen ve paketlenmekte olan siparişleri gösterir.';
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    begin
                        Rec.SetFilter(Status, '%1|%2', Rec.Status::Ready, Rec.Status::"In Progress");
                        CurrPage.Update(false);
                    end;
                }
                action(ShowCompleted)
                {
                    ApplicationArea = All;
                    Caption = 'Tamamlananlar';
                    Image = Completed;
                    ToolTip = 'Sadece paketlemesi bitmiş (sevk + fatura kesilmiş) siparişleri gösterir.';
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    begin
                        Rec.SetRange(Status, Rec.Status::Completed);
                        CurrPage.Update(false);
                    end;
                }
                action(ShowAll)
                {
                    ApplicationArea = All;
                    Caption = 'Tümü';
                    Image = ShowList;
                    ToolTip = 'Tüm paketleme siparişlerini gösterir.';
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    begin
                        Rec.SetRange(Status);
                        CurrPage.Update(false);
                    end;
                }
                action(ShowUnassigned)
                {
                    ApplicationArea = All;
                    Caption = 'Atanmamışlar';
                    Image = UserSetup;
                    ToolTip = 'Henüz kimsenin üstlenmediği paketleme siparişlerini gösterir.';

                    trigger OnAction()
                    begin
                        Rec.SetFilter(Status, '%1|%2', Rec.Status::Ready, Rec.Status::"In Progress");
                        Rec.SetRange("Started By User", '');
                        CurrPage.Update(false);
                    end;
                }
            }
            group(Manage)
            {
                Caption = 'Yönet';

                action(AssignPacker)
                {
                    ApplicationArea = All;
                    Caption = 'Paketleyici Ata';
                    Image = UserSetup;
                    ToolTip = 'Seçili siparişi bir WMS operatörüne atar. Liste, operatörlerin terminalde giriş yaptığı yerel WMS kullanıcılarını gösterir.';
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    var
                        LocalUser: Record "DOPSWHS Local User";
                    begin
                        if Rec."Sales Order No." = '' then
                            exit;
                        if Rec.Status = Rec.Status::Completed then
                            Error('Tamamlanmış sipariş yeniden atanamaz.');
                        LocalUser.SetRange(Disabled, false);
                        if Page.RunModal(Page::"DOPSWHS Local User List", LocalUser) <> Action::LookupOK then
                            exit;
                        Rec."Started By User" := LocalUser.Username;
                        if Rec.Status = Rec.Status::Ready then
                            Rec.Status := Rec.Status::"In Progress";
                        if Rec."Started DateTime" = 0DT then
                            Rec."Started DateTime" := CurrentDateTime();
                        Rec.Modify(true);
                        CurrPage.Update(false);
                        Message('%1 siparişi %2 kullanıcısına atandı.', Rec."Sales Order No.", LocalUser."Display Name");
                    end;
                }
                action(ClearPacker)
                {
                    ApplicationArea = All;
                    Caption = 'Atamayı Kaldır';
                    Image = UnApply;
                    ToolTip = 'Siparişi atanmamış duruma döndürür; başka bir operatör üstlenebilir.';

                    trigger OnAction()
                    begin
                        if Rec.Status = Rec.Status::Completed then
                            Error('Tamamlanmış siparişin ataması değiştirilemez.');
                        Rec."Started By User" := '';
                        Rec.Status := Rec.Status::Ready;
                        Rec.Modify(true);
                        CurrPage.Update(false);
                    end;
                }
            }
            group(Navigate)
            {
                Caption = 'İlgili';

                action(OpenSalesOrder)
                {
                    ApplicationArea = All;
                    Caption = 'Satış Siparişi';
                    Image = Document;
                    ToolTip = 'Bu paketleme kaydının kaynağı olan satış siparişini açar.';
                    Promoted = true;
                    PromotedCategory = Category4;

                    trigger OnAction()
                    var
                        SalesHeader: Record "Sales Header";
                    begin
                        if not SalesHeader.Get(SalesHeader."Document Type"::Order, Rec."Sales Order No.") then
                            Error('Satış siparişi %1 bulunamadı (kayıtlanmış olabilir).', Rec."Sales Order No.");
                        Page.Run(Page::"Sales Order", SalesHeader);
                    end;
                }
                action(OpenPick)
                {
                    ApplicationArea = All;
                    Caption = 'Toplama Belgesi';
                    Image = PickLines;
                    ToolTip = 'Bu siparişin geldiği toplama (pick) belgesini açar.';
                    Promoted = true;
                    PromotedCategory = Category4;

                    trigger OnAction()
                    var
                        WhseActivityHeader: Record "Warehouse Activity Header";
                    begin
                        if Rec."Pick No." = '' then
                            Error('Bu kayıtta toplama belgesi yok.');
                        // Pick register edilince başlık silinir; o durumda kullanıcıya
                        // hata yerine açıklayıcı mesaj ver.
                        if not WhseActivityHeader.Get(WhseActivityHeader.Type::Pick, Rec."Pick No.") then
                            Error('Toplama %1 artık açık değil (kaydedilmiş olabilir).', Rec."Pick No.");
                        Page.Run(Page::"Warehouse Pick", WhseActivityHeader);
                    end;
                }
                action(OpenPackSession)
                {
                    ApplicationArea = All;
                    Caption = 'Paketleme Oturumu';
                    Image = WorkCenter;
                    ToolTip = 'Bu siparişin paketleme oturumunu (okutulan ürünler, kutu) açar.';

                    trigger OnAction()
                    var
                        PackSession: Record "DOPSWHS Pack Session";
                    begin
                        if Rec."Session Entry No." = 0 then
                            Error('Bu sipariş için henüz paketleme oturumu başlatılmadı.');
                        if not PackSession.Get(Rec."Session Entry No.") then
                            Error('Paketleme oturumu bulunamadı.');
                        Page.Run(Page::"DOPSWHS Pack Station", PackSession);
                    end;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        // Varsayılan: sorumlunun ilgilendiği açık iş. "Tümü" / "Tamamlananlar"
        // aksiyonlarıyla genişletilebilir.
        Rec.SetFilter(Status, '%1|%2', Rec.Status::Ready, Rec.Status::"In Progress");
    end;

    trigger OnAfterGetRecord()
    var
        PackLine: Record "DOPSWHS Pack Session Line";
        Expected: Decimal;
        Packed: Decimal;
        WaitingMinutes: Integer;
    begin
        // Durum metni + satır rengi
        case Rec.Status of
            Rec.Status::Ready:
                begin
                    StatusText := 'Hazır';
                    RowStyle := 'Standard';
                end;
            Rec.Status::"In Progress":
                begin
                    StatusText := 'Paketleniyor';
                    RowStyle := 'Attention';
                end;
            Rec.Status::Completed:
                begin
                    StatusText := 'Tamamlandı';
                    RowStyle := 'Favorable';
                end;
            else begin
                StatusText := Format(Rec.Status);
                RowStyle := 'Standard';
            end;
        end;

        // İlerleme: oturum satırlarından paketlenen / beklenen adet
        Expected := 0;
        Packed := 0;
        if Rec."Session Entry No." <> 0 then begin
            PackLine.SetRange("Session Entry No.", Rec."Session Entry No.");
            PackLine.SetRange("Source Order No.", Rec."Sales Order No.");
            if PackLine.FindSet() then
                repeat
                    Expected += PackLine."Qty. Expected";
                    Packed += PackLine."Qty. Packed";
                until PackLine.Next() = 0;
        end;
        if Expected > 0 then begin
            ProgressText := StrSubstNo('%1 / %2', Format(Packed), Format(Expected));
            if Packed >= Expected then
                ProgressStyle := 'Favorable'
            else if Packed > 0 then
                ProgressStyle := 'Attention'
            else
                ProgressStyle := 'Standard';
        end else begin
            ProgressText := '—';
            ProgressStyle := 'Subordinate';
        end;

        // Bekleme süresi (tamamlananlarda gösterilmez)
        WaitingText := '';
        WaitingStyle := 'Standard';
        if (Rec.Status <> Rec.Status::Completed) and (Rec."Ready DateTime" <> 0DT) then begin
            WaitingMinutes := Round((CurrentDateTime() - Rec."Ready DateTime") / 60000, 1);
            if WaitingMinutes < 60 then
                WaitingText := StrSubstNo('%1 dk', WaitingMinutes)
            else
                WaitingText := StrSubstNo('%1 sa %2 dk', WaitingMinutes div 60, WaitingMinutes mod 60);
            // 2 saati aşan bekleme dikkat çeksin.
            if WaitingMinutes >= 120 then
                WaitingStyle := 'Unfavorable'
            else if WaitingMinutes >= 60 then
                WaitingStyle := 'Attention';
        end;
    end;

    var
        RowStyle: Text;
        StatusText: Text;
        ProgressText: Text;
        ProgressStyle: Text;
        WaitingText: Text;
        WaitingStyle: Text;
}
