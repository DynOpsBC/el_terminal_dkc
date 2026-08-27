table 72332 "DOPSWHS Pack Session"
{
    // ELOG saha ziyareti: paketleme istasyonu oturumu. Operatör tote'u (LP)
    // okutur beklenen satırlar oluşur; kutuyu okutur; ürünleri tek tek
    // okutur; bir siparişin tüm satırları tamamlanınca sipariş sevk+fatura
    // edilir ve fişi basılır (bkz. "DOPSWHS Pack Station Mgmt").
    Caption = 'Pack Session';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'Entry No.'; DataClassification = CustomerContent; AutoIncrement = true; }
        // SEPET (tote): depoda kalan, geri dönen taşıma kabı gerçek bir LP.
        field(10; "Tote LP No."; Code[20]) { Caption = 'Sepet LP No.'; DataClassification = CustomerContent; TableRelation = "DOPSWHS LP Header"; }
        // KUTU (koli): müşteriye giden kargo kolisi depoda kalmaz, LP olmak
        // zorunda değildir. Okutulan koli barkodu "Box Barcode"a yazılır;
        // "Box LP No." yalnızca sistem karton LP ürettiğinde dolar.
        field(11; "Box LP No."; Code[20]) { Caption = 'Kutu LP No.'; DataClassification = CustomerContent; TableRelation = "DOPSWHS LP Header"; }
        field(14; "Box Barcode"; Code[50]) { Caption = 'Kargo Kolisi Barkodu'; DataClassification = CustomerContent; }
        field(12; "Pick No."; Code[20]) { Caption = 'Pick No.'; DataClassification = CustomerContent; }
        field(13; "Location Code"; Code[10]) { Caption = 'Location Code'; DataClassification = CustomerContent; TableRelation = Location; }
        field(20; Status; Enum "DOPSWHS Pack Status") { Caption = 'Status'; DataClassification = CustomerContent; }
        field(21; Mode; Enum "DOPSWHS Pack Mode") { Caption = 'Mode'; DataClassification = CustomerContent; }
        field(30; "Created By User"; Code[50]) { Caption = 'Created By User'; DataClassification = CustomerContent; Editable = false; }
        field(31; "Created DateTime"; DateTime) { Caption = 'Created DateTime'; DataClassification = CustomerContent; Editable = false; }
        field(32; "Completed DateTime"; DateTime) { Caption = 'Completed DateTime'; DataClassification = CustomerContent; Editable = false; }
        field(40; "Orders Total"; Integer) { Caption = 'Orders Total'; DataClassification = CustomerContent; Editable = false; }
        field(41; "Orders Completed"; Integer) { Caption = 'Orders Completed'; DataClassification = CustomerContent; Editable = false; }
        field(42; "Direct Order Packing"; Boolean) { Caption = 'Direct Order Packing'; DataClassification = CustomerContent; Editable = false; }
        field(43; "Printer Code"; Code[20])
        {
            Caption = 'Printer Code';
            DataClassification = CustomerContent;
            TableRelation = "DOPSWHS Printer"."Code" where(Active = const(true));
            ToolTip = 'Printer selected by the terminal when the packing session was started.';
        }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(Tote; "Tote LP No.", Status) { }
    }
}
