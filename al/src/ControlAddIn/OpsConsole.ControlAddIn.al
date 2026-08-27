controladdin "DOPSWHS Ops Console"
{
    // Yönetim/ofis konsolu — BC sayfası içine gömülü React SPA. Süpervizör
    // masaüstünden işleri (pick/put-away/sevkiyat/sayım) izler ve kullanıcılara
    // atar; el terminali yalnız fiziksel yürütmeyi yapar (toplantı isteği).
    RequestedHeight = 760;
    MinimumHeight = 400;
    RequestedWidth = 1000;
    MinimumWidth = 520;
    VerticalStretch = true;
    HorizontalStretch = true;
    Scripts = 'Resources/opsConsole.js';
    StyleSheets = 'Resources/opsConsole.css';
    StartupScript = 'Resources/opsConsole.js';

    procedure SetData(Json: Text);
    procedure SetLocale(LocaleCode: Text);
    procedure NotifyResult(Json: Text);

    event ControlReady();
    event AssignDoc(DocType: Text; DocNo: Code[20]; UserId: Code[50]);
    event RequestRefresh();
    // ELOG multi akışı: seçili siparişleri tek pick'te grupla ve kullanıcıya ata.
    event CreateMultiPick(OrderNosCsv: Text; UserId: Code[50]);
}
