enum 72349 "DOPSWHS Pick Mode"
{
    Extensible = true;

    // Terminaldeki toplama modu sekmeleri. Multi = ofiste birleştirilen çok
    // siparişli pick (ELOG multi); Bulk = aynı ürün çok siparişe bölünmüş;
    // Batch = tek ürünlük siparişler (mono-SKU). Boş = standart BC pick'i
    // (mod atanmamış) — "Tümü" görünümünde listelenir.
    value(0; " ") { Caption = ' '; }
    value(1; Multi) { Caption = 'Multi'; }
    value(2; Bulk) { Caption = 'Tek SKU'; }
    value(3; Batch) { Caption = 'Mono'; }
}
