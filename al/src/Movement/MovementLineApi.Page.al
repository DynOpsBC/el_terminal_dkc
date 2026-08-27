page 72350 "DOPSWHS Movement Line API"
{
    // Movement Worksheet'ten oluşturulan Warehouse Movement belgelerinin
    // satırları — terminaldeki "Yönlendirilmiş Hareket" ekranı satırları
    // buradan listeler, qtyToHandle'ı PATCH'ler, sonra movements.register
    // ile belgeyi kaydeder (PickLineApi 72229 deseni).
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'movementLine';
    EntitySetName = 'movementLines';
    SourceTable = "Warehouse Activity Line";
    SourceTableView = where("Activity Type" = const(Movement));
    DelayedInsert = true;
    ODataKeyFields = "Activity Type", "No.", "Line No.";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(activityType; Rec."Activity Type") { Caption = 'activityType'; Editable = false; }
                field(no; Rec."No.") { Caption = 'no'; Editable = false; }
                field(lineNo; Rec."Line No.") { Caption = 'lineNo'; Editable = false; }
                field(actionType; Rec."Action Type") { Caption = 'actionType'; Editable = false; }
                field(itemNo; Rec."Item No.") { Caption = 'itemNo'; Editable = false; }
                field(description; Rec.Description) { Caption = 'description'; Editable = false; }
                field(unitOfMeasureCode; Rec."Unit of Measure Code") { Caption = 'unitOfMeasureCode'; Editable = false; }
                field(variantCode; Rec."Variant Code") { Caption = 'variantCode'; Editable = false; }
                field(gtin; ItemGtin) { Caption = 'gtin'; Editable = false; }
                field(quantity; Rec.Quantity) { Caption = 'quantity'; Editable = false; }
                field(qtyOutstanding; Rec."Qty. Outstanding") { Caption = 'qtyOutstanding'; Editable = false; }
                field(qtyToHandle; Rec."Qty. to Handle") { Caption = 'qtyToHandle'; }
                field(qtyHandled; Rec."Qty. Handled") { Caption = 'qtyHandled'; Editable = false; }
                field(binCode; Rec."Bin Code") { Caption = 'binCode'; }
                field(lotNo; Rec."Lot No.") { Caption = 'lotNo'; Editable = false; }
                field(lotRequired; LotRequired) { Caption = 'lotRequired'; Editable = false; }
                field(serialNo; Rec."Serial No.") { Caption = 'serialNo'; Editable = false; }
                field(serialRequired; SerialRequired) { Caption = 'serialRequired'; Editable = false; }
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; Editable = false; }
                field(licensePlateNo; Rec."LP No.") { Caption = 'licensePlateNo'; }
            }
        }
    }

    trigger OnOpenPage()
    var
        FilterMgmt: Codeunit "DOPSWHS App Role Filter Mgmt";
        RecRef: RecordRef;
    begin
        RecRef.GetTable(Rec);
        FilterMgmt.ApplyForCurrentUser(RecRef, Enum::"DOPSWHS App Filter Entity"::Movement);
        RecRef.SetTable(Rec);
    end;

    trigger OnAfterGetRecord()
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        Clear(ItemGtin);
        Clear(LotRequired);
        Clear(SerialRequired);
        if (Rec."Item No." <> '') and Item.Get(Rec."Item No.") then begin
            ItemGtin := Item.GTIN;
            if (Item."Item Tracking Code" <> '') and ItemTrackingCode.Get(Item."Item Tracking Code") then begin
                LotRequired :=
                    ItemTrackingCode."Lot Specific Tracking" or
                    ItemTrackingCode."Lot Warehouse Tracking";
                SerialRequired :=
                    ItemTrackingCode."SN Specific Tracking" or
                    ItemTrackingCode."SN Warehouse Tracking";
            end;
        end;
    end;

    var
        ItemGtin: Code[14];
        LotRequired: Boolean;
        SerialRequired: Boolean;
}
