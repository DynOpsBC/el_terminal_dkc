page 72231 "DOPSWHS Movement Ops API"
{
    // Hosts collection-less warehouse movement operations (e.g. ad-hoc bin-to-bin moves) that have
    // no pre-existing document to bind to. Bound to the singleton "DOPSWHS Setup" record (key '')
    // so the mobile app can invoke the action with a stable, always-present key:
    //   POST movementOps('')/Microsoft.NAV.adHoc
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'movementOp';
    EntitySetName = 'movementOps';
    SourceTable = "DOPSWHS Setup";
    ODataKeyFields = "Primary Key";
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
                field(primaryKey; Rec."Primary Key") { Caption = 'primaryKey'; Editable = false; }
                // Mobil için global toggle'lar bu Setup-singleton üzerinden okunur.
                // (Sipariş bazlı sevkiyat sekmesi terminalde gösterilsin mi?)
                field(showSoShipment; Rec."Show SO Shipment Mobile") { Caption = 'showSoShipment'; Editable = false; }
                field(hierarchicalLpEnabled; Rec."Hierarchical LP Enabled") { Caption = 'hierarchicalLpEnabled'; Editable = false; }
            }
        }
    }

    [ServiceEnabled]
    procedure adHoc(fromBin: Code[20]; toBin: Code[20]; itemNo: Code[20]; lpNo: Code[20]; qty: Decimal; userId: Code[50])
    var
        MovementMgmt: Codeunit "DOPSWHS Movement Mgmt";
    begin
        MovementMgmt.AdHocMove(fromBin, toBin, itemNo, lpNo, qty, userId);
    end;

    // Lot izlemeli ürünler için: reclass satırına lot tracking bağlanır
    // ("You must assign a lot number" hatasının çözümü). Ayrı action olarak
    // eklendi ki eski APK'ların adHoc çağrıları kırılmasın.
    [ServiceEnabled]
    procedure adHocLot(fromBin: Code[20]; toBin: Code[20]; itemNo: Code[20]; lpNo: Code[20]; qty: Decimal; userId: Code[50]; lotNo: Code[50])
    var
        MovementMgmt: Codeunit "DOPSWHS Movement Mgmt";
    begin
        MovementMgmt.AdHocMove(fromBin, toBin, itemNo, lpNo, qty, userId, lotNo);
    end;
}
