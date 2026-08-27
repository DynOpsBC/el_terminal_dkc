table 72359 "DOPSWHS Packing Order"
{
    Caption = 'Order Packing';
    DataClassification = CustomerContent;
    LookupPageId = "DOPSWHS Packing Order List";
    DrillDownPageId = "DOPSWHS Packing Order List";

    fields
    {
        field(1; "Sales Order No."; Code[20]) { Caption = 'Sales Order No.'; DataClassification = CustomerContent; }
        field(10; "Pick No."; Code[20]) { Caption = 'Pick No.'; DataClassification = CustomerContent; }
        field(20; "Warehouse Shipment No."; Code[20]) { Caption = 'Warehouse Shipment No.'; DataClassification = CustomerContent; }
        field(30; "Location Code"; Code[10]) { Caption = 'Location Code'; TableRelation = Location; DataClassification = CustomerContent; }
        field(40; "Customer No."; Code[20]) { Caption = 'Customer No.'; DataClassification = CustomerContent; }
        field(41; "Customer Name"; Text[100]) { Caption = 'Customer Name'; DataClassification = CustomerContent; }
        field(50; Status; Enum "DOPSWHS Packing Order Status") { Caption = 'Status'; DataClassification = CustomerContent; }
        // Toplama grubundan taşınan ELOG akış tipi. Terminaldeki V2 paketleme
        // sekmeleri (Multi / Mono / Tek SKU) listeyi bu alanla filtreler.
        field(55; "Order Flow Mode"; Enum "DOPSWHS Pick Mode") { Caption = 'V2 Sipariş Tipi'; Editable = false; DataClassification = CustomerContent; }
        field(60; "Session Entry No."; Integer) { Caption = 'Session Entry No.'; Editable = false; DataClassification = CustomerContent; }
        field(70; "Ready DateTime"; DateTime) { Caption = 'Ready DateTime'; Editable = false; DataClassification = CustomerContent; }
        field(80; "Started By User"; Code[50]) { Caption = 'Started By User'; Editable = false; DataClassification = EndUserIdentifiableInformation; }
        // Toplamada kullanılan ana sepet (LP). Paketlemede operatöre "ürünler
        // hangi sepette" bilgisini vermek için pick'ten taşınır.
        field(85; "Main LP No."; Code[20]) { Caption = 'Ana Sepet (LP)'; Editable = false; DataClassification = CustomerContent; }
        field(81; "Started DateTime"; DateTime) { Caption = 'Started DateTime'; Editable = false; DataClassification = CustomerContent; }
        field(90; "Completed DateTime"; DateTime) { Caption = 'Completed DateTime'; Editable = false; DataClassification = CustomerContent; }
    }

    keys
    {
        key(PK; "Sales Order No.") { Clustered = true; }
        key(StatusKey; Status, "Ready DateTime") { }
        // StartPickSession ve paketleme listeleri Pick No. ile filtreler.
        key(PickKey; "Pick No.") { }
        // Terminalin V2 sorgusu: orderFlowMode filtresi + readyDateTime sıralaması.
        key(FlowStatusKey; "Order Flow Mode", Status, "Ready DateTime") { }
    }
}
