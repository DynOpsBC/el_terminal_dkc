codeunit 72378 "DOPSWHS Hierarchical LP Mgt"
{
    Access = Public;

    procedure EnsureEnabled()
    var
        Setup: Record "DOPSWHS Setup";
    begin
        if not Setup.Get('') then
            Error('Advanced WMS Setup must be configured before hierarchical LP operations.');
        if not Setup."Hierarchical LP Enabled" then
            Error('Hierarchical LP is not enabled for this Business Central company.');
    end;

    procedure SeedDkcTemplates()
    begin
        EnsureEnabled();
        UpsertTemplate('DKC-ITEM', 'DKC product LP', Enum::"DOPSWHS LP Unit Type"::Item, 0, 0, 0, 0, false, false);
        UpsertTemplate('DKC-BOX', 'DKC box', Enum::"DOPSWHS LP Unit Type"::Box, 60, 40, 40, 50, false, false);
        UpsertTemplate('DKC-PALLET', 'DKC pallet', Enum::"DOPSWHS LP Unit Type"::Pallet, 120, 80, 120, 1000, false, false);
    end;

    [CommitBehavior(CommitBehavior::Error)]
    procedure CompleteNode(var LP: Record "DOPSWHS LP Header")
    var
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        EnsureEnabled();
        EnsureGs1Configured();
        LP.LockTable();
        LP.Get(LP."No.");
        EnsureDkcUnitType(LP);
        if LP.Status = LP.Status::Open then
            LPMgt.Stop(LP, false)
        else
            if LP.Status <> LP.Status::Built then
                Error('%1 LP must be Open or Built before it can be completed for the hierarchy.', LP."No.");
        ValidateSsccForConfiguredPrefix(LP);
        ValidateNodeShape(LP, false, 0);
    end;

    [CommitBehavior(CommitBehavior::Error)]
    procedure AttachChild(var ParentLP: Record "DOPSWHS LP Header"; ChildLpNo: Code[20])
    var
        ChildLP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        EnsureEnabled();
        ParentLP.LockTable();
        ParentLP.Get(ParentLP."No.");
        if not ChildLP.Get(ChildLpNo) then
            Error('%1 child LP was not found.', ChildLpNo);
        if ParentLP."No." = ChildLP."No." then
            Error('An LP cannot be attached to itself.');
        EnsureBuilt(ParentLP);
        EnsureBuilt(ChildLP);
        EnsureDkcUnitType(ParentLP);
        EnsureDkcUnitType(ChildLP);
        EnsureGs1Configured();
        ValidateSsccForConfiguredPrefix(ParentLP);
        ValidateSsccForConfiguredPrefix(ChildLP);
        if ChildLP."Parent LP No." <> '' then
            Error('%1 is already attached to %2. Detach it first.', ChildLP."No.", ChildLP."Parent LP No.");
        if ParentLP."Location Code" <> ChildLP."Location Code" then
            Error('Parent and child LPs must be in the same location.');
        if ParentLP."Bin Code" <> ChildLP."Bin Code" then
            Error('Parent and child LPs must be in the same bin. Move them to one bin first.');
        ValidateParentChildTypes(ParentLP, ChildLP);
        ValidateNodeShape(ChildLP, true, 0);
        EnsureNoCycle(ParentLP, ChildLP);

        ChildLP.Validate("Parent LP No.", ParentLP."No.");
        ChildLP.Modify(true);
        ValidateParentCapacity(ParentLP);
        LPMgt.WriteToLedger(ChildLP, Enum::"DOPSWHS LP Action"::NestIn, ChildLP."Bin Code", ParentLP."Bin Code", 0, '', '', ParentLP."No.");
    end;

    [CommitBehavior(CommitBehavior::Error)]
    procedure DetachChild(var ParentLP: Record "DOPSWHS LP Header"; ChildLpNo: Code[20])
    var
        ChildLP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        EnsureEnabled();
        ParentLP.LockTable();
        ParentLP.Get(ParentLP."No.");
        if not ChildLP.Get(ChildLpNo) then
            Error('%1 child LP was not found.', ChildLpNo);
        EnsureBuilt(ParentLP);
        EnsureBuilt(ChildLP);
        if ChildLP."Parent LP No." <> ParentLP."No." then
            Error('%1 is not attached to %2.', ChildLP."No.", ParentLP."No.");

        ChildLP.Validate("Parent LP No.", '');
        ChildLP.Modify(true);
        LPMgt.WriteToLedger(ChildLP, Enum::"DOPSWHS LP Action"::Unnest, ChildLP."Bin Code", ChildLP."Bin Code", 0, '', '', ParentLP."No.");
    end;

    procedure GetHierarchyJson(var RootLP: Record "DOPSWHS LP Header"): Text
    var
        RootObject: JsonObject;
        ResultText: Text;
    begin
        EnsureEnabled();
        RootLP.Get(RootLP."No.");
        BuildNodeJson(RootLP, RootObject, 0);
        RootObject.WriteTo(ResultText);
        exit(ResultText);
    end;

    [CommitBehavior(CommitBehavior::Error)]
    procedure MoveHierarchy(var RootLP: Record "DOPSWHS LP Header"; TargetBinCode: Code[20]; OperatorUserId: Code[50])
    var
        TargetBin: Record Bin;
        SourceLocation: Code[10];
        SourceBin: Code[20];
    begin
        EnsureEnabled();
        RootLP.LockTable();
        RootLP.Get(RootLP."No.");
        if RootLP."Parent LP No." <> '' then
            Error('%1 is inside %2. Move the root LP instead.', RootLP."No.", RootLP."Parent LP No.");
        if OperatorUserId = '' then
            Error('Operator user ID is required to move an LP hierarchy.');
        if TargetBinCode = '' then
            Error('Target bin is required.');
        if not TargetBin.Get(RootLP."Location Code", TargetBinCode) then
            Error('%1 target bin was not found in location %2.', TargetBinCode, RootLP."Location Code");
        if RootLP."Bin Code" = TargetBinCode then
            Error('%1 hierarchy is already in bin %2.', RootLP."No.", TargetBinCode);

        SourceLocation := RootLP."Location Code";
        SourceBin := RootLP."Bin Code";
        ValidateTreeLocationAndBin(RootLP, SourceLocation, SourceBin, 0);
        ValidateNodeShape(RootLP, true, 0);
        MoveNode(RootLP, TargetBinCode, OperatorUserId, 0);
        RootLP.Get(RootLP."No.");
    end;

    procedure CompleteAndPrint(var RootLP: Record "DOPSWHS LP Header"; PrinterId: Code[50]; LabelProfile: Code[20]; Copies: Integer)
    begin
        CompleteNode(RootLP);
        if RootLP."Hierarchy Label Print Count" > 0 then
            Error('%1 label was already printed. Use reprint with a reason.', RootLP."No.");
        ValidateNodeShape(RootLP, true, 0);
        ValidateTreeSscc(RootLP, 0);
        PrintHierarchyLabel(RootLP, PrinterId, LabelProfile, Copies);
        RegisterLabelPrint(RootLP, '');
    end;

    procedure ReprintLabel(var RootLP: Record "DOPSWHS LP Header"; PrinterId: Code[50]; LabelProfile: Code[20]; Copies: Integer; Reason: Text[100])
    begin
        EnsureEnabled();
        RootLP.Get(RootLP."No.");
        EnsureBuilt(RootLP);
        if Reason.Trim() = '' then
            Error('A reprint reason is required.');
        ValidateNodeShape(RootLP, RootLP."Unit Type" <> RootLP."Unit Type"::Item, 0);
        ValidateTreeSscc(RootLP, 0);
        PrintHierarchyLabel(RootLP, PrinterId, LabelProfile, Copies);
        RegisterLabelPrint(RootLP, Reason);
    end;

    local procedure PrintHierarchyLabel(var LP: Record "DOPSWHS LP Header"; PrinterId: Code[50]; LabelProfile: Code[20]; Copies: Integer)
    var
        Dispatcher: Codeunit "DOPSWHS Print Dispatcher";
        ResolvedProfile: Code[20];
    begin
        ResolvedProfile := LabelProfile;
        if ResolvedProfile = '' then
            ResolvedProfile := ExpectedLabelProfile(LP);
        ValidateLabelProfile(LP, ResolvedProfile);
        Dispatcher.PrintDkcHierarchyLabel(LP, ResolvedProfile, PrinterId, Copies);
    end;

    local procedure RegisterLabelPrint(var LP: Record "DOPSWHS LP Header"; ReprintReason: Text[100])
    var
        Telemetry: Codeunit "DOPSWHS Telemetry";
    begin
        LP."Hierarchy Label Print Count" += 1;
        LP."Hierarchy Label Printed At" := CurrentDateTime();
        LP."Hierarchy Reprint Reason" := ReprintReason;
        LP.Modify(true);
        if ReprintReason <> '' then
            Telemetry.LogInfo('Print.DkcHierarchyReprint', CopyStr(StrSubstNo('%1: %2', LP."No.", ReprintReason), 1, 250))
        else
            Telemetry.LogInfo('Print.DkcHierarchyFirstPrint', LP."No.");
    end;

    local procedure ValidateLabelProfile(LP: Record "DOPSWHS LP Header"; LabelProfile: Code[20])
    var
        ExpectedProfile: Code[20];
    begin
        case LP."Unit Type" of
            LP."Unit Type"::Item:
                ExpectedProfile := 'DKC-ITEM';
            LP."Unit Type"::Box:
                ExpectedProfile := 'DKC-BOX';
            LP."Unit Type"::Pallet:
                ExpectedProfile := 'DKC-PALLET';
            else
                Error('%1 does not have a DKC hierarchy unit type.', LP."No.");
        end;
        if UpperCase(LabelProfile) <> ExpectedProfile then
            Error('%1 LP requires label profile %2, not %3.', LP."No.", ExpectedProfile, LabelProfile);
    end;

    local procedure ExpectedLabelProfile(LP: Record "DOPSWHS LP Header"): Code[20]
    begin
        case LP."Unit Type" of
            LP."Unit Type"::Item:
                exit('DKC-ITEM');
            LP."Unit Type"::Box:
                exit('DKC-BOX');
            LP."Unit Type"::Pallet:
                exit('DKC-PALLET');
        end;
        Error('%1 does not have a DKC hierarchy unit type.', LP."No.");
    end;

    local procedure EnsureEnabledAndDepth(Depth: Integer)
    var
        Setup: Record "DOPSWHS Setup";
    begin
        Setup.Get('');
        if Depth > Setup."Max LP Nesting Depth" then
            Error('LP hierarchy depth exceeds the configured maximum of %1.', Setup."Max LP Nesting Depth");
    end;

    local procedure ValidateNodeShape(LP: Record "DOPSWHS LP Header"; RequireContainerChildren: Boolean; Depth: Integer)
    var
        ChildLP: Record "DOPSWHS LP Header";
        LPLine: Record "DOPSWHS LP Line";
        HasChildren: Boolean;
    begin
        EnsureEnabledAndDepth(Depth);
        EnsureBuilt(LP);
        EnsureDkcUnitType(LP);
        LPLine.SetRange("LP No.", LP."No.");
        LPLine.SetFilter("Child LP No.", '<>%1', '');
        if not LPLine.IsEmpty() then
            Error('%1 contains a legacy child-LP line. Migrate it to Parent LP No. before using the DKC hierarchy.', LP."No.");

        LPLine.Reset();
        LPLine.SetRange("LP No.", LP."No.");
        LPLine.SetFilter("Item No.", '<>%1', '');
        if LP."Unit Type" = LP."Unit Type"::Item then begin
            if LPLine.IsEmpty() then
                Error('%1 product LP must contain at least one item line.', LP."No.");
        end else
            if not LPLine.IsEmpty() then
                Error('%1 is a %2 container and cannot contain item lines directly.', LP."No.", LP."Unit Type");

        ChildLP.SetRange("Parent LP No.", LP."No.");
        if ChildLP.FindSet() then
            repeat
                HasChildren := true;
                ValidateParentChildTypes(LP, ChildLP);
                ValidateNodeShape(ChildLP, true, Depth + 1);
            until ChildLP.Next() = 0;
        if (LP."Unit Type" = LP."Unit Type"::Item) and HasChildren then
            Error('%1 product LP cannot contain another LP.', LP."No.");
        if RequireContainerChildren and (LP."Unit Type" in [LP."Unit Type"::Box, LP."Unit Type"::Pallet]) and not HasChildren then
            Error('%1 %2 must contain at least one child LP.', LP."No.", LP."Unit Type");
    end;

    local procedure ValidateParentChildTypes(ParentLP: Record "DOPSWHS LP Header"; ChildLP: Record "DOPSWHS LP Header")
    begin
        case ParentLP."Unit Type" of
            ParentLP."Unit Type"::Box:
                if ChildLP."Unit Type" <> ChildLP."Unit Type"::Item then
                    Error('%1 box can contain only product LPs; %2 is %3.', ParentLP."No.", ChildLP."No.", ChildLP."Unit Type");
            ParentLP."Unit Type"::Pallet:
                if ChildLP."Unit Type" <> ChildLP."Unit Type"::Box then
                    Error('%1 pallet can contain only boxes; %2 is %3.', ParentLP."No.", ChildLP."No.", ChildLP."Unit Type");
            else
                Error('%1 product LP cannot be used as a parent.', ParentLP."No.");
        end;
    end;

    local procedure ValidateParentCapacity(ParentLP: Record "DOPSWHS LP Header")
    var
        Template: Record "DOPSWHS LP Template";
        ItemNos: Dictionary of [Text, Boolean];
        LotNos: Dictionary of [Text, Boolean];
        TotalWeight: Decimal;
    begin
        if not Template.Get(ParentLP."LP Template Code") then
            Error('%1 template for LP %2 was not found.', ParentLP."LP Template Code", ParentLP."No.");
        TotalWeight := GetTreeWeight(ParentLP, 0);
        if (Template."Max Weight kg" > 0) and (TotalWeight > Template."Max Weight kg") then
            Error('%1 exceeds template %2 maximum weight: %3 kg > %4 kg.', ParentLP."No.", Template.Code, TotalWeight, Template."Max Weight kg");
        CollectCharacteristics(ParentLP, ItemNos, LotNos, 0);
        if not Template."Allow Mixed Items" and (ItemNos.Count() > 1) then
            Error('%1 template does not allow mixed items.', Template.Code);
        if not Template."Allow Mixed Lots" and (LotNos.Count() > 1) then
            Error('%1 template does not allow mixed lots.', Template.Code);
    end;

    local procedure GetTreeWeight(LP: Record "DOPSWHS LP Header"; Depth: Integer): Decimal
    var
        LPLine: Record "DOPSWHS LP Line";
        ChildLP: Record "DOPSWHS LP Header";
        Total: Decimal;
    begin
        EnsureEnabledAndDepth(Depth);
        LPLine.SetRange("LP No.", LP."No.");
        if LPLine.FindSet() then
            repeat
                Total += LPLine."Line Weight kg";
            until LPLine.Next() = 0;
        ChildLP.SetRange("Parent LP No.", LP."No.");
        if ChildLP.FindSet() then
            repeat
                Total += GetTreeWeight(ChildLP, Depth + 1);
            until ChildLP.Next() = 0;
        exit(Total);
    end;

    local procedure CollectCharacteristics(LP: Record "DOPSWHS LP Header"; var ItemNos: Dictionary of [Text, Boolean]; var LotNos: Dictionary of [Text, Boolean]; Depth: Integer)
    var
        LPLine: Record "DOPSWHS LP Line";
        ChildLP: Record "DOPSWHS LP Header";
        LotKey: Text;
    begin
        EnsureEnabledAndDepth(Depth);
        LPLine.SetRange("LP No.", LP."No.");
        LPLine.SetFilter("Item No.", '<>%1', '');
        if LPLine.FindSet() then
            repeat
                if not ItemNos.ContainsKey(LPLine."Item No.") then
                    ItemNos.Add(LPLine."Item No.", true);
                LotKey := LPLine."Lot No.";
                if LotKey = '' then
                    LotKey := '#NOLOT';
                if not LotNos.ContainsKey(LotKey) then
                    LotNos.Add(LotKey, true);
            until LPLine.Next() = 0;
        ChildLP.SetRange("Parent LP No.", LP."No.");
        if ChildLP.FindSet() then
            repeat
                CollectCharacteristics(ChildLP, ItemNos, LotNos, Depth + 1);
            until ChildLP.Next() = 0;
    end;

    local procedure EnsureNoCycle(ParentLP: Record "DOPSWHS LP Header"; ChildLP: Record "DOPSWHS LP Header")
    var
        Ancestor: Record "DOPSWHS LP Header";
        ParentNo: Code[20];
        Depth: Integer;
    begin
        ParentNo := ParentLP."No.";
        while ParentNo <> '' do begin
            if ParentNo = ChildLP."No." then
                Error('Attaching %1 to %2 would create an LP cycle.', ChildLP."No.", ParentLP."No.");
            Ancestor.Get(ParentNo);
            ParentNo := Ancestor."Parent LP No.";
            Depth += 1;
            EnsureEnabledAndDepth(Depth);
        end;
    end;

    local procedure ValidateTreeLocationAndBin(LP: Record "DOPSWHS LP Header"; LocationCode: Code[10]; BinCode: Code[20]; Depth: Integer)
    var
        ChildLP: Record "DOPSWHS LP Header";
    begin
        EnsureEnabledAndDepth(Depth);
        if (LP."Location Code" <> LocationCode) or (LP."Bin Code" <> BinCode) then
            Error('%1 is in %2/%3 but the hierarchy root is in %4/%5.', LP."No.", LP."Location Code", LP."Bin Code", LocationCode, BinCode);
        ChildLP.SetRange("Parent LP No.", LP."No.");
        if ChildLP.FindSet() then
            repeat
                ValidateTreeLocationAndBin(ChildLP, LocationCode, BinCode, Depth + 1);
            until ChildLP.Next() = 0;
    end;

    local procedure MoveNode(var LP: Record "DOPSWHS LP Header"; TargetBinCode: Code[20]; OperatorUserId: Code[50]; Depth: Integer)
    var
        ChildLP: Record "DOPSWHS LP Header";
        LPMgt: Codeunit "DOPSWHS LP Management";
    begin
        EnsureEnabledAndDepth(Depth);
        ChildLP.SetRange("Parent LP No.", LP."No.");
        if ChildLP.FindSet() then
            repeat
                MoveNode(ChildLP, TargetBinCode, OperatorUserId, Depth + 1);
            until ChildLP.Next() = 0;
        LPMgt.MoveToBin(LP, TargetBinCode, OperatorUserId);
    end;

    local procedure BuildNodeJson(LP: Record "DOPSWHS LP Header"; var Node: JsonObject; Depth: Integer)
    var
        ChildLP: Record "DOPSWHS LP Header";
        LPLine: Record "DOPSWHS LP Line";
        ChildNode: JsonObject;
        Children: JsonArray;
        Lines: JsonArray;
        LineNode: JsonObject;
    begin
        EnsureEnabledAndDepth(Depth);
        Node.Add('no', LP."No.");
        Node.Add('unitType', Format(LP."Unit Type"));
        Node.Add('status', Format(LP.Status));
        Node.Add('locationCode', LP."Location Code");
        Node.Add('binCode', LP."Bin Code");
        Node.Add('sscc', LP.SSCC);

        LPLine.SetRange("LP No.", LP."No.");
        LPLine.SetFilter("Item No.", '<>%1', '');
        if LPLine.FindSet() then
            repeat
                Clear(LineNode);
                LineNode.Add('itemNo', LPLine."Item No.");
                LineNode.Add('quantity', LPLine.Quantity);
                LineNode.Add('unitOfMeasure', LPLine."Unit of Measure");
                LineNode.Add('lotNo', LPLine."Lot No.");
                LineNode.Add('serialNo', LPLine."Serial No.");
                Lines.Add(LineNode);
            until LPLine.Next() = 0;
        Node.Add('lines', Lines);

        ChildLP.SetRange("Parent LP No.", LP."No.");
        ChildLP.SetCurrentKey("Parent LP No.");
        if ChildLP.FindSet() then
            repeat
                Clear(ChildNode);
                BuildNodeJson(ChildLP, ChildNode, Depth + 1);
                Children.Add(ChildNode);
            until ChildLP.Next() = 0;
        Node.Add('children', Children);
    end;

    local procedure EnsureBuilt(LP: Record "DOPSWHS LP Header")
    begin
        if LP.Status <> LP.Status::Built then
            Error('%1 LP must be Built. Current status: %2.', LP."No.", LP.Status);
    end;

    local procedure EnsureDkcUnitType(LP: Record "DOPSWHS LP Header")
    begin
        if LP."Unit Type" = LP."Unit Type"::Unspecified then
            Error('%1 does not use a DKC-ITEM, DKC-BOX, or DKC-PALLET template.', LP."No.");
    end;

    local procedure EnsureGs1Configured()
    var
        Setup: Record "DOPSWHS Setup";
        Position: Integer;
        Character: Text[1];
    begin
        Setup.Get('');
        Setup.TestField("GS1 Company Prefix");
        if StrLen(Setup."GS1 Company Prefix") > 12 then
            Error('GS1 company prefix cannot exceed 12 digits.');
        for Position := 1 to StrLen(Setup."GS1 Company Prefix") do begin
            Character := CopyStr(Setup."GS1 Company Prefix", Position, 1);
            if not (Character in ['0' .. '9']) then
                Error('GS1 company prefix must contain digits only.');
        end;
    end;

    local procedure ValidateSsccForConfiguredPrefix(LP: Record "DOPSWHS LP Header")
    var
        Setup: Record "DOPSWHS Setup";
        Generator: Codeunit "DOPSWHS SSCC Generator";
        Position: Integer;
        Character: Text[1];
        Base17: Text[17];
    begin
        Setup.Get('');
        if StrLen(LP.SSCC) <> 18 then
            Error('%1 must have an 18-digit SSCC before it can be used in the DKC hierarchy.', LP."No.");
        for Position := 1 to StrLen(LP.SSCC) do begin
            Character := CopyStr(LP.SSCC, Position, 1);
            if not (Character in ['0' .. '9']) then
                Error('%1 SSCC must contain digits only.', LP."No.");
        end;
        if CopyStr(LP.SSCC, 2, StrLen(Setup."GS1 Company Prefix")) <> Setup."GS1 Company Prefix" then
            Error('%1 SSCC was not generated with the configured GS1 company prefix. Rebuild the LP after correcting setup.', LP."No.");
        Base17 := CopyStr(LP.SSCC, 1, 17);
        if CopyStr(LP.SSCC, 18, 1)[1] <> Generator.CalculateCheckDigit(Base17) then
            Error('%1 SSCC check digit is invalid.', LP."No.");
    end;

    local procedure ValidateTreeSscc(LP: Record "DOPSWHS LP Header"; Depth: Integer)
    var
        ChildLP: Record "DOPSWHS LP Header";
    begin
        EnsureEnabledAndDepth(Depth);
        ValidateSsccForConfiguredPrefix(LP);
        ChildLP.SetRange("Parent LP No.", LP."No.");
        if ChildLP.FindSet() then
            repeat
                ValidateTreeSscc(ChildLP, Depth + 1);
            until ChildLP.Next() = 0;
    end;

    local procedure UpsertTemplate(Code: Code[20]; Description: Text[100]; UnitType: Enum "DOPSWHS LP Unit Type"; LengthCm: Decimal; WidthCm: Decimal; HeightCm: Decimal; MaxWeightKg: Decimal; AllowMixedItems: Boolean; AllowMixedLots: Boolean)
    var
        Template: Record "DOPSWHS LP Template";
        IsNew: Boolean;
    begin
        IsNew := not Template.Get(Code);
        if IsNew then begin
            Template.Init();
            Template.Code := Code;
            Template.Description := Description;
            Template."Default Length cm" := LengthCm;
            Template."Default Width cm" := WidthCm;
            Template."Default Height cm" := HeightCm;
            Template."Max Weight kg" := MaxWeightKg;
            Template."Label Report ID" := Report::"DOPSWHS LP Label";
            Template."Allow Mixed Items" := AllowMixedItems;
            Template."Allow Mixed Lots" := AllowMixedLots;
        end;
        Template."Unit Type" := UnitType;
        if IsNew then
            Template.Insert(true)
        else
            Template.Modify(true);
    end;
}
