page 72360 "DOPSWHS Packing Order API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'packingOrder';
    EntitySetName = 'packingOrders';
    SourceTable = "DOPSWHS Packing Order";
    ODataKeyFields = "Sales Order No.";
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
                field(salesOrderNo; Rec."Sales Order No.") { Caption = 'salesOrderNo'; }
                field(pickNo; Rec."Pick No.") { Caption = 'pickNo'; }
                // Toplamada kullanılan sepet — paketleyici ürünleri nereden alacağını görür.
                field(mainLpNo; Rec."Main LP No.") { Caption = 'mainLpNo'; }
                field(warehouseShipmentNo; Rec."Warehouse Shipment No.") { Caption = 'warehouseShipmentNo'; }
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; }
                field(customerNo; Rec."Customer No.") { Caption = 'customerNo'; }
                field(customerName; Rec."Customer Name") { Caption = 'customerName'; }
                field(status; Rec.Status) { Caption = 'status'; }
                // V2 paketleme sekmeleri (Multi / Mono / Tek SKU) listeyi bu
                // alanla filtreliyor; yayınlanmadan $filter 400 dönüyordu.
                field(orderFlowMode; Rec."Order Flow Mode") { Caption = 'orderFlowMode'; }
                field(sessionEntryNo; Rec."Session Entry No.") { Caption = 'sessionEntryNo'; }
                field(readyDateTime; Rec."Ready DateTime") { Caption = 'readyDateTime'; }
                field(startedByUser; Rec."Started By User") { Caption = 'startedByUser'; }
                field(lineCount; LineCount) { Caption = 'lineCount'; }
                field(remainingQuantity; RemainingQuantity) { Caption = 'remainingQuantity'; }
                field(percentComplete; PercentComplete) { Caption = 'percentComplete'; }
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        PackLine: Record "DOPSWHS Pack Session Line";
        Expected: Decimal;
        Packed: Decimal;
    begin
        Clear(LineCount);
        Clear(RemainingQuantity);
        Clear(PercentComplete);
        if Rec."Session Entry No." = 0 then
            exit;

        PackLine.SetRange("Session Entry No.", Rec."Session Entry No.");
        if PackLine.FindSet() then
            repeat
                LineCount += 1;
                Expected += PackLine."Qty. Expected";
                Packed += PackLine."Qty. Packed";
            until PackLine.Next() = 0;
        RemainingQuantity := Expected - Packed;
        if Expected > 0 then
            PercentComplete := Round(Packed / Expected * 100, 1);
    end;

    [ServiceEnabled]
    procedure startPacking(): Integer
    var
        PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
    begin
        exit(PackMgmt.StartOrderSession(Rec."Sales Order No."));
    end;

    // ELOG: paketlemeyi ÜSTLENEN WMS operatörünü kaydet (başlatan = üstlenen).
    // BC servis hesabı yerine terminaldeki WMS kullanıcısı Started By User olur.
    [ServiceEnabled]
    procedure startPackingAs(userId: Code[50]): Integer
    var
        PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
    begin
        exit(PackMgmt.StartOrderSession(Rec."Sales Order No.", userId));
    end;

    var
        LineCount: Integer;
        RemainingQuantity: Decimal;
        PercentComplete: Decimal;
}
