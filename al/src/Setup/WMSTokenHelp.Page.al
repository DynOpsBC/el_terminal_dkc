page 72009 "DOPSWHS WMS Token Help"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'WMS Token Help — Web/Mobile uygulamaya bağlantı';
    SourceTable = Integer;
    SourceTableTemporary = true;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(Overview)
            {
                Caption = '1. Genel Bakış';
                label(OverviewMsg)
                {
                    ApplicationArea = All;
                    Caption = 'BCWMS web (tarayıcı) ve mobil (Android) operatör uygulamaları BC SaaS''e AAD bearer token ile bağlanır. Mobil uygulama Device Code Grant''ı otomatik kullanır; web uygulaması ve mobil "Gelişmiş: token yapıştır" yedek akışı için token gerekir. Tokenı BC üzerinden veya iş istasyonunuzdan üretebilirsiniz.';
                }
            }
            group(BcGenerationLimit)
            {
                Caption = '2. BC üzerinden token üretmek mümkün mü?';
                label(BcLimitAnswer)
                {
                    ApplicationArea = All;
                    Caption = 'KISA CEVAP: BC SaaS''ta uzantı kodu (extension) doğrudan AAD bearer token üretemez. Microsoft, güvenlik gerekçesiyle OAuth2.AcquireOnBehalfOfToken gibi method''ları extension scope''una kapalı tutar (OnPrem''e açık). Bu yüzden token''ı kullanıcı, kendi iş istasyonunda (az CLI / PowerShell / curl) üretir; aşağıdaki Method 3-5 buna yöneliktir. BC bu sayfada sadece komutları toplu sunar, kopyala-yapıştır akışını hızlandırır.';
                }
                label(BcLimitWorkaround)
                {
                    ApplicationArea = All;
                    Caption = 'ALTERNATİF: Çok-istasyonlu kurulumda BC tenant''ına özel bir confidential AAD app + Azure Function deploy edilirse, BC üzerindeki bir action HTTP ile bu function''a delegated impersonation isteyebilir. Bu bir entegrasyon projesi — bkz. docs/wms-token-generation.md › "Otomatik Token Yenileyici" bölümü.';
                }
                field(TokenInputForCheck; TokenInputForCheck)
                {
                    ApplicationArea = All;
                    Caption = 'Token doğrulayıcı (opsiyonel): üreteceğiniz token''ı buraya yapıştırın';
                    MultiLine = true;
                    ToolTip = 'az CLI veya PowerShell ile aldığınız token''ı buraya yapıştırın, ▶ Token Doğrula aksiyonuyla JWT içeriğindeki tenant + scope + bitiş zamanını gösterir. Yapıştırılan token sadece bellekte tutulur, kaydedilmez.';
                }
                field(TokenStatusField; TokenStatusMsg)
                {
                    ApplicationArea = All;
                    Caption = 'Durum';
                    Editable = false;
                    StyleExpr = TokenStatusStyle;
                }
            }
            group(Method1)
            {
                Caption = '3. Alternatif — Azure CLI (her platform)';
                label(Method1Step1)
                {
                    ApplicationArea = All;
                    Caption = 'Adım 1: Azure CLI''yi kur (https://aka.ms/azcli) ve "az login" ile BC tenant''ına giriş yap (Deniz@dynamicsops.com).';
                }
                field(Method1Cmd; Method1Cmd)
                {
                    ApplicationArea = All;
                    Caption = 'Adım 2: Aşağıdaki komutu Terminal/PowerShell''e yapıştır + çalıştır (1 saat geçerli token kopyalanır)';
                    Editable = false;
                    MultiLine = true;
                    ToolTip = 'Komut çıktısı standard output''a yazılır. macOS''ta "| pbcopy", Windows''ta "| Set-Clipboard" ekleyerek doğrudan kopyalayabilirsin.';
                }
                label(Method1Step3)
                {
                    ApplicationArea = All;
                    Caption = 'Adım 3: Token''ı Web App''in Login ekranındaki textarea''ya, veya Mobile App''in "Gelişmiş: token ile giriş" alanına yapıştır Bağlan';
                }
            }
            group(Method2)
            {
                Caption = '4. Alternatif — PowerShell (Windows)';
                field(Method2Cmd; Method2Cmd)
                {
                    ApplicationArea = All;
                    Caption = 'Microsoft.Identity.Client veya MSAL.PS modülü gerekir';
                    Editable = false;
                    MultiLine = true;
                }
            }
            group(Method3)
            {
                Caption = '5. Alternatif — curl üzerinden device code (tarayıcısız)';
                field(Method3Cmd; Method3Cmd)
                {
                    ApplicationArea = All;
                    Caption = 'Bir cihazda interactive login yapıp başka cihazda kullanmak için';
                    Editable = false;
                    MultiLine = true;
                }
            }
            group(URLs)
            {
                Caption = '6. Bağlantı uçları';
                field(WebUrl; WebUrl)
                {
                    ApplicationArea = All;
                    Caption = 'Web App URL';
                    Editable = false;
                    ExtendedDatatype = URL;
                }
                field(MobileApk; MobileApk)
                {
                    ApplicationArea = All;
                    Caption = 'Mobile APK (releases)';
                    Editable = false;
                    ExtendedDatatype = URL;
                }
                field(BcEnvironment; BcEnvironment)
                {
                    ApplicationArea = All;
                    Caption = 'BC Environment / Company (giriş ekranına yaz)';
                    Editable = false;
                }
                field(Resource; Resource)
                {
                    ApplicationArea = All;
                    Caption = 'AAD resource (token alırken)';
                    Editable = false;
                }
            }
            group(Notes)
            {
                Caption = '7. Notlar';
                label(NoteExpiry)
                {
                    ApplicationArea = All;
                    Caption = '• Token ömrü ~1 saat. Süre dolunca aynı komutla yenisini al ve yapıştır. Web app sağ üstte Bağlı değil gösterirse token expired demektir.';
                }
                label(NoteSecurity)
                {
                    ApplicationArea = All;
                    Caption = '• Token bir bearer secret''ıdır — paylaşma, screen-share ederken görünür yapma. Slack/Teams/email''e gönderme.';
                }
                label(NoteMobile)
                {
                    ApplicationArea = All;
                    Caption = '• Mobile app çoğu durumda Device Code Grant''ı (RFC 8628) kendi yapar; "Token yapıştır" sadece Wi-Fi olmayan kiosk cihazları için fallback''tür.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ValidateToken)
            {
                Caption = '▶ Token Doğrula (JWT decode)';
                ToolTip = 'Yapıştırılan token JWT''sinin payload''unu çözer. Tenant ID, scope, expiration time görüntülenir. Token kaydedilmez, sadece bu oturumda gösterilir.';
                ApplicationArea = All;
                Image = EncryptionKeys;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                trigger OnAction()
                begin
                    DoValidateToken();
                end;
            }
            action(CopyHint)
            {
                Caption = 'Kopyala-Yapıştır Akışı';
                ToolTip = 'Token''ı iş istasyonundan üretip BC ve WMS arasında nasıl taşıyacağınızı gösterir.';
                ApplicationArea = All;
                Image = SuggestLines;
                Promoted = true;
                PromotedCategory = Process;
                trigger OnAction()
                begin
                    Message(
                        'WMS Token akışı:\n\n' +
                        '1) İş istasyonunuzda terminal/PowerShell aç.\n' +
                        '2) Aşağıdaki "Method 1" alanındaki komutu kopyala (alanın içine tıkla Ctrl+A Ctrl+C).\n' +
                        '3) Terminal''e yapıştır, çalıştır. Komut sonunda "| pbcopy" (macOS) veya "| Set-Clipboard" (Win) varsa token doğrudan panonda olur.\n' +
                        '4) Tarayıcıda WMS web app''i aç Login ekranında token textarea''ya yapıştır  Bağlan.\n' +
                        '5) (Opsiyonel) Token''ı bu sayfadaki "Token Doğrulayıcı" alanına da yapıştırıp ▶ Token Doğrula ile içeriği kontrol et.');
                end;
            }
            action(OpenWebApp)
            {
                Caption = 'Web App''i tarayıcıda aç';
                ApplicationArea = All;
                Image = Web;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                trigger OnAction()
                begin
                    Hyperlink(WebUrl);
                end;
            }
            action(OpenAzCliDocs)
            {
                Caption = 'az CLI kurulum sayfası';
                ApplicationArea = All;
                Image = Link;
                Promoted = true;
                PromotedCategory = Process;
                trigger OnAction()
                begin
                    Hyperlink('https://learn.microsoft.com/cli/azure/install-azure-cli');
                end;
            }
            action(OpenMobileApk)
            {
                Caption = 'Mobile APK indir';
                ApplicationArea = All;
                Image = Download;
                Promoted = true;
                PromotedCategory = Process;
                trigger OnAction()
                begin
                    Hyperlink(MobileApk);
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        Method1Cmd :=
            'az account get-access-token \' + NL +
            '  --resource "https://api.businesscentral.dynamics.com" \' + NL +
            '  --query accessToken -o tsv | pbcopy   # macOS' + NL +
            '' + NL +
            'az account get-access-token `' + NL +
            '  --resource "https://api.businesscentral.dynamics.com" `' + NL +
            '  --query accessToken -o tsv | Set-Clipboard   # PowerShell/Windows';

        Method2Cmd :=
            'Connect-MgGraph -Scopes "user_impersonation"' + NL +
            '$token = Get-MsalToken -ClientId "04b07795-8ddb-461a-bbee-02f9e1bf7b46" `' + NL +
            '  -Authority "https://login.microsoftonline.com/7fa2357e-26f2-4174-8e16-a713981356b8" `' + NL +
            '  -Scopes "https://api.businesscentral.dynamics.com/.default"' + NL +
            '$token.AccessToken | Set-Clipboard';

        Method3Cmd :=
            '# Step 1: device code iste' + NL +
            'curl -s -X POST \' + NL +
            '  "https://login.microsoftonline.com/7fa2357e-26f2-4174-8e16-a713981356b8/oauth2/v2.0/devicecode" \' + NL +
            '  -d "client_id=04b07795-8ddb-461a-bbee-02f9e1bf7b46&scope=https://api.businesscentral.dynamics.com/.default offline_access"' + NL +
            '' + NL +
            '# Step 2: tarayıcıda https://microsoft.com/devicelogin user_code gir' + NL +
            '# Step 3: token al' + NL +
            'curl -s -X POST \' + NL +
            '  "https://login.microsoftonline.com/7fa2357e-26f2-4174-8e16-a713981356b8/oauth2/v2.0/token" \' + NL +
            '  -d "grant_type=urn:ietf:params:oauth:grant-type:device_code&client_id=04b07795-8ddb-461a-bbee-02f9e1bf7b46&device_code=<paste>"';

        WebUrl := 'http://127.0.0.1:5173/';
        MobileApk := 'https://github.com/DynOpsBC/WMS/releases';
        BcEnvironment := 'SandboxUS / CRONUS USA, Inc.';
        Resource := 'https://api.businesscentral.dynamics.com';
    end;

    local procedure DoValidateToken()
    var
        Base64: Codeunit "Base64 Convert";
        TokenText: Text;
        Parts: List of [Text];
        PayloadB64: Text;
        PayloadJson: Text;
        Payload: JsonObject;
        TokenObj: JsonToken;
        NowSec: BigInteger;
        ExpSec: BigInteger;
        Padding: Text;
        I: Integer;
    begin
        TokenText := TokenInputForCheck;
        if TokenText.Trim() = '' then begin
            TokenStatusStyle := 'Unfavorable';
            TokenStatusMsg := 'Token boş. Önce iş istasyonundan üretip yapıştırın.';
            exit;
        end;

        Parts := TokenText.Trim().Split('.');
        if Parts.Count < 3 then begin
            TokenStatusStyle := 'Unfavorable';
            TokenStatusMsg := 'Geçersiz JWT formatı (header.payload.signature 3 parça olmalı). Yapıştırılan metin JWT değil olabilir.';
            exit;
        end;

        PayloadB64 := Parts.Get(2);
        // Base64URL Base64 (gerçek '+' '/' ve padding)
        PayloadB64 := PayloadB64.Replace('-', '+');
        PayloadB64 := PayloadB64.Replace('_', '/');
        for I := 1 to (4 - (StrLen(PayloadB64) mod 4)) mod 4 do
            Padding += '=';
        PayloadB64 += Padding;

        if not TryDecodeBase64(Base64, PayloadB64, PayloadJson) then begin
            TokenStatusStyle := 'Unfavorable';
            TokenStatusMsg := 'Base64 decode başarısız. Token yapıştırılırken kırpılmış olabilir (boşluk/yeni satır?).';
            exit;
        end;

        if not Payload.ReadFrom(PayloadJson) then begin
            TokenStatusStyle := 'Unfavorable';
            TokenStatusMsg := 'JSON parse başarısız. Geçersiz token.';
            exit;
        end;

        NowSec := Round((CurrentDateTime() - CreateDateTime(20700101D, 0T)) / 1000, 1);
        if Payload.Get('exp', TokenObj) then
            ExpSec := TokenObj.AsValue().AsBigInteger()
        else
            ExpSec := 0;

        TokenStatusStyle := 'Favorable';
        TokenStatusMsg := BuildTokenSummary(Payload, ExpSec, NowSec);
    end;

    [TryFunction]
    local procedure TryDecodeBase64(var Base64: Codeunit "Base64 Convert"; B64: Text; var Decoded: Text)
    begin
        Decoded := Base64.FromBase64(B64);
    end;

    local procedure BuildTokenSummary(Payload: JsonObject; ExpSec: BigInteger; NowSec: BigInteger): Text[500]
    var
        Summary: Text;
        Tok: JsonToken;
        Remaining: Integer;
    begin
        if Payload.Get('upn', Tok) then
            Summary := 'Kullanıcı: ' + Tok.AsValue().AsText() + ' · ';
        if Payload.Get('tid', Tok) then
            Summary += 'Tenant: ' + Tok.AsValue().AsText() + ' · ';
        if Payload.Get('aud', Tok) then
            Summary += 'Audience: ' + Tok.AsValue().AsText() + ' · ';
        if Payload.Get('scp', Tok) then
            Summary += 'Scope: ' + Tok.AsValue().AsText() + ' · ';

        if ExpSec > 0 then begin
            Remaining := ExpSec - NowSec;
            if Remaining > 0 then
                Summary += StrSubstNo('Geçerli, %1 dakika kalan', Remaining div 60)
            else
                Summary += StrSubstNo('Süresi %1 dakika önce dolmuş', Abs(Remaining) div 60);
        end;

        exit(CopyStr(Summary, 1, 500));
    end;

    var
        Method1Cmd: Text;
        Method2Cmd: Text;
        Method3Cmd: Text;
        TokenInputForCheck: Text;
        TokenStatusMsg: Text[500];
        TokenStatusStyle: Text;
        WebUrl: Text[250];
        MobileApk: Text[250];
        BcEnvironment: Text[100];
        Resource: Text[100];
        NL: Label '\', Locked = true;
}
