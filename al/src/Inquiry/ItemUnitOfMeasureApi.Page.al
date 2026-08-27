page 72479 "DOPSWHS Item UOM API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'itemUnitOfMeasure';
    EntitySetName = 'itemUnitOfMeasures';
    SourceTable = "Item Unit of Measure";
    ODataKeyFields = "Item No.", Code;
    DelayedInsert = true;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(itemNo; Rec."Item No.") { Caption = 'itemNo'; }
                field(code; Rec.Code) { Caption = 'code'; }
                field(qtyPerUnitOfMeasure; Rec."Qty. per Unit of Measure")
                {
                    Caption = 'qtyPerUnitOfMeasure';
                }
            }
        }
    }
}
