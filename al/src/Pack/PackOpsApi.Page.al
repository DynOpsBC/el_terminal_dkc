page 72335 "DOPSWHS Pack Ops API"
{
    // Paketleme istasyonu operasyonları — MovementOps deseninde Setup-singleton
    // üzerinden koleksiyonsuz aksiyonlar:
    //   POST packOps('')/Microsoft.NAV.startSession   {"toteLpNo": "T-06-K2", "mode": "solo|bulk|batch"}
    //   POST packOps('')/Microsoft.NAV.setBox         {"sessionId": 1, "boxLpNo": "", "lpTemplateCode": "CARTON-S"}
    //   POST packOps('')/Microsoft.NAV.setBoxForOrder {"sessionId": 1, "orderNo": "SO-1001", "boxLpNo": "", "lpTemplateCode": ""}
    //   POST packOps('')/Microsoft.NAV.scanItem       {"sessionId": 1, "itemNo": "1000", "qty": 1}
    //   POST packOps('')/Microsoft.NAV.cancelSession  {"sessionId": 1}
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'packOp';
    EntitySetName = 'packOps';
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
            }
        }
    }

    [ServiceEnabled]
    procedure startSession(toteLpNo: Code[20]; mode: Text): Integer
    var
        PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
    begin
        exit(PackMgmt.StartSession(toteLpNo, mode));
    end;

    // ELOG "ürün-önce": bir PICK'in tüm siparişlerini tek session'da paketle.
    // userId dolu ise paketlemeyi üstlenen WMS operatörü olarak kaydedilir.
    [ServiceEnabled]
    procedure startPickPacking(pickNo: Code[20]; userId: Code[50]): Integer
    var
        PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
    begin
        exit(PackMgmt.StartPickSession(pickNo, userId));
    end;

    [ServiceEnabled]
    procedure startPickPackingWithPrinter(pickNo: Code[20]; userId: Code[50]; printerId: Code[50]): Integer
    var
        PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
    begin
        exit(PackMgmt.StartPickSession(pickNo, userId, printerId));
    end;

    // boxLpNo = okutulan KARGO KOLİSİ barkodu. Kayıtlı bir LP olmak zorunda
    // değildir (kargo etiketi / SSCC olabilir); boş gelirse sistem karton üretir.
    // Kargo barkodları 20 karakteri aşabildiğinden Code[50].
    [ServiceEnabled]
    procedure setBox(sessionId: Integer; boxLpNo: Code[50]; lpTemplateCode: Code[20]): Code[50]
    var
        PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
    begin
        exit(PackMgmt.SetBox(sessionId, boxLpNo, lpTemplateCode));
    end;

    // Bulk/batch: kutu sipariş başına — belirli siparişe kargo kolisi bağla.
    [ServiceEnabled]
    procedure setBoxForOrder(sessionId: Integer; orderNo: Code[20]; boxLpNo: Code[50]; lpTemplateCode: Code[20]): Code[50]
    var
        PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
    begin
        exit(PackMgmt.SetBoxForOrder(sessionId, orderNo, boxLpNo, lpTemplateCode));
    end;

    [ServiceEnabled]
    procedure scanItem(sessionId: Integer; itemNo: Code[20]; qty: Decimal): Text
    var
        PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
    begin
        exit(PackMgmt.ScanItem(sessionId, itemNo, qty));
    end;

    // ELOG "ürün-önce" öncelik: ürünü belirli (en az kalan) siparişe yaz.
    [ServiceEnabled]
    procedure scanItemForOrder(sessionId: Integer; orderNo: Code[20]; itemNo: Code[20]; qty: Decimal): Text
    var
        PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
    begin
        exit(PackMgmt.ScanItemForOrder(sessionId, orderNo, itemNo, qty));
    end;

    [ServiceEnabled]
    procedure cancelSession(sessionId: Integer)
    var
        PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
    begin
        PackMgmt.CancelSession(sessionId);
    end;
}
