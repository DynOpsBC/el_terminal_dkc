controladdin "DOPSWHS Pick Board"
{
    RequestedHeight = 700;
    MinimumHeight = 400;
    RequestedWidth = 900;
    MinimumWidth = 480;
    VerticalStretch = true;
    HorizontalStretch = true;
    Scripts = 'Resources/pickBoard.js';
    StyleSheets = 'Resources/pickBoard.css';
    StartupScript = 'Resources/pickBoard.js';

    procedure SetData(Json: Text);
    procedure SetLocale(LocaleCode: Text);
    procedure ApplyFilter(FilterJson: Text);

    event ControlReady();
    event Reassign(PickNo: Code[20]; UserId: Code[50]);
    event RequestRefresh();
}
