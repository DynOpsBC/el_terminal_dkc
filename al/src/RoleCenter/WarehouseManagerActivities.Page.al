page 72489 "DOPSWHS Warehouse Manager Act"
{
    Caption = 'Warehouse Manager Activities';
    PageType = CardPart;
    SourceTable = "DOPSWHS Warehouse Mgr Cue";
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            cuegroup(Warehouse)
            {
                Caption = 'Warehouse';
                field("Open Receipts"; Rec."Open Receipts") { ApplicationArea = All; DrillDownPageId = "Warehouse Receipts"; }
                field("Open Picks"; Rec."Open Picks") { ApplicationArea = All; DrillDownPageId = "Warehouse Picks"; }
                field("Open Shipments"; Rec."Open Shipments") { ApplicationArea = All; DrillDownPageId = "Warehouse Shipment List"; }
                field("Late Picks"; Rec."Late Picks") { ApplicationArea = All; DrillDownPageId = "Warehouse Picks"; }
                field("Unbuilt LPs"; Rec."Unbuilt LPs") { ApplicationArea = All; DrillDownPageId = "DOPSWHS LP List"; }
                field("Count Discrepancies"; Rec."Count Discrepancies") { ApplicationArea = All; DrillDownPageId = "DOPSWHS Count Sheet List"; }
                field("Devices Online"; Rec."Devices Online") { ApplicationArea = All; DrillDownPageId = "DOPSWHS Device Reg List"; }
            }
            cuegroup(PackStation)
            {
                Caption = 'Pick & Packing';
                field("Open Picking Orders"; Rec."Open Picking Orders") { ApplicationArea = All; DrillDownPageId = "DOPSWHS Picking Order List"; }
                field("Orders Ready for Packing"; Rec."Orders Ready for Packing") { ApplicationArea = All; DrillDownPageId = "DOPSWHS Packing Order List"; }
                field("Orders Being Packed"; Rec."Orders Being Packed") { ApplicationArea = All; DrillDownPageId = "DOPSWHS Packing Order List"; }
            }
        }
    }

    trigger OnOpenPage()
    begin
        if not Rec.Get('') then begin
            Rec.Init();
            Rec.Insert(true);
        end;
        Rec.SetFilter("Late Pick Date Filter", '..%1', Today() - 1);
        Rec.SetFilter("Online Since DateTime Filter", '%1..', CurrentDateTime() - (5 * 60 * 1000));
    end;
}
