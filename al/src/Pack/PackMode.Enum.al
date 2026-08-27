enum 72343 "DOPSWHS Pack Mode"
{
    Extensible = true;

    // ELOG akışları: önce toplama LP'si doğrulanır, sonra ürünler okutulur;
    // siparişin ürünleri bitince koli bağlanır ve fiş/fatura süreci çalışır.
    value(0; Solo) { Caption = 'Solo'; }
    value(1; Bulk) { Caption = 'Bulk'; }
    value(2; Batch) { Caption = 'Batch'; }
}
