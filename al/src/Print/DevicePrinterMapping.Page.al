page 72298 "DOPSWHS Device Printer Map"
{
    Caption = 'Device Printer Mapping';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "DOPSWHS Device Printer Map";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Device ID"; Rec."Device ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Leave blank for tenant-wide defaults.';
                }
                field(Usage; Rec.Usage) { ApplicationArea = All; }
                field("Printer Code"; Rec."Printer Code") { ApplicationArea = All; }
                field("Station ID"; Rec."Station ID") { ApplicationArea = All; }
                field(Copies; Rec.Copies) { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
            }
        }
    }
}
