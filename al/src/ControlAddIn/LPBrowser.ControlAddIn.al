controladdin "DOPSWHS LP Browser"
{
    RequestedHeight = 600;
    MinimumHeight = 320;
    MaximumHeight = 1200;
    RequestedWidth = 900;
    MinimumWidth = 480;
    HorizontalStretch = true;
    VerticalStretch = true;
    Scripts = 'Resources/lpBrowser.js';
    StyleSheets = 'Resources/lpBrowser.css';
    StartupScript = 'Resources/lpBrowser.js';

    procedure SetData(json: Text);
    procedure SetLocale(code: Text);
    procedure RefreshTree();

    event ControlReady();
    event NestLp(childLpNo: Text; parentLpNo: Text);
    event UnnestLp(childLpNo: Text);
    event PrintLabel(lpNo: Text; printerId: Text);
    event MoveLpToBin(lpNo: Text; binCode: Text);
}
