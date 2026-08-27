enum 72205 "DOPSWHS IWX Report Usage"
{
    Extensible = true;

    value(0; LpLabel) { Caption = 'LP Label'; }
    value(1; Receipt) { Caption = 'Receipt'; }
    value(2; Pick) { Caption = 'Pick'; }
    value(3; Ship) { Caption = 'Ship'; }
    value(4; Item) { Caption = 'Item'; }
    value(5; Bin) { Caption = 'Bin'; }
    value(6; PostedShipment) { Caption = 'Posted Shipment'; }
    value(7; Custom1) { Caption = 'Custom 1'; }
    value(8; Custom2) { Caption = 'Custom 2'; }
    value(9; Custom3) { Caption = 'Custom 3'; }
    // ELOG: paketleme istasyonunda sipariş tamamlanınca basılan fiş/fatura.
    value(10; PackReceipt) { Caption = 'Pack Receipt'; }
}
