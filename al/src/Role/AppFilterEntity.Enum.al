enum 72270 "DOPSWHS App Filter Entity"
{
    // Identifies the WMS API entity that a role-based filter rule applies to. Extensible so
    // future entities can plug in without touching the helper codeunit.
    Caption = 'App Filter Entity';
    Extensible = true;
    AssignmentCompatibility = true;

    value(0;  "None")               { Caption = 'None'; }
    value(10; "LicensePlate")       { Caption = 'License Plate'; }
    value(11; "LicensePlateLine")   { Caption = 'License Plate Line'; }
    value(20; "Receipt")            { Caption = 'Warehouse Receipt'; }
    value(21; "ReceiptLine")        { Caption = 'Warehouse Receipt Line'; }
    value(30; "PutAway")            { Caption = 'Put-Away'; }
    value(31; "PutAwayLine")        { Caption = 'Put-Away Line'; }
    value(40; "Pick")               { Caption = 'Pick'; }
    value(41; "PickLine")           { Caption = 'Pick Line'; }
    value(50; "Shipment")           { Caption = 'Warehouse Shipment'; }
    value(51; "ShipmentLine")       { Caption = 'Warehouse Shipment Line'; }
    value(60; "Movement")           { Caption = 'Movement'; }
    value(70; "CountSheet")         { Caption = 'Count Sheet'; }
    value(71; "CountSheetLine")     { Caption = 'Count Sheet Line'; }
    value(80; "QualityOrder")       { Caption = 'Quality Order'; }
    value(90; "ProductionConsumption") { Caption = 'Production Consumption'; }
    value(91; "ProductionOutput")   { Caption = 'Production Output'; }
    value(100; "Assembly")          { Caption = 'Assembly'; }
    value(101; "AssemblyLine")      { Caption = 'Assembly Line'; }
}
