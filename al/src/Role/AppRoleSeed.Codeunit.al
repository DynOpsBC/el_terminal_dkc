codeunit 72273 "DOPSWHS App Role Seed"
{
    // Idempotent seed of the 7 default WMS roles + their starter filter rules.
    // Called from Install/Upgrade. Each role is marked Is System := true so it cannot be
    // deleted from the admin UI accidentally; rules below the system role can be edited.
    Access = Public;

    procedure Seed()
    begin
        // Operator — no rules, full visibility.
        EnsureRole('OPERATOR', 'Generic warehouse operator (full visibility)', 10, true, true);

        // Picker
        EnsureRole('PICKER', 'Picks shipments assigned to me or unassigned', 20, true, true);
        EnsureRule('PICKER', Enum::"DOPSWHS App Filter Entity"::Pick, 16, 'Assigned User ID', '=%USER%|=''''');
        EnsureRule('PICKER', Enum::"DOPSWHS App Filter Entity"::PickLine, 21, 'Assigned User ID', '=%USER%|=''''');
        EnsureRule('PICKER', Enum::"DOPSWHS App Filter Entity"::Shipment, 16, 'Assigned User ID', '=%USER%|=''''');

        // Receiver
        EnsureRole('RECEIVER', 'Receives and put-aways assigned to me or unassigned', 30, true, true);
        EnsureRule('RECEIVER', Enum::"DOPSWHS App Filter Entity"::Receipt, 16, 'Assigned User ID', '=%USER%|=''''');
        EnsureRule('RECEIVER', Enum::"DOPSWHS App Filter Entity"::PutAway, 16, 'Assigned User ID', '=%USER%|=''''');

        // Shipper
        EnsureRole('SHIPPER', 'Ships outbound documents from my default location', 40, true, true);
        EnsureRule('SHIPPER', Enum::"DOPSWHS App Filter Entity"::Shipment, 16, 'Assigned User ID', '=%USER%|=''''');

        // Counter
        EnsureRole('COUNTER', 'Count sheets assigned to me, open only', 50, true, true);
        EnsureRule('COUNTER', Enum::"DOPSWHS App Filter Entity"::CountSheet, 30, 'Status', '=Open');

        // Quality
        EnsureRole('QUALITY', 'Quality orders assigned to me or unassigned, open/in-progress', 60, true, true);
        EnsureRule('QUALITY', Enum::"DOPSWHS App Filter Entity"::QualityOrder, 60, 'Inspector', '=%USER%|=''''');

        // Inventory Admin — broad. Show test/admin tools.
        EnsureRole('INV_ADMIN', 'Inventory admin (broad view, sees admin tools)', 70, false, false);
    end;

    local procedure EnsureRole(RoleCode: Code[20]; Description: Text[100]; SortOrder: Integer; HideTest: Boolean; HideAdmin: Boolean)
    var
        Role: Record "DOPSWHS App Role";
    begin
        if Role.Get(RoleCode) then
            exit;
        Role.Init();
        Role.Code := RoleCode;
        Role.Description := Description;
        Role."Sort Order" := SortOrder;
        Role.Active := true;
        Role."Is System" := true;
        Role."Hide Test Tools" := HideTest;
        Role."Hide Admin Tools" := HideAdmin;
        Role.Insert(true);
    end;

    local procedure EnsureRule(RoleCode: Code[20]; Entity: Enum "DOPSWHS App Filter Entity"; FieldNo: Integer; FieldName: Text[80]; Expression: Text[250])
    var
        Rule: Record "DOPSWHS App Role Filter Rule";
    begin
        Rule.SetRange("Role Code", RoleCode);
        Rule.SetRange("Entity", Entity);
        Rule.SetRange("Field No.", FieldNo);
        if not Rule.IsEmpty() then
            exit;
        Rule.Init();
        Rule."Role Code" := RoleCode;
        Rule."Entity" := Entity;
        Rule."Field No." := FieldNo;
        Rule."Field Name Hint" := FieldName;
        Rule."Filter Expression" := Expression;
        Rule."Combine Mode" := Rule."Combine Mode"::Append;
        Rule.Insert(true);
    end;
}
