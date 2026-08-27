page 72279 "DOPSWHS App User Role API"
{
    // Web/mobile admin için rol atama API'sı. Şimdiye kadar
    // "DOPSWHS App User Role" tablosuna sadece BC içi ListPart sayfasından
    // satır eklenebiliyordu — yeni kullanıcıyı WMS'e onboard etmek için
    // BC sandbox'a manuel girmek gerekiyordu.
    //
    // Bu API page operatör/yönetici/script tarafından OData POST ile
    // rol ataması yapmayı mümkün kılar.
    //
    // Örnek:
    //   POST .../warehouse/v2.0/companies(<id>)/appUserRoles
    //   { "userId": "kaanodabas@dynamicsops.com", "roleCode": "INV_ADMIN" }
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'appUserRole';
    EntitySetName = 'appUserRoles';
    SourceTable = "DOPSWHS App User Role";
    DelayedInsert = true;
    ODataKeyFields = "User ID", "Role Code";
    Caption = 'WMS App User Role API';
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(userId; Rec."User ID") { Caption = 'userId'; }
                field(roleCode; Rec."Role Code") { Caption = 'roleCode'; }
                field(priority; Rec.Priority) { Caption = 'priority'; }
                field(disabled; Rec.Disabled) { Caption = 'disabled'; }
                field(assignedDateTime; Rec."Assigned DateTime")
                {
                    Caption = 'assignedDateTime';
                    Editable = false;
                }
                field(assignedBy; Rec."Assigned By")
                {
                    Caption = 'assignedBy';
                    Editable = false;
                }
            }
        }
    }
}
