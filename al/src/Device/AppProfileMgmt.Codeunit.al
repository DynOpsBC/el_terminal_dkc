codeunit 72265 "DOPSWHS App Profile Mgmt"
{
    // Resolves the effective WMS App profile for the calling user: their own row falls back to a
    // 'DEFAULT' profile finally to an empty default. Returns JSON the mobile app consumes once
    // after login to tailor visible modules + filters + defaults.
    Access = Public;

    procedure ResolveForCurrentUser(): Text
    var
        Profile: Record "DOPSWHS App User Profile";
        UserKey: Code[50];
    begin
        UserKey := CopyStr(UserId(), 1, 50);
        if Profile.Get(UserKey) and not Profile."Disabled" then
            exit(BuildJson(Profile, UserKey));
        if Profile.Get('DEFAULT') and not Profile."Disabled" then
            exit(BuildJson(Profile, UserKey));
        // No profile yet — return a minimal default so the mobile app still works.
        Clear(Profile);
        Profile."User ID" := UserKey;
        exit(BuildJson(Profile, UserKey));
    end;

    /// <summary>Ensures a baseline DEFAULT profile + a row for the current install user.</summary>
    procedure SeedDefaults()
    var
        Profile: Record "DOPSWHS App User Profile";
        Setup: Record "DOPSWHS Setup";
        DefaultLoc: Code[10];
        DefaultConfig: Code[20];
        CurrentUser: Code[50];
    begin
        if Setup.Get('') then DefaultLoc := Setup."Default Location Code";
        DefaultConfig := FirstDeviceConfig();

        if not Profile.Get('DEFAULT') then begin
            Profile.Init();
            Profile."User ID" := 'DEFAULT';
            Profile."Description" := 'Fallback profile (every user without a specific row)';
            Profile."Config Code" := DefaultConfig;
            Profile."Default Location Code" := DefaultLoc;
            Profile."Hide Test Tools" := true;
            Profile."Hide Admin Tools" := true;
            Profile."LP Status Filter" := Profile."LP Status Filter"::Built;
            Profile."Quality Filter" := Profile."Quality Filter"::OpenOnly;
            Profile.Insert(true);
        end;

        CurrentUser := CopyStr(UserId(), 1, 50);
        if (CurrentUser <> '') and (CurrentUser <> 'DEFAULT') and (not Profile.Get(CurrentUser)) then begin
            Profile.Init();
            Profile."User ID" := CurrentUser;
            Profile."Description" := StrSubstNo('%1 (admin)', CurrentUser);
            Profile."Config Code" := DefaultConfig;
            Profile."Default Location Code" := DefaultLoc;
            Profile."Hide Test Tools" := false;   // admin sees test tools
            Profile."Hide Admin Tools" := false;
            Profile.Insert(true);
        end;
    end;

    local procedure FirstDeviceConfig(): Code[20]
    var
        Config: Record "DOPSWHS Device Configuration";
    begin
        if Config.FindFirst() then exit(Config.Code);
        exit('');
    end;

    local procedure BuildJson(Profile: Record "DOPSWHS App User Profile"; ResolvedFor: Code[50]): Text
    var
        Json: TextBuilder;
        EffectiveLoc: Code[10];
    begin
        EffectiveLoc := Profile."Default Location Code";
        if EffectiveLoc = '' then EffectiveLoc := DefaultLocationFromSetup();

        Json.Append('{');
        Json.Append(StrSubstNo('"userId":"%1",', Esc(ResolvedFor)));
        Json.Append(StrSubstNo('"profileUserId":"%1",', Esc(Profile."User ID")));
        Json.Append(StrSubstNo('"description":"%1",', Esc(Profile."Description")));
        Json.Append(StrSubstNo('"configCode":"%1",', Esc(Profile."Config Code")));
        Json.Append(StrSubstNo('"defaultLocationCode":"%1",', Esc(EffectiveLoc)));
        Json.Append(StrSubstNo('"defaultBinCode":"%1",', Esc(Profile."Default Bin Code")));
        Json.Append(StrSubstNo('"locale":"%1",', Esc(Profile."Locale")));
        Json.Append(StrSubstNo('"onlyMyPicks":%1,', BoolTxt(Profile."Only My Picks")));
        Json.Append(StrSubstNo('"onlyMyReceipts":%1,', BoolTxt(Profile."Only My Receipts")));
        Json.Append(StrSubstNo('"onlyMyPutAways":%1,', BoolTxt(Profile."Only My PutAways")));
        Json.Append(StrSubstNo('"onlyMyShipments":%1,', BoolTxt(Profile."Only My Shipments")));
        Json.Append(StrSubstNo('"onlyMyMovements":%1,', BoolTxt(Profile."Only My Movements")));
        Json.Append(StrSubstNo('"lpStatusFilter":"%1",', Format(Profile."LP Status Filter")));
        Json.Append(StrSubstNo('"qualityFilter":"%1",', Format(Profile."Quality Filter")));
        Json.Append(StrSubstNo('"hideTestTools":%1,', BoolTxt(Profile."Hide Test Tools")));
        Json.Append(StrSubstNo('"hideAdminTools":%1,', BoolTxt(Profile."Hide Admin Tools")));
        Json.Append(StrSubstNo('"maxListRows":%1,', Profile."Max List Rows"));
        Json.Append('"visibleModules":[');
        AppendVisibleModules(Json, Profile."Config Code");
        Json.Append('],');
        AppendRoleSections(Json, ResolvedFor);
        Json.Append('}');
        exit(Json.ToText());
    end;

    local procedure AppendRoleSections(var Json: TextBuilder; UserKey: Code[50])
    var
        FilterMgmt: Codeunit "DOPSWHS App Role Filter Mgmt";
    begin
        FilterMgmt.AppendRolesJson(Json, UserKey);
        Json.Append(',');
        FilterMgmt.AppendEffectiveFiltersJson(Json, UserKey);
    end;

    local procedure AppendVisibleModules(var Json: TextBuilder; ConfigCode: Code[20])
    var
        DeviceMenu: Record "DOPSWHS Device Menu";
        First: Boolean;
    begin
        if ConfigCode = '' then exit;
        DeviceMenu.SetCurrentKey("Config Code", "Sort Order");
        DeviceMenu.SetRange("Config Code", ConfigCode);
        DeviceMenu.SetRange(Visible, true);
        First := true;
        if DeviceMenu.FindSet() then
            repeat
                if not First then Json.Append(',');
                First := false;
                Json.Append(StrSubstNo('{"module":"%1","menuItem":"%2","sort":%3}',
                    Format(DeviceMenu."Application Module"), Esc(DeviceMenu."Menu Item"), DeviceMenu."Sort Order"));
            until DeviceMenu.Next() = 0;
    end;

    local procedure DefaultLocationFromSetup(): Code[10]
    var
        Setup: Record "DOPSWHS Setup";
    begin
        if Setup.Get('') then exit(Setup."Default Location Code");
        exit('');
    end;

    local procedure Esc(Value: Text): Text
    begin
        Value := Value.Replace('\', '\\');
        Value := Value.Replace('"', '\"');
        exit(Value);
    end;

    local procedure BoolTxt(B: Boolean): Text
    begin
        if B then exit('true');
        exit('false');
    end;
}
