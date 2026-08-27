page 72066 "DOPSWHS Device Reg List"
{
    PageType = List;
    SourceTable = "DOPSWHS Device Registration";
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'DOPSWHS Device Registrations';

    layout { area(Content) { repeater(General) {
        field("Device ID"; Rec."Device ID") { ApplicationArea = All; }
        field(Fingerprint; Rec.Fingerprint) { ApplicationArea = All; }
        field("App Version"; Rec."App Version") { ApplicationArea = All; }
        field("Last Seen DateTime"; Rec."Last Seen DateTime") { ApplicationArea = All; }
        field(Active; Rec.Active) { ApplicationArea = All; }
        field("Assigned User"; Rec."Assigned User") { ApplicationArea = All; }
        field("Config Code"; Rec."Config Code") { ApplicationArea = All; }
    } } }
}
