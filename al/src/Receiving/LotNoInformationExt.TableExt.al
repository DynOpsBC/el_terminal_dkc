tableextension 72430 "DOPSWHS Lot No Info Ext" extends "Lot No. Information"
{
    fields
    {
        field(72430; "DOPSWHS Supplier Lot No."; Code[50])
        {
            Caption = 'Tedarikçi Lotu';
            DataClassification = CustomerContent;
            ToolTip = 'Tedarikçinin ürün üzerinde veya belgesinde bildirdiği lot numarasını belirtir.';
            ObsoleteState = Pending;
            ObsoleteReason = 'BadeProduction tarafından kullanılan Lot No. Information.Description tek tedarikçi lotu kaynağıdır.';
            ObsoleteTag = '1.14.0.22';
        }
    }
}
