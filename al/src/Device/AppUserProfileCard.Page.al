page 72264 "DOPSWHS App User Profile Card"
{
    PageType = Card;
    SourceTable = "DOPSWHS App User Profile";
    Caption = 'WMS App User Profile';
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("User ID"; Rec."User ID") { ApplicationArea = All; }
                field("Description"; Rec."Description") { ApplicationArea = All; }
                field("Config Code"; Rec."Config Code") { ApplicationArea = All; ToolTip = 'Hangi Device Configuration menüsünün/davranışlarının baz alınacağı.'; }
                field("Disabled"; Rec."Disabled") { ApplicationArea = All; }
            }
            group(Defaults)
            {
                Caption = 'Defaults';
                field("Default Location Code"; Rec."Default Location Code") { ApplicationArea = All; }
                field("Default Bin Code"; Rec."Default Bin Code") { ApplicationArea = All; }
                field("Locale"; Rec."Locale") { ApplicationArea = All; ToolTip = 'tr / en / de'; }
                field("Max List Rows"; Rec."Max List Rows") { ApplicationArea = All; }
            }
            group(MineFilters)
            {
                Caption = 'Only-Mine Filters';
                field("Only My Picks"; Rec."Only My Picks") { ApplicationArea = All; }
                field("Only My Receipts"; Rec."Only My Receipts") { ApplicationArea = All; }
                field("Only My PutAways"; Rec."Only My PutAways") { ApplicationArea = All; }
                field("Only My Shipments"; Rec."Only My Shipments") { ApplicationArea = All; }
                field("Only My Movements"; Rec."Only My Movements") { ApplicationArea = All; }
            }
            group(EntityFilters)
            {
                Caption = 'Entity Filters';
                field("LP Status Filter"; Rec."LP Status Filter") { ApplicationArea = All; }
                field("Quality Filter"; Rec."Quality Filter") { ApplicationArea = All; }
            }
            group(Hide)
            {
                Caption = 'Visibility';
                field("Hide Test Tools"; Rec."Hide Test Tools") { ApplicationArea = All; ToolTip = 'Posting Test / Test Center tile''larını gizle (non-admin kullanıcılar için).'; }
                field("Hide Admin Tools"; Rec."Hide Admin Tools") { ApplicationArea = All; }
            }
            part(Roles; "DOPSWHS App User Roles")
            {
                Caption = 'Roles';
                ApplicationArea = All;
                SubPageLink = "User ID" = field("User ID");
                UpdatePropagation = Both;
            }
        }
    }
}
