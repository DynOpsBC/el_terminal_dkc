page 72263 "DOPSWHS App User Profile List"
{
    PageType = List;
    SourceTable = "DOPSWHS App User Profile";
    Caption = 'WMS App User Profiles';
    ApplicationArea = All;
    UsageCategory = Lists;
    CardPageId = "DOPSWHS App User Profile Card";

    layout
    {
        area(Content)
        {
            repeater(Profiles)
            {
                field("User ID"; Rec."User ID") { ApplicationArea = All; }
                field("Description"; Rec."Description") { ApplicationArea = All; }
                field("Config Code"; Rec."Config Code") { ApplicationArea = All; }
                field("Default Location Code"; Rec."Default Location Code") { ApplicationArea = All; }
                field("Default Bin Code"; Rec."Default Bin Code") { ApplicationArea = All; }
                field("Only My Picks"; Rec."Only My Picks") { ApplicationArea = All; }
                field("Only My Receipts"; Rec."Only My Receipts") { ApplicationArea = All; }
                field("LP Status Filter"; Rec."LP Status Filter") { ApplicationArea = All; }
                field("Disabled"; Rec."Disabled") { ApplicationArea = All; }
            }
        }
    }
}
