page 72266 "DOPSWHS App User Profile API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'appUserProfile';
    EntitySetName = 'appUserProfiles';
    SourceTable = "DOPSWHS App User Profile";
    DelayedInsert = true;
    ODataKeyFields = "User ID";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(userId; Rec."User ID") { Caption = 'userId'; }
                field(description; Rec."Description") { Caption = 'description'; }
                field(configCode; Rec."Config Code") { Caption = 'configCode'; }
                field(defaultLocationCode; Rec."Default Location Code") { Caption = 'defaultLocationCode'; }
                field(defaultBinCode; Rec."Default Bin Code") { Caption = 'defaultBinCode'; }
                field(locale; Rec."Locale") { Caption = 'locale'; }
                field(onlyMyPicks; Rec."Only My Picks") { Caption = 'onlyMyPicks'; }
                field(onlyMyReceipts; Rec."Only My Receipts") { Caption = 'onlyMyReceipts'; }
                field(onlyMyPutAways; Rec."Only My PutAways") { Caption = 'onlyMyPutAways'; }
                field(onlyMyShipments; Rec."Only My Shipments") { Caption = 'onlyMyShipments'; }
                field(onlyMyMovements; Rec."Only My Movements") { Caption = 'onlyMyMovements'; }
                field(lpStatusFilter; Rec."LP Status Filter") { Caption = 'lpStatusFilter'; }
                field(qualityFilter; Rec."Quality Filter") { Caption = 'qualityFilter'; }
                field(hideTestTools; Rec."Hide Test Tools") { Caption = 'hideTestTools'; }
                field(hideAdminTools; Rec."Hide Admin Tools") { Caption = 'hideAdminTools'; }
                field(maxListRows; Rec."Max List Rows") { Caption = 'maxListRows'; }
                field(disabled; Rec."Disabled") { Caption = 'disabled'; }
            }
        }
    }

    /// <summary>
    /// Returns the resolved JSON profile for the CURRENT authenticated user (ignores the bound Rec).
    /// Mobile calls: POST .../appUserProfiles('DEFAULT')/Microsoft.NAV.resolveCurrent on connect.
    /// </summary>
    [ServiceEnabled]
    procedure resolveCurrent(): Text
    var
        Mgmt: Codeunit "DOPSWHS App Profile Mgmt";
    begin
        exit(Mgmt.ResolveForCurrentUser());
    end;
}
