page 72092 "DOPSWHS Pick API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'pick';
    EntitySetName = 'picks';
    SourceTable = "Warehouse Activity Header";
    SourceTableView = where(Type = const(Pick));
    DelayedInsert = true;
    ODataKeyFields = "No.";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(no; Rec."No.") { Caption = 'no'; Editable = false; }
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; Editable = false; }
                // SALT-OKUNUR: atama yalnızca claim/assignToMe (kural kontrollü) ya da
                // forceReassign (yönetici) uçlarından değişir. Alan yazılabilir kalsaydı
                // PATCH ile başkasının üstündeki toplama sessizce devralınabilirdi —
                // eş zamanlılık kontrollerinin tamamı atlanmış olurdu.
                field(assignedUserId; Rec."Assigned User ID") { Caption = 'assignedUserId'; Editable = false; }
                field(pickMode; Rec."DOPSWHS Pick Mode") { Caption = 'pickMode'; Editable = false; }
                // ELOG: araç bilgisini sorumlu masadan girer; terminal salt-okunur gösterir.
                field(vehicleNo; Rec."DOPSWHS Vehicle No.") { Caption = 'vehicleNo'; Editable = false; }
                // Ana sepet: terminal toplamaya başlarken PATCH'ler; ekrandan
                // çıkıp girince kaybolmasın diye kalıcı. Paketleme de okur.
                field(mainLpNo; Rec."DOPSWHS Main LP No.") { Caption = 'mainLpNo'; }
                field(sourceNo; SourceNo) { Caption = 'sourceNo'; }
                field(status; StatusText) { Caption = 'status'; }
                field(dueDate; DueDate) { Caption = 'dueDate'; }
                field(percentComplete; PercentComplete) { Caption = 'percentComplete'; }
                part(lines; "DOPSWHS Pick Line API")
                {
                    Caption = 'lines';
                    EntityName = 'pickLine';
                    EntitySetName = 'pickLines';
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
        FilterMgmt.ApplyForCurrentUser(RecRef, Enum::"DOPSWHS App Filter Entity"::Pick);
        RecRef.SetTable(Rec);
    end;

    trigger OnAfterGetRecord()
    begin
        FillCalculatedFields();
    end;

    [ServiceEnabled]
    procedure assignToMe()
    var
        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
    begin
        PickMgmt.AssignToMe(Rec);
    end;

    /// <summary>
    /// Terminaldeki "Üzerime Al" — WMS oturumundaki operatör kendi adına üstlenir.
    /// Toplama başka bir operatördeyse reddedilir (bkz. PickMgmt.ClaimPick).
    /// </summary>
    [ServiceEnabled]
    procedure claim(userId: Code[50])
    var
        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
    begin
        PickMgmt.ClaimPick(Rec, userId, ClaimReasonLbl);
    end;

    [ServiceEnabled]
    procedure startShippingLP(lpTemplateCode: Code[20]): Code[20]
    var
        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
    begin
        // Sevk LP'si açmak toplamanın parçası: belge bu operatörde olmalı.
        // (StartShippingLP masadaki Warehouse Pick kartından da çağrıldığı için
        // kontrol codeunit'e değil, terminale bakan bu uca konuldu.)
        PickMgmt.EnsurePickOperator(Rec);
        exit(PickMgmt.StartShippingLP(Rec, lpTemplateCode));
    end;

    [ServiceEnabled]
    procedure stopShippingLP(lpNo: Code[20]; printLabel: Boolean): Code[18]
    var
        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
    begin
        PickMgmt.EnsurePickOperator(Rec);
        exit(PickMgmt.StopShippingLP(Rec, lpNo, printLabel));
    end;

    [ServiceEnabled]
    procedure stopShippingLPToPrinter(lpNo: Code[20]; printLabel: Boolean; printerId: Code[50]): Code[18]
    var
        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
    begin
        PickMgmt.EnsurePickOperator(Rec);
        exit(PickMgmt.StopShippingLP(Rec, lpNo, printLabel, printerId));
    end;

    [ServiceEnabled]
    procedure markShort(lineNo: Integer; qty: Decimal; reasonCode: Code[20])
    var
        PickLine: Record "Warehouse Activity Line";
        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
    begin
        PickLine.Get(Rec.Type, Rec."No.", lineNo);
        PickMgmt.RegisterShortPick(PickLine, qty, reasonCode);
    end;

    /// <summary>
    /// Satır onayı — operatör kimliğiyle. Paylaşımlı BC hesabında sahipliği kesin
    /// doğrulayan tek yol budur (pickLines PATCH yolu kimlik taşımaz).
    /// </summary>
    [ServiceEnabled]
    procedure confirmLine(lineNo: Integer; qtyToHandle: Decimal; lotNo: Code[50]; userId: Code[50])
    var
        PickLine: Record "Warehouse Activity Line";
        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
    begin
        PickLine.Get(Rec.Type, Rec."No.", lineNo);
        PickMgmt.ConfirmPickLineFor(PickLine, qtyToHandle, lotNo, userId);
    end;

    [ServiceEnabled]
    procedure register()
    var
        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
    begin
        PickMgmt.RegisterPick(Rec);
    end;

    /// <summary>
    /// Terminalin kullanması gereken strict kayıt yolu. userId WMS oturumundaki
    /// operatördür; shared BC hesabıyla yanlış operatör adına register engellenir.
    /// </summary>
    [ServiceEnabled]
    procedure registerFor(userId: Code[50])
    var
        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
    begin
        PickMgmt.RegisterPickFor(Rec, userId);
    end;

    /// <summary>
    /// Terminal bu ucu YALNIZCA kendine atama için çağırır ("Bana Ata"/"Üzerine Al",
    /// userId = oturumdaki operatör). Bu yüzden zorla devretme değil, kural
    /// kontrollü üstlenme (ClaimPick) çalıştırılır: belge başkasındaysa reddedilir.
    /// Zorla devretme masa tarafındadır (Warehouse Pick kartı, Toplanacak
    /// Siparişler, Pick Board) ve API'de forceReassign ucundan yapılır.
    /// </summary>
    [ServiceEnabled]
    procedure reassign(userId: Code[50]; reason: Text[250])
    var
        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
    begin
        PickMgmt.ClaimPick(Rec, userId, reason);
    end;

    /// <summary>Yönetici yolu: belgeyi başka bir operatörden zorla devralır/devreder.</summary>
    [ServiceEnabled]
    procedure forceReassign(userId: Code[50]; reason: Text[250])
    var
        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
    begin
        PickMgmt.ReassignPick(Rec, userId, reason);
    end;

    // ELOG: sipariş başına tote (sepet) bağlama — bkz. "DOPSWHS Pick Tote Assignment".
    // Sahiplik kontrolü PickMgmt.AssignTote içinde (EnsurePickOperator).
    [ServiceEnabled]
    procedure assignTote(sourceOrderNo: Code[20]; lpNo: Code[20])
    var
        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
    begin
        PickMgmt.AssignTote(Rec, sourceOrderNo, lpNo);
    end;

    [ServiceEnabled]
    procedure toteForOrder(sourceOrderNo: Code[20]): Code[20]
    var
        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
    begin
        exit(PickMgmt.GetToteForOrder(Rec."No.", sourceOrderNo));
    end;

    var
        SourceNo: Code[20];
        DueDate: Date;
        PercentComplete: Decimal;
        StatusText: Text[30];
        ClaimReasonLbl: Label 'Terminalden üzerine alındı.';

    local procedure FillCalculatedFields()
    var
        PickLine: Record "Warehouse Activity Line";
        TotalQty: Decimal;
        HandledQty: Decimal;
    begin
        Clear(SourceNo);
        Clear(DueDate);
        Clear(PercentComplete);
        Clear(StatusText);

        PickLine.SetRange("Activity Type", Rec.Type);
        PickLine.SetRange("No.", Rec."No.");
        PickLine.SetRange("Action Type", PickLine."Action Type"::Take);
        if PickLine.FindSet() then
            repeat
                if SourceNo = '' then begin
                    SourceNo := PickLine."Source No.";
                    DueDate := PickLine."Due Date";
                end;
                TotalQty += PickLine.Quantity;
                HandledQty += PickLine."Qty. to Handle";
            until PickLine.Next() = 0;

        if TotalQty > 0 then begin
            PercentComplete := Round(HandledQty / TotalQty * 100, 1);
            if PercentComplete > 100 then
                PercentComplete := 100;
        end;

        // Warehouse Activity Header has no lifecycle status that maps cleanly
        // to the handheld contract. Derive the stable API values from the
        // actual Take-line progress and assignment instead of returning blank.
        if (TotalQty > 0) and (HandledQty >= TotalQty) then
            StatusText := 'Done'
        else
            if (HandledQty > 0) or (Rec."Assigned User ID" <> '') then
                StatusText := 'InProgress'
            else
                StatusText := 'Open';
    end;
}
