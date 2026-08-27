codeunit 72285 "DOPSWHS Local Auth Mgmt"
{
    // E-postası olmayan WMS operatörleri için yerel kimlik doğrulama yönetimi.
    // Şifre saklama: salt + password SHA-256 hex. Salt her kayıt için unique (GUID).
    // Verify: timing-attack korunması için her zaman hash hesaplar (kayıt bulunmasa bile).
    Access = Public;

    /// <summary>Yeni bir yerel kullanıcı oluşturur ya da mevcut olanı günceller (idempotent).
    /// Şifre düz metinde verilir, salt + hash hesaplanır.</summary>
    procedure Register(Username: Code[20]; DisplayName: Text[100]; PlainPassword: Text; DefaultLocation: Code[10]; DefaultBin: Code[20])
    var
        LocalUser: Record "DOPSWHS Local User";
        Salt: Text;
        Hash: Text;
    begin
        if Username = '' then
            Error('Kullanıcı adı boş olamaz.');
        if StrLen(PlainPassword) < 4 then
            Error('Şifre en az 4 karakter olmalı.');
        Salt := GenerateSalt();
        Hash := ComputeHash(Salt, PlainPassword);

        if LocalUser.Get(Username) then begin
            LocalUser."Display Name" := DisplayName;
            LocalUser."Password Hash" := CopyStr(Hash, 1, MaxStrLen(LocalUser."Password Hash"));
            LocalUser."Password Salt" := CopyStr(Salt, 1, MaxStrLen(LocalUser."Password Salt"));
            if DefaultLocation <> '' then
                LocalUser."Default Location Code" := DefaultLocation;
            if DefaultBin <> '' then
                LocalUser."Default Bin Code" := DefaultBin;
            LocalUser."Failed Login Count" := 0;
            LocalUser.Modify(true);
        end else begin
            LocalUser.Init();
            LocalUser.Username := Username;
            LocalUser."Display Name" := DisplayName;
            LocalUser."Password Hash" := CopyStr(Hash, 1, MaxStrLen(LocalUser."Password Hash"));
            LocalUser."Password Salt" := CopyStr(Salt, 1, MaxStrLen(LocalUser."Password Salt"));
            LocalUser."Default Location Code" := DefaultLocation;
            LocalUser."Default Bin Code" := DefaultBin;
            LocalUser.Insert(true);
        end;

        Session.LogMessage('AdvWMS.LocalAuth.UserRegistered',
            StrSubstNo('Local WMS user %1 registered/updated by %2.', Username, UserId()),
            Verbosity::Normal, DataClassification::EndUserIdentifiableInformation,
            TelemetryScope::ExtensionPublisher, GetEmptyDimensions());
    end;

    /// <summary>Sadece şifre günceller. Display name / location değişmez.</summary>
    procedure UpdatePassword(Username: Code[20]; NewPlainPassword: Text)
    var
        LocalUser: Record "DOPSWHS Local User";
        Salt: Text;
        Hash: Text;
    begin
        if not LocalUser.Get(Username) then
            Error('Kullanıcı bulunamadı: %1', Username);
        if StrLen(NewPlainPassword) < 4 then
            Error('Şifre en az 4 karakter olmalı.');
        Salt := GenerateSalt();
        Hash := ComputeHash(Salt, NewPlainPassword);
        LocalUser."Password Hash" := CopyStr(Hash, 1, MaxStrLen(LocalUser."Password Hash"));
        LocalUser."Password Salt" := CopyStr(Salt, 1, MaxStrLen(LocalUser."Password Salt"));
        LocalUser."Failed Login Count" := 0;
        LocalUser.Modify(true);
    end;

    /// <summary>Username + Password kombinasyonunu doğrular. Geçersiz/disabled kullanıcıda da
    /// dummy bir hash hesabı yaparak timing-attack'i önler.</summary>
    procedure Verify(Username: Code[20]; PlainPassword: Text): Boolean
    var
        LocalUser: Record "DOPSWHS Local User";
        DummySalt: Text;
        Found: Boolean;
        Match: Boolean;
    begin
        Found := LocalUser.Get(Username) and not LocalUser.Disabled;
        if Found then
            Match := ComputeHash(LocalUser."Password Salt", PlainPassword) = LocalUser."Password Hash"
        else begin
            DummySalt := 'dummy-salt-to-defeat-timing-attacks';
            ComputeHash(DummySalt, PlainPassword); // discard
            Match := false;
        end;

        if Found then begin
            if Match then begin
                LocalUser."Last Login DateTime" := CurrentDateTime();
                LocalUser."Failed Login Count" := 0;
                LocalUser.Modify(true);
                Session.LogMessage('AdvWMS.LocalAuth.LoginOk',
                    StrSubstNo('Local user %1 logged in.', Username),
                    Verbosity::Normal, DataClassification::EndUserIdentifiableInformation,
                    TelemetryScope::ExtensionPublisher, GetEmptyDimensions());
            end else begin
                LocalUser."Failed Login Count" += 1;
                LocalUser.Modify(true);
                Session.LogMessage('AdvWMS.LocalAuth.LoginFailed',
                    StrSubstNo('Local user %1 failed login (count=%2).', Username, LocalUser."Failed Login Count"),
                    Verbosity::Warning, DataClassification::EndUserIdentifiableInformation,
                    TelemetryScope::ExtensionPublisher, GetEmptyDimensions());
            end;
        end;
        exit(Match);
    end;

    /// <summary>Bir yerel kullanıcının çözümlenmiş profile JSON'unu döner — AppProfileMgmt.resolveCurrent
    /// ile aynı yapıda ama AAD UserId() yerine yerel username üzerinden roller resolve edilir.</summary>
    procedure ResolveProfileJson(Username: Code[20]): Text
    var
        LocalUser: Record "DOPSWHS Local User";
        FilterMgmt: Codeunit "DOPSWHS App Role Filter Mgmt";
        Json: TextBuilder;
        EffectiveLoc: Code[10];
    begin
        if not LocalUser.Get(Username) then begin
            Json.Append(StrSubstNo('{"userId":"%1","error":"local user not found"}', Username));
            exit(Json.ToText());
        end;
        EffectiveLoc := LocalUser."Default Location Code";

        Json.Append('{');
        Json.Append(StrSubstNo('"userId":"%1",', EscapeJson(LocalUser.Username)));
        Json.Append(StrSubstNo('"displayName":"%1",', EscapeJson(LocalUser."Display Name")));
        Json.Append('"authMode":"local",');
        Json.Append(StrSubstNo('"defaultLocationCode":"%1",', EscapeJson(EffectiveLoc)));
        Json.Append(StrSubstNo('"defaultBinCode":"%1",', EscapeJson(LocalUser."Default Bin Code")));
        Json.Append(StrSubstNo('"locale":"%1",', EscapeJson(LocalUser.Locale)));
        Json.Append(StrSubstNo('"hideTestTools":%1,', BoolText(LocalUser."Hide Test Tools")));
        Json.Append(StrSubstNo('"hideAdminTools":%1,', BoolText(LocalUser."Hide Admin Tools")));
        FilterMgmt.AppendRolesJson(Json, CopyStr(LocalUser.Username, 1, 50));
        Json.Append(',');
        FilterMgmt.AppendEffectiveFiltersJson(Json, CopyStr(LocalUser.Username, 1, 50));
        Json.Append('}');
        exit(Json.ToText());
    end;

    // --- private helpers ---

    local procedure GenerateSalt(): Text
    var
        SaltGuid: Guid;
    begin
        SaltGuid := CreateGuid();
        exit(DelChr(LowerCase(Format(SaltGuid)), '=', '{-}'));
    end;

    [NonDebuggable]
    local procedure ComputeHash(Salt: Text; PlainPassword: Text): Text
    var
        CryptMgt: Codeunit "Cryptography Management";
        ToHash: Text;
    begin
        ToHash := Salt + ':' + PlainPassword;
        // BC 24 Cryptography Management.GenerateHash uses Enum "Hash Algorithm"
        exit(LowerCase(CryptMgt.GenerateHash(ToHash, Enum::"Hash Algorithm"::SHA256)));
    end;

    local procedure EscapeJson(Value: Text): Text
    begin
        Value := Value.Replace('\', '\\');
        Value := Value.Replace('"', '\"');
        exit(Value);
    end;

    local procedure BoolText(B: Boolean): Text
    begin
        if B then exit('true');
        exit('false');
    end;

    local procedure GetEmptyDimensions(): Dictionary of [Text, Text]
    var
        Dims: Dictionary of [Text, Text];
    begin
        exit(Dims);
    end;
}
