query 72485 "DOPSWHS Available Lot API"
{
    QueryType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'availableLot';
    EntitySetName = 'availableLots';
    DataAccessIntent = ReadOnly;

    elements
    {
        dataitem(WarehouseEntry; "Warehouse Entry")
        {
            column(itemNo; "Item No.") { Caption = 'itemNo'; }
            column(variantCode; "Variant Code") { Caption = 'variantCode'; }
            column(locationCode; "Location Code") { Caption = 'locationCode'; }
            column(binCode; "Bin Code") { Caption = 'binCode'; }
            column(lotNo; "Lot No.") { Caption = 'lotNo'; }
            column(unitOfMeasureCode; "Unit of Measure Code") { Caption = 'unitOfMeasureCode'; }
            column(quantity; Quantity)
            {
                Caption = 'quantity';
                Method = Sum;
            }
            column(quantityBase; "Qty. (Base)")
            {
                Caption = 'quantityBase';
                Method = Sum;
            }
        }
    }
}
