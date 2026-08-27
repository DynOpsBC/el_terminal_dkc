page 72486 "DOPSWHS Shipment LP Factbox"
{
    PageType = ListPart;
    SourceTable = "DOPSWHS LP Header";
    ApplicationArea = All;
    Caption = 'Shipping License Plates';

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.") { ApplicationArea = All; Caption = 'LP No.'; }
                field(SSCC; Rec.SSCC) { ApplicationArea = All; Caption = 'SSCC'; }
                field(Status; Rec.Status) { ApplicationArea = All; Caption = 'Status'; }
                field("Bin Code"; Rec."Bin Code") { ApplicationArea = All; Caption = 'Bin Code'; }
            }
        }
    }
}
