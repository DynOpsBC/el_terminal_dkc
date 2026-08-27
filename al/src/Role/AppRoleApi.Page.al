page 72278 "DOPSWHS App Role API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'appRole';
    EntitySetName = 'appRoles';
    SourceTable = "DOPSWHS App Role";
    DelayedInsert = true;
    ODataKeyFields = "Code";
    Caption = 'WMS App Role API';

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(code; Rec.Code) { Caption = 'code'; }
                field(description; Rec.Description) { Caption = 'description'; }
                field(active; Rec.Active) { Caption = 'active'; }
                field(isSystem; Rec."Is System") { Caption = 'isSystem'; }
                field(sortOrder; Rec."Sort Order") { Caption = 'sortOrder'; }
                field(hideTestTools; Rec."Hide Test Tools") { Caption = 'hideTestTools'; }
                field(hideAdminTools; Rec."Hide Admin Tools") { Caption = 'hideAdminTools'; }
                field(memberCount; Rec."Member Count") { Caption = 'memberCount'; Editable = false; }
                field(ruleCount; Rec."Rule Count") { Caption = 'ruleCount'; Editable = false; }
            }
        }
    }

    /// <summary>Idempotently assigns this role to a user. Used by mobile/admin bootstrap scripts
    /// to provision DOPSWHS role membership without going through the BC web client.</summary>
    [ServiceEnabled]
    procedure assignToUser(userId: Code[50])
    var
        UserRole: Record "DOPSWHS App User Role";
    begin
        if UserRole.Get(userId, Rec.Code) then begin
            if UserRole.Disabled then begin
                UserRole.Disabled := false;
                UserRole.Modify(true);
            end;
            exit;
        end;
        UserRole.Init();
        UserRole."User ID" := userId;
        UserRole."Role Code" := Rec.Code;
        UserRole.Insert(true);
    end;
}

