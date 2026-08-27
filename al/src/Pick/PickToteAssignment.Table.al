table 72330 "DOPSWHS Pick Tote Assignment"
{
    // ELOG saha ziyareti (07.07.2026): "bir sepet = bir sipariş" — toplama
    // sırasında her kaynak satış siparişine bir tote (yeniden kullanılabilir LP)
    // bağlanır. Paketleme istasyonu (Pack Station) tote'u okutunca bu tablodan
    // sipariş listesini bulur. Bulk/batch'te aynı tote birden çok siparişe
    // hizmet edebilir (aynı pick içinde birden fazla satır).
    Caption = 'Pick Tote Assignment';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Pick No."; Code[20]) { Caption = 'Pick No.'; DataClassification = CustomerContent; }
        field(2; "Source Order No."; Code[20]) { Caption = 'Source Order No.'; DataClassification = CustomerContent; }
        field(10; "LP No."; Code[20]) { Caption = 'LP No.'; DataClassification = CustomerContent; TableRelation = "DOPSWHS LP Header"; }
        field(20; "Location Code"; Code[10]) { Caption = 'Location Code'; DataClassification = CustomerContent; TableRelation = Location; }
        field(30; "Assigned By User"; Code[50]) { Caption = 'Assigned By User'; DataClassification = CustomerContent; Editable = false; }
        field(31; "Assigned DateTime"; DateTime) { Caption = 'Assigned DateTime'; DataClassification = CustomerContent; Editable = false; }
        field(40; Packed; Boolean) { Caption = 'Packed'; DataClassification = CustomerContent; }
    }

    keys
    {
        key(PK; "Pick No.", "Source Order No.") { Clustered = true; }
        key(LP; "LP No.", Packed) { }
    }
}
