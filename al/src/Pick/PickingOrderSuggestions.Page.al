page 72363 "DOPSWHS Picking Order Sugg."
{
    // "Öner" akışının onay penceresi. Motor (PickingOrderMgmt.BuildSuggestions)
    // benzer ürünlü + sevk tarihi yakın siparişleri puanlar; sorumlu burada
    // görür, istemediğini işaretten çıkarır, "Seçilenleri Ekle" der.
    PageType = List;
    Caption = 'Önerilen Siparişler';
    SourceTable = "DOPSWHS Picking Order Sugg.";
    SourceTableTemporary = true;
    ApplicationArea = All;
    UsageCategory = None;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = true;
    SourceTableView = sorting(Score) order(descending);

    layout
    {
        area(Content)
        {
            group(Info)
            {
                ShowCaption = false;

                field(HeaderText; HeaderText)
                {
                    ApplicationArea = All;
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                    Style = Strong;
                }
            }
            repeater(Suggestions)
            {
                field(Selected; Rec."Selected")
                {
                    ApplicationArea = All;
                    Caption = 'Ekle';
                    ToolTip = 'İşaretli siparişler gruba eklenir. İstemediğinizin işaretini kaldırın.';
                }
                field("Sales Order No."; Rec."Sales Order No.")
                {
                    ApplicationArea = All;
                    Caption = 'Satış Siparişi';
                    Editable = false;
                    StyleExpr = RowStyle;
                }
                field("Sell-to Customer Name"; Rec."Sell-to Customer Name")
                {
                    ApplicationArea = All;
                    Caption = 'Müşteri';
                    Editable = false;
                    StyleExpr = RowStyle;
                }
                // Ortak ürün, önerinin ASIL gerekçesi — sipariş/müşteriden hemen
                // sonra gelsin (uzun "Neden" metni bu kolonu sağa itiyordu).
                field("Shared Item Count"; Rec."Shared Item Count")
                {
                    ApplicationArea = All;
                    Caption = 'Ortak Ürün';
                    Editable = false;
                    StyleExpr = SharedStyle;
                }
                field(Reason; Rec.Reason)
                {
                    ApplicationArea = All;
                    Caption = 'Neden Öneriliyor';
                    Editable = false;
                    StyleExpr = RowStyle;
                }
                field("Shipment Date"; Rec."Shipment Date")
                {
                    ApplicationArea = All;
                    Caption = 'Sevk Tarihi';
                    Editable = false;
                }
                field("Date Gap Days"; Rec."Date Gap Days")
                {
                    ApplicationArea = All;
                    Caption = 'Gün Farkı';
                    Editable = false;
                }
                field("Item Line Count"; Rec."Item Line Count")
                {
                    ApplicationArea = All;
                    Caption = 'Satır';
                    Editable = false;
                }
                field("Total Quantity"; Rec."Total Quantity")
                {
                    ApplicationArea = All;
                    Caption = 'Toplam Miktar';
                    Editable = false;
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    Caption = 'Lokasyon';
                    Editable = false;
                }
                field(Score; Rec.Score)
                {
                    ApplicationArea = All;
                    Caption = 'Puan';
                    Editable = false;
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SelectAll)
            {
                ApplicationArea = All;
                Caption = 'Tümünü Seç';
                Image = AllLines;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    Rec.Reset();
                    Rec.ModifyAll("Selected", true);
                    CurrPage.Update(false);
                end;
            }
            action(SelectNone)
            {
                ApplicationArea = All;
                Caption = 'Seçimi Temizle';
                Image = ClearFilter;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    Rec.Reset();
                    Rec.ModifyAll("Selected", false);
                    CurrPage.Update(false);
                end;
            }
            action(OpenSalesOrder)
            {
                ApplicationArea = All;
                Caption = 'Siparişi Aç';
                Image = Document;
                ToolTip = 'Seçili satış siparişini inceleyin.';
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                begin
                    if SalesHeader.Get(SalesHeader."Document Type"::Order, Rec."Sales Order No.") then
                        Page.Run(Page::"Sales Order", SalesHeader);
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        UpdateHeaderText();
    end;

    trigger OnAfterGetRecord()
    begin
        // Ortak ürünü olan öneriler öne çıksın (aynı raflardan toplanır).
        if Rec."Shared Item Count" > 0 then begin
            RowStyle := 'Favorable';
            SharedStyle := 'Favorable';
        end else begin
            RowStyle := 'Standard';
            SharedStyle := 'Subordinate';
        end;
    end;

    local procedure UpdateHeaderText()
    var
        WithShared: Integer;
    begin
        Rec.Reset();
        Rec.SetFilter("Shared Item Count", '>%1', 0);
        WithShared := Rec.Count();
        Rec.Reset();
        case true of
            Rec.Count() = 0:
                HeaderText := 'Uygun öneri bulunamadı. "Satış Siparişlerini Seç" ile elle ekleyebilirsiniz.';
            // Grup boşken ortak ürün kıyaslaması yapılamaz — yanıltıcı
            // "0 tanesinin ortak ürünü var" yazmak yerine durumu açıkla.
            WithShared = 0:
                HeaderText := StrSubstNo(
                    '%1 sipariş önerildi, en yakın sevk tarihlileri üstte. Grupta sipariş olmadığı için ' +
                    'ortak ürün kıyaslaması yapılamadı — birkaçını ekleyip "Öner" derseniz, aynı ürünleri ' +
                    'içeren siparişler öne çıkar. İstemediğinizin işaretini kaldırıp "Tamam" deyin.',
                    Rec.Count());
            else
                HeaderText := StrSubstNo(
                    '%1 sipariş önerildi · %2 tanesinin gruptakilerle ORTAK ÜRÜNÜ var (yeşil satırlar — aynı ' +
                    'raflardan toplanır, yürüme yolu kısalır). İstemediğinizin işaretini kaldırıp "Tamam" deyin.',
                    Rec.Count(), WithShared);
        end;
    end;

    /// <summary>Çağıran sayfa önerileri buraya yükler.</summary>
    procedure LoadSuggestions(var TempSugg: Record "DOPSWHS Picking Order Sugg." temporary)
    begin
        Rec.Reset();
        Rec.DeleteAll();
        if TempSugg.FindSet() then
            repeat
                Rec := TempSugg;
                Rec.Insert();
            until TempSugg.Next() = 0;
        Rec.Reset();
        if Rec.FindFirst() then;
    end;

    /// <summary>Kullanıcının işaretlediklerini çağırana geri verir.</summary>
    procedure GetSelected(var TempSugg: Record "DOPSWHS Picking Order Sugg." temporary)
    begin
        TempSugg.Reset();
        TempSugg.DeleteAll();
        Rec.Reset();
        Rec.SetRange("Selected", true);
        if Rec.FindSet() then
            repeat
                TempSugg := Rec;
                TempSugg.Insert();
            until Rec.Next() = 0;
        Rec.Reset();
    end;

    var
        HeaderText: Text;
        RowStyle: Text;
        SharedStyle: Text;
}
