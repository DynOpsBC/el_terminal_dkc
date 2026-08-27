codeunit 72032 "DOPSWHS Telemetry"
{
    Access = Public;
    // Operatörün görünen adını çözmek için yerel kullanıcı tablosu okunur.
    // NEDEN ayrı izin: telemetri her akıştan (post, scan, register) çağrılıyor;
    // izin eksikliği yüzünden log satırı hata fırlatırsa İŞLEM geri alınır.
    // İzin burada verilir, ayrıca ReadPermission() ile de korunur.
    Permissions = tabledata "DOPSWHS Local User" = r;

    procedure Log(Category: Text; Message: Text; Verbosity: Verbosity; CustomDimensions: Dictionary of [Text, Text])
    var
        EventId: Text;
    begin
        EventId := EnsureCategoryPrefix(Category);
        Session.LogMessage(EventId, Message, Verbosity, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;

    /// <summary>
    /// Geriye dönük imza: operatör kimliği bilinmiyor. Kullanıcı alanları yine
    /// yazılır, ancak WMS operatörü yerine oturumun BC hesabına düşülür.
    /// </summary>
    procedure LogInfo(Category: Text; Message: Text)
    begin
        LogInfo(Category, Message, '');
    end;

    /// <summary>
    /// İşlemi GERÇEKTEN yapan WMS operatörüyle birlikte loglar.
    ///
    /// NEDEN ayrı bir kullanıcı parametresi: bu kurulumda tüm BC çağrıları
    /// PAYLAŞIMLI bir servis hesabı üzerinden gidiyor; UserId() her istekte aynı
    /// hesabı (ör. DYNOPS) döndürüyor. Gerçek operatör terminaldeki
    /// "DOPSWHS Local User" oturumudur ve bound action'lara parametre olarak
    /// gelir (claim(userId), startPackingAs(userId), adHocMove(..., userId) ...).
    /// Sadece UserId() loglansaydı her satır aynı kullanıcıyı gösterir ve
    /// "bu işlemi kim yaptı" sorusu cevapsız kalırdı.
    /// </summary>
    procedure LogInfo(Category: Text; Message: Text; WmsUserId: Code[50])
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        AddUserDimensions(CustomDimensions, WmsUserId);
        Log(Category, Message, Verbosity::Normal, CustomDimensions);
    end;

    /// <summary>Uyarı seviyesinde, kullanıcı bilgisi taşıyan log.</summary>
    procedure LogWarning(Category: Text; Message: Text; WmsUserId: Code[50])
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        AddUserDimensions(CustomDimensions, WmsUserId);
        Log(Category, Message, Verbosity::Warning, CustomDimensions);
    end;

    /// <summary>
    /// Hazır bir CustomDimensions sözlüğüne kullanıcı alanlarını ekler.
    /// Session.LogMessage'ı doğrudan çağıran yerler (Movement, Count, Ship ...)
    /// de aynı alan adlarını yazabilsin diye Public: telemetride tek bir
    /// "kim yaptı" sözlüğü olsun, sorgu yazan her yerde ayrı alan aramasın.
    ///
    /// Yazılan alanlar:
    ///   bcUserId      - oturumun BC hesabı (paylaşımlı servis hesabı olabilir)
    ///   wmsUserId     - işlemi yapan operatör (bilinmiyorsa bcUserId)
    ///   operatorName  - operatörün görünen adı (yoksa kimliğin kendisi)
    ///   actorSource   - WMS: gerçek operatör biliniyor / BC: servis hesabına düşüldü
    /// </summary>
    procedure AddUserDimensions(var CustomDimensions: Dictionary of [Text, Text]; WmsUserId: Code[50])
    var
        Operator: Code[50];
    begin
        SetDimension(CustomDimensions, 'bcUserId', UserId());
        SetDimension(CustomDimensions, 'userSecurityId', Format(UserSecurityId()));

        if WmsUserId <> '' then begin
            Operator := WmsUserId;
            SetDimension(CustomDimensions, 'actorSource', 'WMS');
        end else begin
            // Operatör kimliği çağrı zincirinde taşınmıyor: log satırı servis
            // hesabını gösterir. Bu ayrımı ayrıca işaretliyoruz ki telemetriye
            // bakan kişi "DYNOPS gerçekten bu işi yaptı" sanmasın.
            Operator := CopyStr(UserId(), 1, MaxStrLen(Operator));
            SetDimension(CustomDimensions, 'actorSource', 'BC');
        end;

        SetDimension(CustomDimensions, 'wmsUserId', Operator);
        SetDimension(CustomDimensions, 'operatorName', ResolveOperatorName(Operator));
    end;

    /// <summary>
    /// Operatörün görünen adını ("Ahmet Yılmaz") döndürür; çözülemezse kimliğin
    /// kendisini. Hiçbir koşulda hata fırlatmaz — log çağrısı iş akışını
    /// düşürmemeli (bkz. codeunit başındaki Permissions notu).
    /// </summary>
    procedure ResolveOperatorName(UserIdValue: Code[50]): Text
    var
        LocalUser: Record "DOPSWHS Local User";
    begin
        if UserIdValue = '' then
            exit('');
        if not LocalUser.ReadPermission() then
            exit(UserIdValue);
        // Code[50] kimlik Username'e (Code[20]) sığmıyorsa yerel kullanıcı olamaz;
        // CopyStr ile kırpıp yanlış kullanıcıyı eşleştirmeyelim.
        if StrLen(UserIdValue) > MaxStrLen(LocalUser.Username) then
            exit(UserIdValue);
        if not LocalUser.Get(CopyStr(UserIdValue, 1, MaxStrLen(LocalUser.Username))) then
            exit(UserIdValue);
        if LocalUser."Display Name" = '' then
            exit(UserIdValue);
        exit(LocalUser."Display Name");
    end;

    local procedure SetDimension(var CustomDimensions: Dictionary of [Text, Text]; DimensionName: Text; DimensionValue: Text)
    begin
        if DimensionValue = '' then
            exit;
        // Çağıran sözlüğü hazır doldurmuş olabilir (Movement/Ship desenleri):
        // Add çift anahtarda hata verir, bu yüzden varsa üzerine yazılır.
        if CustomDimensions.ContainsKey(DimensionName) then
            CustomDimensions.Set(DimensionName, DimensionValue)
        else
            CustomDimensions.Add(DimensionName, DimensionValue);
    end;

    local procedure EnsureCategoryPrefix(Category: Text): Text
    begin
        if CopyStr(Category, 1, 7) = 'AdvWMS-' then
            exit(Category);

        exit('AdvWMS-' + Category);
    end;
}
