page 72091 "DOPSWHS PutAway API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'putAway';
    EntitySetName = 'putAways';
    SourceTable = "Warehouse Activity Header";
    SourceTableView = where(Type = const("Put-away"));
    DelayedInsert = true;
    ODataKeyFields = "No.";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(no; Rec."No.") { Caption = 'no'; }
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; }
                field(assignedUserId; Rec."Assigned User ID") { Caption = 'assignedUserId'; }
                // TODO Sprint H+ post-deploy: bind to activity status if exposed by the target BC app.
                field(status; StatusText) { Caption = 'status'; }
                part(lines; "DOPSWHS PutAway Line API")
                {
                    Caption = 'lines';
                    EntityName = 'putAwayLine';
                    EntitySetName = 'putAwayLines';
                    SubPageLink = "Activity Type" = field(Type), "No." = field("No.");
                }
            }
        }
    }

    trigger OnOpenPage()
    var
        FilterMgmt: Codeunit "DOPSWHS App Role Filter Mgmt";
        RecRef: RecordRef;
    begin
        RecRef.GetTable(Rec);
        FilterMgmt.ApplyForCurrentUser(RecRef, Enum::"DOPSWHS App Filter Entity"::PutAway);
        RecRef.SetTable(Rec);
    end;

    [ServiceEnabled]
    procedure suggestBin(itemNo: Code[20]; qty: Decimal; locationCode: Code[10]): Code[20]
    var
        DirectedPutAway: Codeunit "DOPSWHS Directed PutAway";
        Item: Record Item;
        EffectiveLocationCode: Code[10];
        BinCode: Code[20];
        Reason: Text;
    begin
        Item.Get(itemNo);
        EffectiveLocationCode := locationCode;
        if EffectiveLocationCode = '' then
            EffectiveLocationCode := Rec."Location Code";
        if not DirectedPutAway.SuggestBin(Item, qty, EffectiveLocationCode, BinCode, Reason) then
            Error(Reason);
        exit(BinCode);
    end;

    [ServiceEnabled]
    procedure register()
    var
        MovementMgmt: Codeunit "DOPSWHS Movement Mgmt";
    begin
        MovementMgmt.RegisterDirected(Rec);
    end;

    [ServiceEnabled]
    procedure assignToMe(userId: Code[50])
    var
        LockedPutAway: Record "Warehouse Activity Header";
        CurrentOwner: Code[50];
    begin
        if userId = '' then
            Error('WMS kullanıcı kimliği boş olamaz. Terminal oturumunu yenileyin.');

        // Aynı belgeyi iki terminal eş zamanlı üstlenirse son yazanın kazanmasını
        // önle. Yalnızca boşta olan belge veya zaten aynı kullanıcıdaki belge
        // üstlenilebilir; başka operatördeki belge terminalden devralınamaz.
        LockedPutAway.LockTable();
        if not LockedPutAway.Get(LockedPutAway.Type::"Put-away", Rec."No.") then
            Error('Yerleştirme belgesi %1 artık bulunamıyor. Listeyi yenileyin.', Rec."No.");

        CurrentOwner := LockedPutAway."Assigned User ID";
        if (CurrentOwner <> '') and (CurrentOwner <> userId) then
            Error('Yerleştirme belgesi %1, %2 kullanıcısına atanmış.', Rec."No.", CurrentOwner);

        if CurrentOwner = userId then begin
            Rec := LockedPutAway;
            exit;
        end;

        // WMS yerel kullanıcısı her kurulumda Warehouse Employee tablosunda
        // bulunmayabilir. Pick self-claim ile aynı nedenle TableRelation
        // doğrulaması tetiklenmeden operatör kimliğini kalıcı yaz.
        LockedPutAway."Assigned User ID" := CopyStr(userId, 1, MaxStrLen(LockedPutAway."Assigned User ID"));
        LockedPutAway.Modify(true);
        Rec := LockedPutAway;
    end;

    var
        StatusText: Text[30];
}
