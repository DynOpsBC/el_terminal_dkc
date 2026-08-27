page 72336 "DOPSWHS Pack Session API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'packSession';
    EntitySetName = 'packSessions';
    SourceTable = "DOPSWHS Pack Session";
    DelayedInsert = true;
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
                field(entryNo; Rec."Entry No.") { Caption = 'entryNo'; Editable = false; }
                field(toteLpNo; Rec."Tote LP No.") { Caption = 'toteLpNo'; Editable = false; }
                field(boxLpNo; Rec."Box LP No.") { Caption = 'boxLpNo'; Editable = false; }
                field(pickNo; Rec."Pick No.") { Caption = 'pickNo'; Editable = false; }
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; Editable = false; }
                field(status; Rec.Status) { Caption = 'status'; Editable = false; }
                field(mode; Rec.Mode) { Caption = 'mode'; Editable = false; }
                field(ordersTotal; Rec."Orders Total") { Caption = 'ordersTotal'; Editable = false; }
                field(ordersCompleted; Rec."Orders Completed") { Caption = 'ordersCompleted'; Editable = false; }
                field(directOrderPacking; Rec."Direct Order Packing") { Caption = 'directOrderPacking'; Editable = false; }
                field(createdBy; Rec."Created By User") { Caption = 'createdBy'; Editable = false; }
            }
        }
    }
}
