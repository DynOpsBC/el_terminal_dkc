codeunit 72258 "DOPSWHS Board Data"
{
    // Builds the JSON payloads the web SPAs (Pick Board, LP Browser) consume, and exposes the
    // mutating helpers their drag-drop / context actions call back into.
    Access = Public;

    /// <summary>
    /// Pick Board payload. `users` intentionally contains every enabled local
    /// WMS operator, including operators who currently have no pick. Without
    /// this list an empty operator column could never be a drag/drop target.
    /// </summary>
    procedure BuildPickBoardJson(): Text
    var
        Pick: Record "Warehouse Activity Header";
        Json: TextBuilder;
        First: Boolean;
    begin
        Json.Append('{"users":');
        Json.Append(BuildPickBoardUsersJson());
        Json.Append(',"picks":[');
        First := true;
        Pick.SetRange(Type, Pick.Type::Pick);
        if Pick.FindSet() then
            repeat
                if not First then Json.Append(',');
                First := false;
                Json.Append(BuildPickObject(Pick));
            until Pick.Next() = 0;
        Json.Append(']}');
        exit(Json.ToText());
    end;

    local procedure BuildPickBoardUsersJson(): Text
    var
        LocalUser: Record "DOPSWHS Local User";
        Json: TextBuilder;
        First: Boolean;
    begin
        Json.Append('[');
        First := true;
        LocalUser.SetRange(Disabled, false);
        if LocalUser.FindSet() then
            repeat
                if LocalUser.Username <> '' then begin
                    if not First then
                        Json.Append(',');
                    First := false;
                    Json.Append(StrSubstNo('"%1"', Esc(LocalUser.Username)));
                end;
            until LocalUser.Next() = 0;
        Json.Append(']');
        exit(Json.ToText());
    end;

    local procedure BuildPickObject(var Pick: Record "Warehouse Activity Header"): Text
    var
        PickLine: Record "Warehouse Activity Line";
        SourceNo: Code[20];
        DueDate: Date;
        TotalQty: Decimal;
        HandledQty: Decimal;
        Pct: Integer;
        StatusText: Text;
    begin
        PickLine.SetRange("Activity Type", Pick.Type);
        PickLine.SetRange("No.", Pick."No.");
        if PickLine.FindSet() then
            repeat
                if SourceNo = '' then begin
                    SourceNo := PickLine."Source No.";
                    DueDate := PickLine."Due Date";
                end;
                TotalQty += PickLine.Quantity;
                HandledQty += PickLine."Qty. Handled";
            until PickLine.Next() = 0;
        if TotalQty <> 0 then
            Pct := Round(HandledQty / TotalQty * 100, 1);
        if Pick."Assigned User ID" = '' then StatusText := 'Open'
        else if Pct >= 100 then StatusText := 'Done'
        else if Pct > 0 then StatusText := 'InProgress'
        else StatusText := 'Open';

        exit(StrSubstNo(
            '{"no":"%1","sourceNo":"%2","assignedUserId":"%3","status":"%4","percentComplete":%5,"dueDate":"%6"}',
            Esc(Pick."No."), Esc(SourceNo), Esc(Pick."Assigned User ID"), StatusText, Pct,
            Format(DueDate, 0, '<Year4>-<Month,2>-<Day,2>')));
    end;

    /// <summary>Flat LP array (the SPA nests by parentLpNo): {"value":[{no,parentLpNo,binCode,status}]}.</summary>
    procedure BuildLpTreeJson(): Text
    var
        LP: Record "DOPSWHS LP Header";
        Json: TextBuilder;
        First: Boolean;
    begin
        Json.Append('{"value":[');
        First := true;
        LP.SetCurrentKey("No.");
        if LP.FindSet() then
            repeat
                if not First then Json.Append(',');
                First := false;
                Json.Append(StrSubstNo(
                    '{"no":"%1","parentLpNo":"%2","binCode":"%3","status":"%4"}',
                    Esc(LP."No."), Esc(LP."Parent LP No."), Esc(LP."Bin Code"), Format(LP.Status)));
            until LP.Next() = 0;
        Json.Append(']}');
        exit(Json.ToText());
    end;

    /// <summary>LP Browser "Move to Bin": update the LP's bin (simple bin move).</summary>
    procedure MoveLpToBin(LpNo: Code[20]; BinCode: Code[20])
    var
        LP: Record "DOPSWHS LP Header";
    begin
        if not LP.Get(LpNo) then exit;
        LP.Validate("Bin Code", BinCode);
        LP."Last Modified DateTime" := CurrentDateTime();
        LP.Modify(true);
    end;

    /// <summary>LP Browser drag-nest: nest child LP under parent via the Nest Manager.</summary>
    procedure NestLp(ChildLpNo: Code[20]; ParentLpNo: Code[20])
    var
        ChildLP: Record "DOPSWHS LP Header";
        ParentLP: Record "DOPSWHS LP Header";
        NestMgr: Codeunit "DOPSWHS LP Nest Manager";
    begin
        if not ChildLP.Get(ChildLpNo) then exit;
        if not ParentLP.Get(ParentLpNo) then exit;
        NestMgr.Nest(ChildLP, ParentLP);
    end;

    /// <summary>LP Browser print action.</summary>
    procedure PrintLpLabel(LpNo: Code[20]; PrinterId: Code[50])
    var
        LP: Record "DOPSWHS LP Header";
        Dispatcher: Codeunit "DOPSWHS Print Dispatcher";
    begin
        if not LP.Get(LpNo) then exit;
        Dispatcher.PrintLPLabel(LP, PrinterId, 1);
    end;

    // ===================== Ops Console (yönetim konsolu) =====================

    /// <summary>Ops Console payload: özet sayaçlar + kullanıcılar + tür bazlı belgeler.</summary>
    procedure BuildOpsConsoleJson(): Text
    var
        Json: TextBuilder;
    begin
        Json.Append('{"summary":');
        Json.Append(BuildSummaryJson());
        Json.Append(',"users":');
        Json.Append(BuildUsersJson());
        Json.Append(',"docs":{');
        Json.Append('"pick":[' + BuildActivityDocs(Enum::"Warehouse Activity Type"::Pick) + '],');
        Json.Append('"putaway":[' + BuildActivityDocs(Enum::"Warehouse Activity Type"::"Put-away") + '],');
        Json.Append('"shipment":[' + BuildShipmentDocs() + '],');
        Json.Append('"count":[' + BuildCountDocs() + ']');
        Json.Append('},"orders":');
        Json.Append(BuildOrdersJson());
        Json.Append('}');
        exit(Json.ToText());
    end;

    /// <summary>Ops Console "Orders" sekmesi: henüz sevkiyata bağlanmamış,
    /// toplanabilir satış siparişleri (multi-order pick adayları).</summary>
    procedure BuildOrdersJson(): Text
    var
        SalesHeader: Record "Sales Header";
        Json: TextBuilder;
        First: Boolean;
        Outstanding: Decimal;
        LineCount: Integer;
        LocationCode: Code[10];
        MaxRows: Integer;
    begin
        First := true;
        MaxRows := 200;
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        if SalesHeader.FindSet() then
            repeat
                if OrderPickable(SalesHeader."No.", Outstanding, LineCount, LocationCode) then begin
                    if not First then
                        Json.Append(',');
                    First := false;
                    Json.Append(StrSubstNo(
                        '{"no":"%1","customer":"%2","location":"%3","lines":%4,"qty":%5,"status":"%6"}',
                        Esc(SalesHeader."No."), Esc(SalesHeader."Sell-to Customer Name"), Esc(LocationCode),
                        LineCount, Format(Outstanding, 0, 9), Esc(Format(SalesHeader.Status))));
                    MaxRows -= 1;
                end;
            until (SalesHeader.Next() = 0) or (MaxRows <= 0);
        exit('[' + Json.ToText() + ']');
    end;

    /// <summary>Ops Console: seçili siparişleri tek sevkiyat + tek pick'te
    /// grupla ve kullanıcıya ata (ELOG multi akışı).</summary>
    procedure CreateMultiPick(OrderNosCsv: Text; UserId: Code[50]): Text
    var
        MultiOrderPick: Codeunit "DOPSWHS Multi Order Pick";
        ShipmentNo: Code[20];
        PickNo: Code[20];
    begin
        PickNo := MultiOrderPick.CreateGroupedPick(OrderNosCsv, UserId, ShipmentNo);
        exit(StrSubstNo('{"shipmentNo":"%1","pickNo":"%2"}', Esc(ShipmentNo), Esc(PickNo)));
    end;

    local procedure OrderPickable(OrderNo: Code[20]; var Outstanding: Decimal; var LineCount: Integer; var LocationCode: Code[10]): Boolean
    var
        SalesLine: Record "Sales Line";
        WhseShptLine: Record "Warehouse Shipment Line";
    begin
        Outstanding := 0;
        LineCount := 0;
        LocationCode := '';
        // Zaten bir sevkiyata bağlanan sipariş yeniden gruplanamaz.
        WhseShptLine.SetRange("Source Type", Database::"Sales Line");
        WhseShptLine.SetRange("Source Subtype", 1);
        WhseShptLine.SetRange("Source No.", OrderNo);
        if not WhseShptLine.IsEmpty() then
            exit(false);
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange("Document No.", OrderNo);
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetFilter("Outstanding Quantity", '>0');
        if SalesLine.FindSet() then
            repeat
                LineCount += 1;
                Outstanding += SalesLine."Outstanding Quantity";
                if LocationCode = '' then
                    LocationCode := SalesLine."Location Code";
            until SalesLine.Next() = 0;
        exit(LineCount > 0);
    end;

    /// <summary>Ops Console drag/dropdown: belgeyi bir kullanıcıya ata/yeniden ata.</summary>
    procedure AssignDoc(DocType: Text; DocNo: Code[20]; UserId: Code[50])
    var
        Act: Record "Warehouse Activity Header";
        Sh: Record "Warehouse Shipment Header";
    begin
        case LowerCase(DocType) of
            'pick':
                if Act.Get(Act.Type::Pick, DocNo) then begin
                    Act.Validate("Assigned User ID", UserId);
                    Act.Modify(true);
                end;
            'putaway':
                if Act.Get(Act.Type::"Put-away", DocNo) then begin
                    Act.Validate("Assigned User ID", UserId);
                    Act.Modify(true);
                end;
            'shipment':
                if Sh.Get(DocNo) then begin
                    Sh.Validate("Assigned User ID", UserId);
                    Sh.Modify(true);
                end;
        // 'count': Count Sheet Header'da atama alanı yok — no-op.
        end;
    end;

    local procedure BuildSummaryJson(): Text
    var
        Rcpt: Record "Warehouse Receipt Header";
        Sh: Record "Warehouse Shipment Header";
        CS: Record "DOPSWHS Count Sheet Header";
        Receipts: Integer;
        Putaways: Integer;
        Picks: Integer;
        Shipments: Integer;
        Counts: Integer;
        Unassigned: Integer;
        InProgress: Integer;
    begin
        Receipts := Rcpt.Count();
        Putaways := CountActivity(Enum::"Warehouse Activity Type"::"Put-away", false);
        Picks := CountActivity(Enum::"Warehouse Activity Type"::Pick, false);
        Shipments := Sh.Count();
        Counts := CS.Count();
        Unassigned := CountActivity(Enum::"Warehouse Activity Type"::"Put-away", true)
            + CountActivity(Enum::"Warehouse Activity Type"::Pick, true);
        Sh.SetRange("Assigned User ID", '');
        Unassigned += Sh.Count();
        InProgress := (Picks + Putaways + Shipments) - Unassigned;
        if InProgress < 0 then
            InProgress := 0;
        exit(StrSubstNo(
            '{"receipts":%1,"putaways":%2,"picks":%3,"shipments":%4,"counts":%5,"unassigned":%6,"inProgress":%7}',
            Receipts, Putaways, Picks, Shipments, Counts, Unassigned, InProgress));
    end;

    local procedure CountActivity(ActType: Enum "Warehouse Activity Type"; UnassignedOnly: Boolean): Integer
    var
        Act: Record "Warehouse Activity Header";
    begin
        Act.SetRange(Type, ActType);
        if UnassignedOnly then
            Act.SetRange("Assigned User ID", '');
        exit(Act.Count());
    end;

    local procedure BuildUsersJson(): Text
    var
        WhseEmployee: Record "Warehouse Employee";
        Json: TextBuilder;
        Seen: Dictionary of [Code[50], Boolean];
        First: Boolean;
    begin
        First := true;
        if WhseEmployee.FindSet() then
            repeat
                if (WhseEmployee."User ID" <> '') and (not Seen.ContainsKey(WhseEmployee."User ID")) then begin
                    Seen.Add(WhseEmployee."User ID", true);
                    if not First then Json.Append(',');
                    First := false;
                    Json.Append(StrSubstNo('"%1"', Esc(WhseEmployee."User ID")));
                end;
            until WhseEmployee.Next() = 0;
        exit('[' + Json.ToText() + ']');
    end;

    local procedure BuildActivityDocs(ActType: Enum "Warehouse Activity Type"): Text
    var
        Act: Record "Warehouse Activity Header";
        Json: TextBuilder;
        First: Boolean;
    begin
        First := true;
        Act.SetRange(Type, ActType);
        if Act.FindSet() then
            repeat
                if not First then Json.Append(',');
                First := false;
                Json.Append(BuildActivityObject(Act));
            until Act.Next() = 0;
        exit(Json.ToText());
    end;

    local procedure BuildActivityObject(var Act: Record "Warehouse Activity Header"): Text
    var
        Line: Record "Warehouse Activity Line";
        SourceNo: Code[20];
        Total: Decimal;
        Handled: Decimal;
        Pct: Integer;
    begin
        Line.SetRange("Activity Type", Act.Type);
        Line.SetRange("No.", Act."No.");
        if Line.FindSet() then
            repeat
                if SourceNo = '' then SourceNo := Line."Source No.";
                Total += Line.Quantity;
                Handled += Line."Qty. Handled";
            until Line.Next() = 0;
        if Total <> 0 then
            Pct := Round(Handled / Total * 100, 1);
        exit(StrSubstNo(
            '{"no":"%1","sourceNo":"%2","assignedUserId":"%3","status":"%4","percent":%5}',
            Esc(Act."No."), Esc(SourceNo), Esc(Act."Assigned User ID"), DocStatus(Act."Assigned User ID", Pct), Pct));
    end;

    local procedure BuildShipmentDocs(): Text
    var
        Sh: Record "Warehouse Shipment Header";
        Line: Record "Warehouse Shipment Line";
        Json: TextBuilder;
        First: Boolean;
        SourceNo: Code[20];
        Total: Decimal;
        Shipped: Decimal;
        Pct: Integer;
    begin
        First := true;
        if Sh.FindSet() then
            repeat
                Clear(SourceNo);
                Total := 0;
                Shipped := 0;
                Pct := 0;
                Line.SetRange("No.", Sh."No.");
                if Line.FindSet() then
                    repeat
                        if SourceNo = '' then SourceNo := Line."Source No.";
                        Total += Line.Quantity;
                        Shipped += Line."Qty. Shipped";
                    until Line.Next() = 0;
                if Total <> 0 then
                    Pct := Round(Shipped / Total * 100, 1);
                if not First then Json.Append(',');
                First := false;
                Json.Append(StrSubstNo(
                    '{"no":"%1","sourceNo":"%2","assignedUserId":"%3","status":"%4","percent":%5}',
                    Esc(Sh."No."), Esc(SourceNo), Esc(Sh."Assigned User ID"), DocStatus(Sh."Assigned User ID", Pct), Pct));
            until Sh.Next() = 0;
        exit(Json.ToText());
    end;

    local procedure BuildCountDocs(): Text
    var
        CS: Record "DOPSWHS Count Sheet Header";
        Json: TextBuilder;
        First: Boolean;
    begin
        First := true;
        if CS.FindSet() then
            repeat
                if not First then Json.Append(',');
                First := false;
                Json.Append(StrSubstNo(
                    '{"no":"%1","sourceNo":"%2","assignedUserId":"","status":"%3","percent":0}',
                    Esc(CS."No."), Esc(CS."Location Code"), Format(CS.Status)));
            until CS.Next() = 0;
        exit(Json.ToText());
    end;

    local procedure DocStatus(AssignedUser: Code[50]; Pct: Integer): Text
    begin
        if AssignedUser = '' then
            exit('Open');
        if Pct >= 100 then
            exit('Done');
        exit('InProgress');
    end;

    local procedure Esc(Value: Text): Text
    begin
        Value := Value.Replace('\', '\\');
        Value := Value.Replace('"', '\"');
        exit(Value);
    end;
}
