codeunit 72281 "DOPSWHS Quick User Provision"
{
    // Tek-noktadan kullanıcı atama. Hem AL kod'undan (Install/Upgrade,
    // demo seed) hem de Role Center Quick User Assign sayfasından çağrılır.
    //
    // Sorumluluklar:
    //   1. BC User kaydının (T2000000120) varlığını idempotent garanti et —
    //      M365 sync ile gelmiş olmalı; yoksa adminin önce M365 invite +
    //      "Get users from Microsoft 365" yapması gerek. Burada yeni User
    //      kaydı oluşturmuyoruz (Microsoft entitlement gerekir).
    //   2. "D365 BUS PREMIUM" permission set'ini ata (yoksa)
    //   3. DOPSWHS App User Role tablosuna idempotent satır ekle
    //   4. Audit log alanları (Assigned DateTime, Assigned By) doldur
    //   5. Demo seed: Kaan ve test ekibi için sabit liste
    Access = Public;

    var
        UserNotInBCErr: Label 'BC user not found: %1. Önce admin M365 invite + BC "Users" sayfasında "Get users from Microsoft 365" yapsın (action: page 9800 Users Get users from Microsoft 365).', Comment = '%1 = email';
        RoleNotFoundErr: Label 'WMS rolü tanımlı değil: %1. AppRoleSeed çalıştırın.', Comment = '%1 = role code';
        AssignedMsg: Label '%1 %2 atandı.', Comment = '%1 = email, %2 = role';
        AlreadyAssignedMsg: Label '%1 zaten %2 rolüne sahip.', Comment = '%1 = email, %2 = role';
        DemoSetCompleteMsg: Label 'Demo kullanıcı seti hazır: %1 atama tamamlandı.', Comment = '%1 = count';

    /// <summary>
    /// Bir kullanıcıya bir WMS rolünü idempotent atar. Çağrı sayıldığında
    /// `True` döner (yeni atama yapıldı), zaten varsa `False`.
    /// </summary>
    /// <param name="Email">User principal name (örn 'kaanodabas@dynamicsops.com')</param>
    /// <param name="RoleCode">'INV_ADMIN', 'PICKER', 'RECEIVER', vb.</param>
    procedure EnsureUserRole(Email: Code[50]; RoleCode: Code[20]): Boolean
    var
        UserRec: Record User;
        Role: Record "DOPSWHS App Role";
        UserRole: Record "DOPSWHS App User Role";
    begin
        // 1. BC User kaydı var mı? Yoksa M365 senkronizasyonu dene (best-effort).
        if not LookupBCUser(Email, UserRec) then begin
            TrySyncFromM365();
            if not LookupBCUser(Email, UserRec) then
                Error(UserNotInBCErr, Email);
        end;

        // 2. WMS rolü tanımlı mı?
        if not Role.Get(RoleCode) then
            Error(RoleNotFoundErr, RoleCode);

        // 3. Idempotent insert
        if UserRole.Get(Email, RoleCode) then
            exit(false);

        UserRole.Init();
        UserRole."User ID" := Email;
        UserRole."Role Code" := RoleCode;
        UserRole.Priority := 100;
        UserRole.Disabled := false;
        UserRole."Assigned DateTime" := CurrentDateTime();
        UserRole."Assigned By" := CopyStr(UserId(), 1, 50);
        UserRole.Insert(true);

        // 4. BC permission set ataması (idempotent)
        AssignWMSPermissionSet(Email);

        exit(true);
    end;

    /// <summary>
    /// Bir kullanıcıdan WMS rolünü kaldırır. Idempotent: yoksa hata yok.
    /// </summary>
    procedure RemoveUserRole(Email: Code[50]; RoleCode: Code[20]): Boolean
    var
        UserRole: Record "DOPSWHS App User Role";
    begin
        if not UserRole.Get(Email, RoleCode) then
            exit(false);
        UserRole.Delete(true);
        exit(true);
    end;

    /// <summary>
    /// BC Premium permission set'i kullanıcıya idempotent ata. M365 sync
    /// genelde otomatik yapar; bu emniyet kemeri.
    /// </summary>
    procedure AssignWMSPermissionSet(Email: Code[50])
    var
        UserRec: Record User;
        AccessControl: Record "Access Control";
    begin
        if not LookupBCUser(Email, UserRec) then exit;

        AccessControl.SetRange("User Security ID", UserRec."User Security ID");
        AccessControl.SetRange("Role ID", 'D365 BUS PREMIUM');
        if not AccessControl.IsEmpty() then exit;

        AccessControl.Init();
        AccessControl."User Security ID" := UserRec."User Security ID";
        AccessControl."Role ID" := 'D365 BUS PREMIUM';
        AccessControl.Scope := AccessControl.Scope::System;
        if AccessControl.Insert(true) then;
    end;

    /// <summary>
    /// BC SaaS'ta M365 BC user sync için PTE'lere açık bir codeunit yok
    /// (`Codeunit "Azure AD User Management".CreateNewUsersFromAzureAD()`
    /// OnPrem scope, AppSource extensiyonlarından çağrılamaz). Bu stub
    /// no-op; admin BC web UI'da page 9800 "Users" "Get users from
    /// Microsoft 365" action'ını manuel tetiklemeli, sonra Quick Assign
    /// tekrar deneyebilir. EnsureUserRole hata mesajı bu adımı söyler.
    /// </summary>
    [TryFunction]
    procedure TrySyncFromM365()
    begin
        // intentionally empty — no SaaS-safe API available as of BC 28.x
    end;

    /// <summary>
    /// BC User tablosunda email match'ini bulur. "Authentication Email"
    /// ya da "User Name" alanlarından biriyle eşleşirse `true` döner.
    /// </summary>
    local procedure LookupBCUser(Email: Code[50]; var UserRec: Record User): Boolean
    begin
        UserRec.Reset();
        UserRec.SetRange("Authentication Email", Email);
        if UserRec.FindFirst() then exit(true);
        UserRec.Reset();
        UserRec.SetRange("User Name", Email);
        exit(UserRec.FindFirst());
    end;

    /// <summary>
    /// Demo / pilot ortamı için sabit kullanıcı seti. Kaan + Deniz
    /// admin olarak otomatik atanır. Idempotent — tekrar çalıştırılabilir.
    /// </summary>
    procedure ProvisionDemoUsers(): Integer
    var
        Count: Integer;
    begin
        Count := 0;
        if TryEnsureUserRole('kaanodabas@dynamicsops.com', 'INV_ADMIN') then Count += 1;
        if TryEnsureUserRole('Deniz@dynamicsops.com', 'INV_ADMIN') then Count += 1;
        Message(DemoSetCompleteMsg, Count);
        exit(Count);
    end;

    /// <summary>
    /// EnsureUserRole'u try-mode'da çağırır; hata olursa false döner.
    /// Demo seed sırasında 1 user eksikse diğerleri devam etsin diye.
    /// </summary>
    [TryFunction]
    local procedure TryEnsureUserRole(Email: Code[50]; RoleCode: Code[20])
    begin
        EnsureUserRole(Email, RoleCode);
    end;

    /// <summary>
    /// UI'dan çağrı için: tek user atama + result message. Page üzerinden
    /// trigger edildiğinde operatöre net feedback verir.
    /// </summary>
    procedure AssignWithFeedback(Email: Code[50]; RoleCode: Code[20])
    begin
        if EnsureUserRole(Email, RoleCode) then
            Message(AssignedMsg, Email, RoleCode)
        else
            Message(AlreadyAssignedMsg, Email, RoleCode);
    end;
}
