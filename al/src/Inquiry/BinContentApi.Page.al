page 72097 "DOPSWHS Bin Content API"
{
    // PDF Bin Inquiry §2 fix: standalone API page over the BC standard
    // Bin Content table (T7302) so the mobile / web Bin Inquiry can render
    // real item quantities per bin (not just LPs). Avoids a second roundtrip
    // for the most common warehouse question — "this bin has how much of X".
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'binContent';
    EntitySetName = 'binContents';
    SourceTable = "Bin Content";
    DelayedInsert = true;
    ApplicationArea = All;
    Editable = false;
    ODataKeyFields = "Location Code", "Bin Code", "Item No.", "Variant Code", "Unit of Measure Code";

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; Editable = false; }
                field(binCode; Rec."Bin Code") { Caption = 'binCode'; Editable = false; }
                field(itemNo; Rec."Item No.") { Caption = 'itemNo'; Editable = false; }
                field(variantCode; Rec."Variant Code") { Caption = 'variantCode'; Editable = false; }
                field(unitOfMeasureCode; Rec."Unit of Measure Code") { Caption = 'unitOfMeasureCode'; Editable = false; }
                field(quantity; Rec.Quantity)
                {
                    Caption = 'quantity';
                    Editable = false;
                    trigger OnAfterLookup(Selected: RecordRef)
                    begin
                        // FlowField — calculated on access.
                        Rec.CalcFields(Quantity);
                    end;
                }
                field(itemDescription; ItemDescription) { Caption = 'itemDescription'; Editable = false; }
                field(zoneCode; Rec."Zone Code") { Caption = 'zoneCode'; Editable = false; }
                field(binTypeCode; Rec."Bin Type Code") { Caption = 'binTypeCode'; Editable = false; }
                field(qtyBaseUoM; Rec."Quantity (Base)")
                {
                    Caption = 'qtyBaseUoM';
                    Editable = false;
                }
                field(blockMovement; Rec."Block Movement") { Caption = 'blockMovement'; Editable = false; }
                field(activeLpNos; ActiveLpNos) { Caption = 'activeLpNos'; Editable = false; }
                field(activeLpQuantity; ActiveLpQuantity) { Caption = 'activeLpQuantity'; Editable = false; }
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        Item: Record Item;
        BinContentSubscriber: Codeunit "DOPSWHS Bin Content Subscriber";
    begin
        // Ensure the FlowField is calculated before serialization.
        Rec.CalcFields(Quantity, "Quantity (Base)");
        // Bin Content (T7302) has no Description column — resolve it from Item.
        if Item.Get(Rec."Item No.") then
            ItemDescription := Item.Description
        else
            ItemDescription := '';
        BinContentSubscriber.GetActiveLPItemInfo(
            Rec."Location Code", Rec."Bin Code", Rec."Item No.", Rec."Variant Code", Rec."Unit of Measure Code",
            ActiveLpNos, ActiveLpQuantity);
    end;

    var
        ItemDescription: Text[100];
        ActiveLpNos: Text[250];
        ActiveLpQuantity: Decimal;
}
