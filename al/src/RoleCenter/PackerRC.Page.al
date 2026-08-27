page 72347 "DOPSWHS Packer RC"
{
    // Sipariş bazlı paketleme rolü. Eski Bulk/Batch/Mono-SKU ayrımı kaldırıldı;
    // paketleyici hazır siparişi seçer ve eksik (kırmızı) satırları okutur.
    Caption = 'Packer';
    PageType = RoleCenter;
    ApplicationArea = All;

    layout
    {
        area(RoleCenter)
        {
            part(Activities; "DOPSWHS Packer Activities")
            {
                ApplicationArea = All;
            }
        }
    }

    actions
    {
        area(Embedding)
        {
            action(OrderPacking)
            {
                Caption = 'Sipariş Paketleme';
                ApplicationArea = All;
                RunObject = page "DOPSWHS Packing Order List";
            }
        }
        area(Sections)
        {
            group(Packing)
            {
                Caption = 'Packing';
                action(OrderPackingNav) { Caption = 'Sipariş Paketleme'; ApplicationArea = All; RunObject = page "DOPSWHS Packing Order List"; }
                action(PackSessions) { Caption = 'Pack Sessions (All)'; ApplicationArea = All; RunObject = page "DOPSWHS Pack Session List"; }
            }
        }
    }
}
