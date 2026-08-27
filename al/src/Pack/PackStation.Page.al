page 72339 "DOPSWHS Pack Station"
{
    // ELOG "Batch Package Worksheet" muadili — masaüstü + USB/wedge barkod
    // okuyucu ile BC istemcisi içinde paketleme. Tek "Scan Here" alanı adım
    // bazlı yönlendirir: sepet (tote LP) kutu ürünler. Bir siparişin payı
    // tamamlanınca sipariş sevk+fatura edilir ve fişi basılır (Pack Station
    // Mgmt). Multi / bulk / mono-SKU tek motorla çalışır; ayrı sayfa gerekmez.
    PageType = Card;
    Caption = 'Pack Station (WMS)';
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "DOPSWHS Pack Session";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(Details)
            {
                Caption = 'Details';
                field(ToteLpNo; Rec."Tote LP No.") { Caption = 'Current Tote'; ApplicationArea = All; Editable = false; }
                field(BoxLpNo; Rec."Box LP No.") { Caption = 'Current Box'; ApplicationArea = All; Editable = false; }
                field(SessionMode; Rec.Mode) { Caption = 'Mode'; ApplicationArea = All; Editable = false; }
                field(CurrentOrderNo; CurrentOrderNo) { Caption = 'Current Order'; ApplicationArea = All; Editable = false; }
                field(PickNo; Rec."Pick No.") { Caption = 'Pick No.'; ApplicationArea = All; Editable = false; }
                field(LocationCode; Rec."Location Code") { Caption = 'Location'; ApplicationArea = All; Editable = false; }
                field(SessionStatus; Rec.Status) { Caption = 'Status'; ApplicationArea = All; Editable = false; }
                field(OrdersProgress; StrSubstNo('%1 / %2', Rec."Orders Completed", Rec."Orders Total"))
                {
                    Caption = 'Orders Completed';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(UnpackedQty; UnpackedQty) { Caption = 'Unpacked Quantity'; ApplicationArea = All; Editable = false; }
                field(UnpackedLines; UnpackedLines) { Caption = 'Unpacked Lines'; ApplicationArea = All; Editable = false; }
            }
            group(Scanning)
            {
                Caption = 'Scanning';
                InstructionalText = 'Scan a license plate to pack';
                // Yeni oturum bu modda açılır — ELOG'daki Batch / Mono-SKU
                // worksheet ayrımı tek sayfada mod seçimiyle karşılanır.
                field(SelectedMode; SelectedMode)
                {
                    Caption = 'New Session Mode';
                    ApplicationArea = All;
                }
                field(ScanInput; ScanInput)
                {
                    Caption = 'Scan Here';
                    ApplicationArea = All;

                    trigger OnValidate()
                    begin
                        HandleScan(ScanInput);
                    end;
                }
                field(NextStep; NextStep) { Caption = 'Next Step'; ApplicationArea = All; Editable = false; }
                field(LastScan; LastScan) { Caption = 'Last Scan'; ApplicationArea = All; Editable = false; }
                field(LastPackedOrder; LastPackedOrder) { Caption = 'Last Packed Order'; ApplicationArea = All; Editable = false; }
            }
            part(Lines; "DOPSWHS Pack Session Subform")
            {
                Caption = 'Packed Lines';
                ApplicationArea = All;
                SubPageLink = "Session Entry No." = field("Entry No.");
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(PrintLastPackedOrder)
            {
                Caption = 'Print Last Packed Order';
                ApplicationArea = All;
                Image = Print;

                trigger OnAction()
                var
                    PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
                    Orders: List of [Text];
                    OrderNo: Text;
                begin
                    if LastPackedOrder = '' then
                        exit;
                    Orders := LastPackedOrder.Split(',');
                    foreach OrderNo in Orders do
                        PackMgmt.ReprintOrderReceipt(CopyStr(OrderNo.Trim(), 1, 20));
                end;
            }
            action(CancelSession)
            {
                Caption = 'Cancel Session';
                ApplicationArea = All;
                Image = Cancel;
                Enabled = Rec.Status = Rec.Status::Open;

                trigger OnAction()
                var
                    PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
                begin
                    if Rec."Entry No." = 0 then
                        exit;
                    PackMgmt.CancelSession(Rec."Entry No.");
                    CurrPage.Update(false);
                end;
            }
            action(Refresh)
            {
                Caption = 'Refresh';
                ApplicationArea = All;
                Image = Refresh;

                trigger OnAction()
                begin
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(Sessions)
            {
                Caption = 'Pack Sessions';
                ApplicationArea = All;
                Image = History;
                RunObject = page "DOPSWHS Pack Session List";
            }
        }
    }

    trigger OnOpenPage()
    begin
        // Listeden belirli bir oturumla açıldıysa (CardPageId) filtre uygulanmaz.
        // Doğrudan açılışta paketleyici kendi son oturumuna döner; yoksa boş —
        // ilk okutulan sepet yeni oturumu başlatır.
        if Rec."Entry No." <> 0 then
            exit;
        Rec.SetRange("Created By User", CopyStr(UserId(), 1, 50));
        if Rec.FindLast() then;
    end;

    trigger OnAfterGetRecord()
    begin
        CalcUnpacked();
    end;

    local procedure HandleScan(Value: Text)
    var
        PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
        Completed: Text;
        BoxOrder: Code[20];
        NewId: Integer;
    begin
        if Value.Trim() = '' then
            exit;
        LastScan := CopyStr(Value.Trim(), 1, MaxStrLen(LastScan));
        ScanInput := '';

        if (Rec."Entry No." = 0) or (Rec.Status <> Rec.Status::Open) then begin
            // Adım 1: sepet — seçili modda yeni oturum.
            NewId := PackMgmt.StartSession(CopyStr(LastScan, 1, 20), Format(SelectedMode));
            Rec.Get(NewId);
        end else begin
            // Kutu bekleyen sipariş varsa okuma kutudur; yoksa üründür.
            // Solo/Bulk: sıradaki siparişin kutusu yoksa önce kutu.
            // Batch: ürünler okutulur, tam paketlenen sipariş kutu bekler —
            // kutu okuması siparişi kapatır ve fişini bastırır.
            BoxOrder := PackMgmt.BoxNeededOrder(Rec."Entry No.");
            if BoxOrder <> '' then begin
                // Kargo kolisi barkodu 20 karakteri aşabilir (kargo etiketi/SSCC).
                PackMgmt.SetBoxForOrder(Rec."Entry No.", BoxOrder, CopyStr(LastScan, 1, 50), '');
                if OrderCompleted(Rec."Entry No.", BoxOrder) then
                    LastPackedOrder := BoxOrder;
            end else begin
                // Yanlış ürün Error ile geri döner.
                Completed := PackMgmt.ScanItem(Rec."Entry No.", CopyStr(LastScan, 1, 20), 1);
                if Completed <> '' then
                    LastPackedOrder := CopyStr(Completed, 1, MaxStrLen(LastPackedOrder));
            end;
        end;

        if Rec.Get(Rec."Entry No.") then;
        CalcUnpacked();
        CurrPage.Update(false);
    end;

    local procedure OrderCompleted(SessionId: Integer; OrderNo: Code[20]): Boolean
    var
        Line: Record "DOPSWHS Pack Session Line";
    begin
        Line.SetRange("Session Entry No.", SessionId);
        Line.SetRange("Source Order No.", OrderNo);
        Line.SetRange("Order Completed", true);
        exit(not Line.IsEmpty());
    end;

    local procedure CalcUnpacked()
    var
        Line: Record "DOPSWHS Pack Session Line";
        PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
        BoxOrder: Code[20];
    begin
        UnpackedQty := 0;
        UnpackedLines := 0;
        CurrentOrderNo := '';
        NextStep := '';
        if Rec."Entry No." = 0 then begin
            NextStep := ScanToteTxt;
            exit;
        end;
        Line.SetRange("Session Entry No.", Rec."Entry No.");
        if Line.FindSet() then
            repeat
                if Line."Qty. Packed" < Line."Qty. Expected" then begin
                    UnpackedLines += 1;
                    UnpackedQty += Line."Qty. Expected" - Line."Qty. Packed";
                end;
            until Line.Next() = 0;

        if Rec.Status <> Rec.Status::Open then begin
            NextStep := ScanToteTxt;
            exit;
        end;
        CurrentOrderNo := PackMgmt.CurrentOrder(Rec."Entry No.");
        BoxOrder := PackMgmt.BoxNeededOrder(Rec."Entry No.");
        if BoxOrder <> '' then
            NextStep := StrSubstNo(ScanBoxTxt, BoxOrder)
        else
            NextStep := ScanItemTxt;
    end;

    var
        ScanInput: Text;
        LastScan: Text[50];
        LastPackedOrder: Text[100];
        CurrentOrderNo: Code[20];
        NextStep: Text;
        SelectedMode: Enum "DOPSWHS Pack Mode";
        UnpackedQty: Decimal;
        UnpackedLines: Integer;
        ScanToteTxt: Label 'Scan a tote (LP) to start';
        ScanBoxTxt: Label 'Scan a box for order %1', Comment = '%1 = Sales Order No.';
        ScanItemTxt: Label 'Scan items';
}
