page 72358 "DOPSWHS Picking Order API"
{
    // ELOG: terminal "Toplama Durumu / Geçmiş" dashboard'u için Picking Order
    // Header'ı okur. Sekmeler: Bekleyen (status=Open), Toplanmakta (Pick Created),
    // Benim Topladıklarım / Genel Toplananlar (Completed, assignedUserId ile filtre).
    // Zaman filtresi createdDateTime / completedDateTime üzerinden (OData ge/le).
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'pickingOrder';
    EntitySetName = 'pickingOrders';
    SourceTable = "DOPSWHS Picking Order Header";
    ODataKeyFields = "Entry No.";
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(entryNo; Rec."Entry No.") { Caption = 'entryNo'; }
                field(description; Rec.Description) { Caption = 'description'; }
                field(status; Rec.Status) { Caption = 'status'; }
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; }
                field(assignedUserId; Rec."Assigned User ID") { Caption = 'assignedUserId'; }
                field(createdByUser; Rec."Created By User") { Caption = 'createdByUser'; }
                field(warehousePickNo; Rec."Warehouse Pick No.") { Caption = 'warehousePickNo'; }
                field(warehouseShipmentNo; Rec."Warehouse Shipment No.") { Caption = 'warehouseShipmentNo'; }
                field(createdDateTime; Rec."Created DateTime") { Caption = 'createdDateTime'; }
                field(completedDateTime; Rec."Completed DateTime") { Caption = 'completedDateTime'; }
                field(orderCount; OrderCount) { Caption = 'orderCount'; }
            }
        }
    }

    trigger OnOpenPage()
    var
        FilterMgmt: Codeunit "DOPSWHS App Role Filter Mgmt";
        RecRef: RecordRef;
    begin
        RecRef.GetTable(Rec);
        FilterMgmt.ApplyForCurrentUser(RecRef, Enum::"DOPSWHS App Filter Entity"::Pick);
        RecRef.SetTable(Rec);
    end;

    trigger OnAfterGetRecord()
    var
        PickingLine: Record "DOPSWHS Picking Order Line";
    begin
        // Kaç satış siparişi bu toplama grubunda — dashboard kartında gösterilir.
        PickingLine.SetRange("Header Entry No.", Rec."Entry No.");
        OrderCount := PickingLine.Count();
    end;

    var
        OrderCount: Integer;
}
