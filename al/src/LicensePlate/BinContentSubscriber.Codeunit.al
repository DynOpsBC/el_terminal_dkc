codeunit 72039 "DOPSWHS Bin Content Subscriber"
{
    Access = Public;

    procedure CalculateNestedLPQuantity(LocationCode: Code[10]; BinCode: Code[20]; ItemNo: Code[20]): Decimal
    var
        LP: Record "DOPSWHS LP Header";
        Total: Decimal;
    begin
        LP.SetRange("Location Code", LocationCode);
        LP.SetRange("Bin Code", BinCode);
        LP.SetRange(Status, LP.Status::Built);
        LP.SetRange("Parent LP No.", '');
        if LP.FindSet() then
            repeat
                Total += SumLeafItemLines(LP."No.", ItemNo);
            until LP.Next() = 0;
        exit(Total);
    end;

    /// <summary>
    /// Returns the active LP numbers and the quantity of the current Bin Content item that is
    /// represented by LP metadata. BC stock remains in Bin Content; these values explain which
    /// part of that stock belongs to which LP.
    /// </summary>
    procedure GetActiveLPItemInfo(LocationCode: Code[10]; BinCode: Code[20]; ItemNo: Code[20]; VariantCode: Code[10]; UomCode: Code[10]; var LpNos: Text[250]; var LPQuantity: Decimal)
    var
        LP: Record "DOPSWHS LP Header";
        LPLine: Record "DOPSWHS LP Line";
        Separator: Text;
    begin
        Clear(LpNos);
        Clear(LPQuantity);
        LP.SetRange("Location Code", LocationCode);
        LP.SetRange("Bin Code", BinCode);
        LP.SetFilter(Status, '%1|%2|%3', LP.Status::Open, LP.Status::Built, LP.Status::Assigned);
        if LP.FindSet() then
            repeat
                LPLine.Reset();
                LPLine.SetRange("LP No.", LP."No.");
                LPLine.SetRange("Item No.", ItemNo);
                LPLine.SetRange("Variant Code", VariantCode);
                if UomCode <> '' then
                    LPLine.SetRange("Unit of Measure", UomCode);
                if LPLine.FindSet() then begin
                    Separator := '';
                    if LpNos <> '' then
                        Separator := ', ';
                    LpNos := CopyStr(LpNos + Separator + LP."No.", 1, MaxStrLen(LpNos));
                    repeat
                        LPQuantity += LPLine.Quantity;
                    until LPLine.Next() = 0;
                end;
            until LP.Next() = 0;
    end;

    procedure GetLPContentSummary(LPNo: Code[20]): Text[250]
    var
        LPLine: Record "DOPSWHS LP Line";
        Summary: Text[250];
        LineText: Text;
        Separator: Text;
    begin
        LPLine.SetRange("LP No.", LPNo);
        LPLine.SetFilter("Item No.", '<>%1', '');
        if LPLine.FindSet() then
            repeat
                LineText := LPLine."Item No." + ' x ' + Format(LPLine.Quantity);
                if LPLine."Lot No." <> '' then
                    LineText += ' (Lot ' + LPLine."Lot No." + ')';
                Separator := '';
                if Summary <> '' then
                    Separator := '; ';
                Summary := CopyStr(Summary + Separator + LineText, 1, MaxStrLen(Summary));
            until (LPLine.Next() = 0) or (StrLen(Summary) = MaxStrLen(Summary));
        exit(Summary);
    end;

    local procedure SumLeafItemLines(LPNo: Code[20]; ItemNo: Code[20]): Decimal
    begin
        exit(SumLeafItemLinesAtDepth(LPNo, ItemNo, 0));
    end;

    local procedure SumLeafItemLinesAtDepth(LPNo: Code[20]; ItemNo: Code[20]; Depth: Integer): Decimal
    var
        LPLine: Record "DOPSWHS LP Line";
        ChildLP: Record "DOPSWHS LP Header";
        Total: Decimal;
        HasCanonicalChildren: Boolean;
    begin
        if Depth > 16 then
            Error('LP hierarchy depth or cycle is invalid at %1.', LPNo);

        // Parent LP No. on the child header is the canonical relationship.
        // Older data may also contain LP Line."Child LP No." rows; use those
        // only as a fallback so a migrated hierarchy is never counted twice.
        ChildLP.SetRange("Parent LP No.", LPNo);
        if ChildLP.FindSet() then
            repeat
                HasCanonicalChildren := true;
                Total += SumLeafItemLinesAtDepth(ChildLP."No.", ItemNo, Depth + 1);
            until ChildLP.Next() = 0;

        LPLine.SetRange("LP No.", LPNo);
        if LPLine.FindSet() then
            repeat
                if LPLine."Child LP No." <> '' then begin
                    if not HasCanonicalChildren then
                        Total += SumLeafItemLinesAtDepth(LPLine."Child LP No.", ItemNo, Depth + 1);
                end
                else
                    if (ItemNo = '') or (LPLine."Item No." = ItemNo) then
                        Total += LPLine.Quantity;
            until LPLine.Next() = 0;
        exit(Total);
    end;
}
