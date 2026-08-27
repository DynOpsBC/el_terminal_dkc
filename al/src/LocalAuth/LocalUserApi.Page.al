page 72284 "DOPSWHS Local User API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'localUser';
    EntitySetName = 'localUsers';
    SourceTable = "DOPSWHS Local User";
    DelayedInsert = true;
    ODataKeyFields = "Username";
    Caption = 'Local WMS User API';

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(username; Rec.Username) { Caption = 'username'; }
                field(displayName; Rec."Display Name") { Caption = 'displayName'; }
                field(defaultLocationCode; Rec."Default Location Code") { Caption = 'defaultLocationCode'; }
                field(defaultBinCode; Rec."Default Bin Code") { Caption = 'defaultBinCode'; }
                field(locale; Rec.Locale) { Caption = 'locale'; }
                field(hideTestTools; Rec."Hide Test Tools") { Caption = 'hideTestTools'; }
                field(hideAdminTools; Rec."Hide Admin Tools") { Caption = 'hideAdminTools'; }
                field(disabled; Rec.Disabled) { Caption = 'disabled'; }
                field(lastLoginDateTime; Rec."Last Login DateTime") { Caption = 'lastLoginDateTime'; Editable = false; }
                field(failedLoginCount; Rec."Failed Login Count") { Caption = 'failedLoginCount'; Editable = false; }
                // Password hash/salt asla expose edilmez.
            }
        }
    }

    /// <summary>Mobile app username + password ile login: doğru ise resolved profile JSON döner,
    /// yanlış ise hata. Authorize: çağıran AAD token'ı geçerli olmalı (admin/service token).</summary>
    [ServiceEnabled]
    procedure verify(password: Text): Text
    var
        AuthMgt: Codeunit "DOPSWHS Local Auth Mgmt";
    begin
        if AuthMgt.Verify(Rec.Username, password) then
            exit(AuthMgt.ResolveProfileJson(Rec.Username))
        else
            Error('Invalid username or password.');
    end;

    /// <summary>Admin-only: yeni kullanıcı oluştur ya da mevcut olanı güncelle (idempotent).</summary>
    [ServiceEnabled]
    procedure register(displayName: Text[100]; password: Text; defaultLocation: Code[10]; defaultBin: Code[20])
    var
        AuthMgt: Codeunit "DOPSWHS Local Auth Mgmt";
    begin
        AuthMgt.Register(Rec.Username, displayName, password, defaultLocation, defaultBin);
    end;

    /// <summary>Sadece şifreyi günceller.</summary>
    [ServiceEnabled]
    procedure changePassword(newPassword: Text)
    var
        AuthMgt: Codeunit "DOPSWHS Local Auth Mgmt";
    begin
        AuthMgt.UpdatePassword(Rec.Username, newPassword);
    end;

    /// <summary>Yerel kullanıcının çözümlenmiş profilini döner (roles + effectiveFilters dahil).
    /// Şifre doğrulamadan, kim olduğunu zaten bildiğimiz bağlamda (örn. login sonrası refresh).</summary>
    [ServiceEnabled]
    procedure resolveProfile(): Text
    var
        AuthMgt: Codeunit "DOPSWHS Local Auth Mgmt";
    begin
        exit(AuthMgt.ResolveProfileJson(Rec.Username));
    end;
}
