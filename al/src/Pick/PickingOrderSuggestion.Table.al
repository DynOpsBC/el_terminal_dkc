table 72354 "DOPSWHS Picking Order Sugg."
{
    // "Öner" akışının sonucu. Kalıcı veri DEĞİL: yalnızca öneri penceresinde
    // gösterilip kullanıcı onaylayınca gruba eklenir (temporary record olarak
    // kullanılır). Puanlama: ortak ürün sayısı + sevk tarihi yakınlığı + aynı
    // müşteri/lokasyon.
    Caption = 'Toplama Önerisi';
    DataClassification = CustomerContent;
    TableType = Temporary;
    Access = Public;

    fields
    {
        field(1; "Sales Order No."; Code[20])
        {
            Caption = 'Satış Siparişi';
            DataClassification = CustomerContent;
        }
        field(10; "Sell-to Customer No."; Code[20]) { Caption = 'Müşteri No.'; DataClassification = CustomerContent; }
        field(11; "Sell-to Customer Name"; Text[100]) { Caption = 'Müşteri'; DataClassification = CustomerContent; }
        field(20; "Location Code"; Code[10]) { Caption = 'Lokasyon'; DataClassification = CustomerContent; }
        field(30; "Shipment Date"; Date) { Caption = 'Sevk Tarihi'; DataClassification = CustomerContent; }
        field(40; "Item Line Count"; Integer) { Caption = 'Satır'; DataClassification = CustomerContent; }
        field(41; "Total Quantity"; Decimal) { Caption = 'Toplam Miktar'; DecimalPlaces = 0 : 5; DataClassification = CustomerContent; }

        // --- Puanlama ---
        field(50; "Score"; Integer)
        {
            Caption = 'Uygunluk Puanı';
            DataClassification = CustomerContent;
            ToolTip = 'Yüksek puan = gruba daha uygun. Ortak ürün sayısı, sevk tarihi yakınlığı ve aynı müşteri/lokasyon dikkate alınır.';
        }
        field(51; "Shared Item Count"; Integer)
        {
            Caption = 'Ortak Ürün';
            DataClassification = CustomerContent;
            ToolTip = 'Gruptaki siparişlerle ortak olan ürün sayısı — aynı raflardan toplanacağı için yürüme yolu kısalır.';
        }
        field(52; "Date Gap Days"; Integer)
        {
            Caption = 'Tarih Farkı (gün)';
            DataClassification = CustomerContent;
            ToolTip = 'Gruptaki en erken sevk tarihine uzaklık.';
        }
        field(53; "Same Customer"; Boolean) { Caption = 'Aynı Müşteri'; DataClassification = CustomerContent; }
        field(60; "Reason"; Text[250])
        {
            Caption = 'Neden Öneriliyor';
            DataClassification = CustomerContent;
        }
        field(70; "Selected"; Boolean)
        {
            Caption = 'Ekle';
            DataClassification = CustomerContent;
            ToolTip = 'İşaretli siparişler "Seçilenleri Ekle" ile gruba eklenir.';
        }
    }

    keys
    {
        key(PK; "Sales Order No.") { Clustered = true; }
        // Öneri listesi en yüksek puandan başlayarak sıralanır.
        key(Score; "Score") { }
    }
}
