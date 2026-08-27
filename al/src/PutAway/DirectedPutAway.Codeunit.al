codeunit 72044 "DOPSWHS Directed PutAway" implements "DOPSWHS PutAway Strategy"
{
    Access = Public;

    procedure SuggestBin(Item: Record Item; Qty: Decimal; LocationCode: Code[10]; var BinCode: Code[20]; var Reason: Text): Boolean
    var
        Bin: Record Bin;
        BestBin: Record Bin;
        CustomDimensions: Dictionary of [Text, Text];
        HasBestBin: Boolean;
    begin
        CustomDimensions.Add('Category', 'PutAway');
        Session.LogMessage('DOPSWHS-PutAway-SuggestBin', StrSubstNo('Suggest bin for item %1 qty %2 location %3', Item."No.", Qty, LocationCode), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);

        Clear(BinCode);
        Clear(Reason);

        Bin.SetRange("Location Code", LocationCode);
        if Bin.FindSet() then
            repeat
                if IsEligibleBin(Bin, Item, Qty) then
                    if IsPreferred(Bin, BestBin, HasBestBin) then begin
                        BestBin := Bin;
                        HasBestBin := true;
                    end;
            until Bin.Next() = 0;

        if HasBestBin then begin
            BinCode := BestBin.Code;
            Reason := StrSubstNo('Selected zone %1 rank %2, bin rank %3.', BestBin."Zone Code", ZoneRank(BestBin), BestBin."Bin Ranking");
            exit(true);
        end;

        Reason := StrSubstNo('No eligible put-away bin found for item %1 at location %2.', Item."No.", LocationCode);
        Session.LogMessage('DOPSWHS-PutAway-NoBin', Reason, Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
        exit(false);
    end;

    local procedure IsPreferred(Candidate: Record Bin; CurrentBest: Record Bin; HasBestBin: Boolean): Boolean
    var
        CandidateZoneRank: Integer;
        BestZoneRank: Integer;
    begin
        if not HasBestBin then
            exit(true);

        CandidateZoneRank := ZoneRank(Candidate);
        BestZoneRank := ZoneRank(CurrentBest);
        if CandidateZoneRank <> BestZoneRank then
            exit(CandidateZoneRank > BestZoneRank);
        if Candidate."Bin Ranking" <> CurrentBest."Bin Ranking" then
            exit(Candidate."Bin Ranking" > CurrentBest."Bin Ranking");
        exit(Candidate.Code < CurrentBest.Code);
    end;

    local procedure IsEligibleBin(Bin: Record Bin; Item: Record Item; Qty: Decimal): Boolean
    begin
        if not PassesCapacity(Bin, Item, Qty) then
            exit(false);
        if not PassesMixingRules(Bin, Item) then
            exit(false);
        exit(true);
    end;

    local procedure PassesCapacity(Bin: Record Bin; Item: Record Item; Qty: Decimal): Boolean
    var
        ExistingCubage: Decimal;
        RequiredCubage: Decimal;
    begin
        if Bin."Maximum Cubage" = 0 then
            exit(true);

        ExistingCubage := CalcExistingCubage(Bin);
        RequiredCubage := Item."Unit Volume" * Qty;
        exit((ExistingCubage + RequiredCubage) <= Bin."Maximum Cubage");
    end;

    local procedure CalcExistingCubage(Bin: Record Bin): Decimal
    var
        BinContent: Record "Bin Content";
        ContentItem: Record Item;
        Cubage: Decimal;
    begin
        BinContent.SetRange("Location Code", Bin."Location Code");
        BinContent.SetRange("Bin Code", Bin.Code);
        if BinContent.FindSet() then
            repeat
                if ContentItem.Get(BinContent."Item No.") then
                    Cubage += ContentItem."Unit Volume" * BinContent.Quantity;
            until BinContent.Next() = 0;
        exit(Cubage);
    end;

    local procedure PassesMixingRules(Bin: Record Bin; Item: Record Item): Boolean
    var
        BinContent: Record "Bin Content";
        ContentItem: Record Item;
        ItemCategoryCode: Code[20];
    begin
        ItemCategoryCode := Item."Item Category Code";
        BinContent.SetRange("Location Code", Bin."Location Code");
        BinContent.SetRange("Bin Code", Bin.Code);
        if BinContent.FindSet() then
            repeat
                if ContentItem.Get(BinContent."Item No.") then
                    if (ContentItem."Item Category Code" <> '') and (ItemCategoryCode <> '') and
                       (ContentItem."Item Category Code" <> ItemCategoryCode)
                    then
                        exit(false);
            until BinContent.Next() = 0;
        exit(true);
    end;

    local procedure ZoneRank(Bin: Record Bin): Integer
    var
        Zone: Record Zone;
    begin
        if Zone.Get(Bin."Location Code", Bin."Zone Code") then
            exit(Zone."Zone Ranking");
        exit(0);
    end;
}
