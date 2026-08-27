page 72094 "DOPSWHS Shipment Line API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'shipmentLine';
    EntitySetName = 'shipmentLines';
    SourceTable = "Warehouse Shipment Line";
    DelayedInsert = true;
    ODataKeyFields = "No.", "Line No.";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(no; Rec."No.") { Caption = 'no'; Editable = false; }
                field(lineNo; Rec."Line No.") { Caption = 'lineNo'; Editable = false; }
                field(itemNo; Rec."Item No.") { Caption = 'itemNo'; Editable = false; }
                field(description; Rec.Description) { Caption = 'description'; Editable = false; }
                field(description2; Rec."Description 2") { Caption = 'description2'; Editable = false; }
                field(variantCode; Rec."Variant Code") { Caption = 'variantCode'; Editable = false; }
                field(gtin; ItemGtin) { Caption = 'gtin'; Editable = false; }
                field(qtyOutstanding; Rec."Qty. Outstanding") { Caption = 'qtyOutstanding'; Editable = false; }
                field(qtyToShip; Rec."Qty. to Ship") { Caption = 'qtyToShip'; }
                field(lotNo; LotNo) { Caption = 'lotNo'; }
                field(lotRequired; LotRequired) { Caption = 'lotRequired'; Editable = false; }
                field(licensePlateNo; Rec."LP No.") { Caption = 'licensePlateNo'; }
                field(sscc; Rec.SSCC) { Caption = 'sscc'; }
                field(uomCode; Rec."Unit of Measure Code") { Caption = 'uomCode'; Editable = false; }
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; Editable = false; }
                field(binCode; Rec."Bin Code") { Caption = 'binCode'; }
            }
        }
    }

    trigger OnOpenPage()
    var
        FilterMgmt: Codeunit "DOPSWHS App Role Filter Mgmt";
        RecRef: RecordRef;
    begin
        RecRef.GetTable(Rec);
        FilterMgmt.ApplyForCurrentUser(RecRef, Enum::"DOPSWHS App Filter Entity"::ShipmentLine);
        RecRef.SetTable(Rec);
    end;

    trigger OnAfterGetRecord()
    var
        Item: Record Item;
        ShipmentMgmt: Codeunit "DOPSWHS Shipment Mgmt";
    begin
        Clear(ItemGtin);
        if (Rec."Item No." <> '') and Item.Get(Rec."Item No.") then
            ItemGtin := Item.GTIN;
        ShipmentMgmt.GetShipmentLineLot(Rec, LotNo);
        LotRequired := ShipmentMgmt.ShipmentLineRequiresLot(Rec);
    end;

    trigger OnModifyRecord(): Boolean
    var
        ShipmentMgmt: Codeunit "DOPSWHS Shipment Mgmt";
    begin
        ShipmentMgmt.ConfirmShipmentLine(Rec, Rec."Qty. to Ship", LotNo, Rec."LP No.", Rec.SSCC);
        exit(false);
    end;

    var
        ItemGtin: Code[14];
        LotNo: Code[50];
        LotRequired: Boolean;
}
