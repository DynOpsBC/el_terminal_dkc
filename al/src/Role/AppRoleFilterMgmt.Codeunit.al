codeunit 72272 "DOPSWHS App Role Filter Mgmt"
{
    // Applies role-based server-side filters on any API page's source record. Called from each
    // SourceTable-backed API page's OnOpenPage trigger via:
    //     RecRef.GetTable(Rec);
    //     FilterMgmt.ApplyForCurrentUser(RecRef, Enum::"DOPSWHS App Filter Entity"::Pick);
    //     RecRef.SetTable(Rec);
    //
    // Pulls every active rule for the current user's roles, OR-joins rules that target the
    // same (Entity, Field No.), substitutes %USER%/%LOC%/%TODAY%/%NOW% tokens, and SetFilter()s
    // the result. Bad expressions are caught silently (TryFunction) the page never breaks.
    Access = Public;

    /// <summary>Applies the current user's role filters to a record reference. Returns true if
    /// any filter was applied.</summary>
    procedure ApplyForCurrentUser(var RecRef: RecordRef; EntityType: Enum "DOPSWHS App Filter Entity"): Boolean
    var
        Rule: Record "DOPSWHS App Role Filter Rule";
        UserRoles: Record "DOPSWHS App User Role";
        ExpressionByField: Dictionary of [Integer, Text];
        UserKey: Code[50];
        FieldNo: Integer;
        FinalExpr: Text;
        Resolved: Text;
        ExistingExpr: Text;
        AppliedAny: Boolean;
    begin
        UserKey := CopyStr(UserId(), 1, 50);
        if UserKey = '' then
            exit(false);

        // Gather active roles for this user.
        UserRoles.SetRange("User ID", UserKey);
        UserRoles.SetRange(Disabled, false);
        if UserRoles.IsEmpty() then
            exit(false);

        // Walk every rule for these roles + this entity, grouping by Field No. with OR-join.
        if UserRoles.FindSet() then
            repeat
                Rule.SetRange("Role Code", UserRoles."Role Code");
                Rule.SetRange("Entity", EntityType);
                Rule.SetRange(Disabled, false);
                if Rule.FindSet() then
                    repeat
                        if Rule."Field No." <> 0 then begin
                            Resolved := ResolveTokens(Rule."Filter Expression", UserKey);
                            if Resolved <> '' then begin
                                if ExpressionByField.ContainsKey(Rule."Field No.") then begin
                                    ExpressionByField.Get(Rule."Field No.", ExistingExpr);
                                    ExpressionByField.Set(Rule."Field No.", ExistingExpr + '|' + Resolved);
                                end else
                                    ExpressionByField.Add(Rule."Field No.", Resolved);
                            end;
                        end;
                    until Rule.Next() = 0;
            until UserRoles.Next() = 0;

        if ExpressionByField.Count() = 0 then
            exit(false);

        foreach FieldNo in ExpressionByField.Keys() do begin
            ExpressionByField.Get(FieldNo, FinalExpr);
            if SafeSetFilter(RecRef, FieldNo, FinalExpr) then
                AppliedAny := true;
        end;
        exit(AppliedAny);
    end;

    /// <summary>Substitutes runtime tokens in a filter expression.</summary>
    procedure ResolveTokens(Expression: Text; UserKey: Code[50]): Text
    var
        Profile: Record "DOPSWHS App User Profile";
        LocCode: Code[10];
    begin
        if Expression = '' then
            exit('');
        Expression := Expression.Replace('%USER%', UserKey);
        Expression := Expression.Replace('%TODAY%', Format(Today()));
        Expression := Expression.Replace('%NOW%', Format(CurrentDateTime()));
        if Expression.Contains('%LOC%') then begin
            if Profile.Get(UserKey) then
                LocCode := Profile."Default Location Code";
            Expression := Expression.Replace('%LOC%', LocCode);
        end;
        exit(Expression);
    end;

    /// <summary>Returns roles for a user as a CSV. Used by AppProfileMgmt resolver JSON.</summary>
    procedure GetRolesForUserAsCsv(UserKey: Code[50]): Text
    var
        UserRoles: Record "DOPSWHS App User Role";
        Csv: TextBuilder;
        First: Boolean;
    begin
        First := true;
        UserRoles.SetRange("User ID", UserKey);
        UserRoles.SetRange(Disabled, false);
        if UserRoles.FindSet() then
            repeat
                if not First then
                    Csv.Append(',');
                Csv.Append(UserRoles."Role Code");
                First := false;
            until UserRoles.Next() = 0;
        exit(Csv.ToText());
    end;

    /// <summary>Builds a JSON section listing the user's roles. AppProfileMgmt embeds this in
    /// the resolveCurrent payload so mobile clients can show role badges.</summary>
    procedure AppendRolesJson(var Json: TextBuilder; UserKey: Code[50])
    var
        UserRoles: Record "DOPSWHS App User Role";
        Role: Record "DOPSWHS App Role";
        First: Boolean;
    begin
        First := true;
        Json.Append('"roles":[');
        UserRoles.SetRange("User ID", UserKey);
        UserRoles.SetRange(Disabled, false);
        if UserRoles.FindSet() then
            repeat
                if Role.Get(UserRoles."Role Code") and Role.Active then begin
                    if not First then
                        Json.Append(',');
                    Json.Append(StrSubstNo('{"code":"%1","description":"%2","priority":%3}',
                        Role.Code,
                        EscapeJsonStr(Role.Description),
                        UserRoles.Priority));
                    First := false;
                end;
            until UserRoles.Next() = 0;
        Json.Append(']');
    end;

    /// <summary>Builds the JSON object listing per-entity resolved filter expressions for the user.</summary>
    procedure AppendEffectiveFiltersJson(var Json: TextBuilder; UserKey: Code[50])
    var
        Rule: Record "DOPSWHS App Role Filter Rule";
        UserRoles: Record "DOPSWHS App User Role";
        EntityName: Text;
        LastEntity: Text;
        FirstEntity: Boolean;
        FirstRule: Boolean;
        Resolved: Text;
        SeenAny: Boolean;
    begin
        Json.Append('"effectiveFilters":{');
        UserRoles.SetRange("User ID", UserKey);
        UserRoles.SetRange(Disabled, false);
        if UserRoles.FindSet() then
            repeat
                Rule.SetCurrentKey("Role Code", "Entity");
                Rule.SetRange("Role Code", UserRoles."Role Code");
                Rule.SetRange(Disabled, false);
                if Rule.FindSet() then
                    repeat
                        if Rule."Field No." <> 0 then begin
                            EntityName := Format(Rule."Entity");
                            Resolved := ResolveTokens(Rule."Filter Expression", UserKey);
                            if EntityName <> LastEntity then begin
                                if SeenAny then
                                    Json.Append(']');
                                if FirstEntity then
                                    FirstEntity := false
                                else
                                    Json.Append(',');
                                Json.Append(StrSubstNo('"%1":[', EntityName));
                                LastEntity := EntityName;
                                FirstRule := true;
                                SeenAny := true;
                            end;
                            if not FirstRule then
                                Json.Append(',');
                            Json.Append(StrSubstNo('{"fieldNo":%1,"field":"%2","expression":"%3"}',
                                Rule."Field No.",
                                EscapeJsonStr(Rule."Field Name Hint"),
                                EscapeJsonStr(Resolved)));
                            FirstRule := false;
                        end;
                    until Rule.Next() = 0;
            until UserRoles.Next() = 0;
        if SeenAny then
            Json.Append(']');
        Json.Append('}');
    end;

    // ----- internals -----

    [TryFunction]
    local procedure TrySetFilter(var RecRef: RecordRef; FieldNo: Integer; Expression: Text)
    var
        FieldRef: FieldRef;
    begin
        FieldRef := RecRef.Field(FieldNo);
        FieldRef.SetFilter(Expression);
    end;

    local procedure SafeSetFilter(var RecRef: RecordRef; FieldNo: Integer; Expression: Text): Boolean
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        if not TrySetFilter(RecRef, FieldNo, Expression) then begin
            CustomDimensions.Add('tableNo', Format(RecRef.Number));
            CustomDimensions.Add('fieldNo', Format(FieldNo));
            CustomDimensions.Add('expression', Expression);
            Session.LogMessage('AdvWMS.RoleFilter.BadExpression',
                StrSubstNo('Role filter expression failed on table %1 field %2: %3', RecRef.Number, FieldNo, Expression),
                Verbosity::Warning, DataClassification::SystemMetadata,
                TelemetryScope::ExtensionPublisher, CustomDimensions);
            exit(false);
        end;
        exit(true);
    end;

    local procedure EscapeJsonStr(Value: Text): Text
    begin
        Value := Value.Replace('\', '\\');
        Value := Value.Replace('"', '\"');
        exit(Value);
    end;
}
