page 72293 "DOPSWHS Purch Source Line API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'purchaseSourceLine';
    EntitySetName = 'purchaseSourceLines';
    SourceTable = "Purchase Line";
    SourceTableView = where("Document Type" = const(Order));
    DelayedInsert = true;
    ODataKeyFields = "Document Type", "Document No.", "Line No.";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(documentType; Rec."Document Type") { Caption = 'documentType'; Editable = false; }
                field(no; Rec."Document No.") { Caption = 'no'; Editable = false; }
                field(lineNo; Rec."Line No.") { Caption = 'lineNo'; Editable = false; }
                field(type; Rec.Type) { Caption = 'type'; Editable = false; }
                field(itemNo; Rec."No.") { Caption = 'itemNo'; Editable = false; }
                field(description; Rec.Description) { Caption = 'description'; Editable = false; }
                field(description2; Rec."Description 2") { Caption = 'description2'; Editable = false; }
                field(variantCode; Rec."Variant Code") { Caption = 'variantCode'; Editable = false; }
                field(itemReference; Rec."Item Reference No.") { Caption = 'itemReference'; Editable = false; }
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; Editable = false; }
                field(binCode; Rec."Bin Code") { Caption = 'binCode'; }
                field(quantity; Rec.Quantity) { Caption = 'quantity'; Editable = false; }
                field(outstandingQuantity; Rec."Outstanding Quantity") { Caption = 'outstandingQuantity'; Editable = false; }
                field(qtyReceived; Rec."Quantity Received") { Caption = 'qtyReceived'; Editable = false; }
                field(qtyToReceive; Rec."Qty. to Receive") { Caption = 'qtyToReceive'; }
                field(unitOfMeasureCode; Rec."Unit of Measure Code") { Caption = 'unitOfMeasureCode'; Editable = false; }
                field(directUnitCost; Rec."Direct Unit Cost") { Caption = 'directUnitCost'; Editable = false; }
                field(lotRequired; LotRequired) { Caption = 'lotRequired'; Editable = false; }
                field(serialRequired; SerialRequired) { Caption = 'serialRequired'; Editable = false; }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        ResolveTrackingRequirements();
    end;

    local procedure ResolveTrackingRequirements()
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        Clear(LotRequired);
        Clear(SerialRequired);
        if Rec.Type <> Rec.Type::Item then
            exit;
        if not Item.Get(Rec."No.") then
            exit;
        if (Item."Item Tracking Code" = '') or (not ItemTrackingCode.Get(Item."Item Tracking Code")) then
            exit;

        LotRequired :=
            ItemTrackingCode."Lot Specific Tracking" or
            ItemTrackingCode."Lot Warehouse Tracking" or
            ItemTrackingCode."Lot Purchase Inbound Tracking";
        SerialRequired :=
            ItemTrackingCode."SN Specific Tracking" or
            ItemTrackingCode."SN Warehouse Tracking" or
            ItemTrackingCode."SN Purchase Inbound Tracking";
    end;

    var
        LotRequired: Boolean;
        SerialRequired: Boolean;
}
