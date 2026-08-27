table 72333 "DOPSWHS Pack Session Line"
{
    // Paketleme oturumunun beklenen içerik satırları — sipariş + ürün bazında.
    // Terminal ekranında "Qty. Packed" < "Qty. Expected" olan satırlar kırmızı
    // (bekliyor) gösterilir; her ürün okutmada Qty. Packed artar.
    Caption = 'Pack Session Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Session Entry No."; Integer) { Caption = 'Session Entry No.'; DataClassification = CustomerContent; TableRelation = "DOPSWHS Pack Session"; }
        field(2; "Line No."; Integer) { Caption = 'Line No.'; DataClassification = CustomerContent; }
        field(10; "Source Order No."; Code[20]) { Caption = 'Source Order No.'; DataClassification = CustomerContent; }
        field(11; "Item No."; Code[20]) { Caption = 'Item No.'; DataClassification = CustomerContent; TableRelation = Item; }
        field(12; "Variant Code"; Code[10]) { Caption = 'Variant Code'; DataClassification = CustomerContent; }
        field(13; "Unit of Measure Code"; Code[10]) { Caption = 'Unit of Measure Code'; DataClassification = CustomerContent; }
        field(14; Description; Text[100]) { Caption = 'Description'; DataClassification = CustomerContent; }
        field(15; GTIN; Code[14]) { Caption = 'GTIN'; DataClassification = CustomerContent; }
        field(20; "Qty. Expected"; Decimal) { Caption = 'Qty. Expected'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(21; "Qty. Packed"; Decimal) { Caption = 'Qty. Packed'; DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(30; "Order Completed"; Boolean) { Caption = 'Order Completed'; DataClassification = CustomerContent; }
        // KUTU = müşteriye giden KARGO KOLİSİ (depoda kalan sepet/tote DEĞİL).
        // Koli barkodu genelde sistemde kayıtlı bir LP değildir; kolinin üzerindeki
        // kargo etiketi / SSCC okutulur. Bu yüzden "Box Barcode" serbest metindir ve
        // TableRelation'ı YOKTUR — LP zorunlu tutulursa operatörün elindeki koli
        // okutulamaz. "Box LP No." yalnızca sistemin ürettiği karton LP'lerde dolar
        // (geriye dönük uyumluluk + LP izlemesi isteyen kurulumlar).
        field(40; "Box LP No."; Code[20]) { Caption = 'Box LP No.'; DataClassification = CustomerContent; TableRelation = "DOPSWHS LP Header"; }
        field(41; "Box Barcode"; Code[50]) { Caption = 'Kargo Kolisi Barkodu'; DataClassification = CustomerContent; }
    }

    keys
    {
        key(PK; "Session Entry No.", "Line No.") { Clustered = true; }
        key(Order; "Session Entry No.", "Source Order No.") { }
        key(BoxBarcode; "Box Barcode") { }
    }
}
