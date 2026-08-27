page 72096 "DOPSWHS DynOps WMS Activities"
{
    Caption = 'DynOps WMS Activities';
    PageType = CardPart;
    SourceTable = "DOPSWHS DynOps WMS Cue";
    RefreshOnActivate = true;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            // ===== MAL KABUL =====
            cuegroup(MalKabul)
            {
                Caption = 'Mal Kabul';
                field("Open Whse Receipts"; Rec."Open Whse Receipts") { ApplicationArea = All; DrillDownPageId = "Warehouse Receipts"; }
                field("PO Pending Receive"; Rec."PO Pending Receive") { ApplicationArea = All; DrillDownPageId = "Purchase Order List"; }
                field("Transfer In Pending"; Rec."Transfer In Pending") { ApplicationArea = All; DrillDownPageId = "Transfer Orders"; }
            }

            // ===== YERLEŞTIRME =====
            cuegroup(Yerlestirme)
            {
                Caption = 'Yerleştirme';
                field("Open PutAways"; Rec."Open PutAways") { ApplicationArea = All; DrillDownPageId = "Warehouse Put-aways"; }
                field("Invt PutAways"; Rec."Invt PutAways") { ApplicationArea = All; DrillDownPageId = "Inventory Put-aways"; }
            }

            // ===== TOPLAMA =====
            cuegroup(Toplama)
            {
                Caption = 'Toplama';
                field("Open Picks"; Rec."Open Picks") { ApplicationArea = All; DrillDownPageId = "Warehouse Picks"; }
                field("Invt Picks"; Rec."Invt Picks") { ApplicationArea = All; DrillDownPageId = "Inventory Picks"; }
                field("Late Picks"; Rec."Late Picks") { ApplicationArea = All; DrillDownPageId = "Warehouse Picks"; }
            }

            // ===== SEVKIYAT =====
            cuegroup(Sevkiyat)
            {
                Caption = 'Sevkiyat';
                field("Released Shipments"; Rec."Released Shipments") { ApplicationArea = All; DrillDownPageId = "Warehouse Shipment List"; }
                field("Sales Ship Pending"; Rec."Sales Ship Pending") { ApplicationArea = All; DrillDownPageId = "Sales Order List"; }
                field("Transfer Ship Pending"; Rec."Transfer Ship Pending") { ApplicationArea = All; DrillDownPageId = "Transfer Orders"; }
            }

            // ===== HAREKETLER =====
            cuegroup(Hareketler)
            {
                Caption = 'Hareketler';
                field("Open Movements"; Rec."Open Movements") { ApplicationArea = All; DrillDownPageId = "Warehouse Activity List"; }
                field("Invt Movements"; Rec."Invt Movements") { ApplicationArea = All; DrillDownPageId = "Inventory Movement"; }
            }

            // ===== ÜRETİM + MONTAJ =====
            cuegroup(Uretim)
            {
                Caption = 'Üretim ve Montaj';
                field("Released Prod Orders"; Rec."Released Prod Orders") { ApplicationArea = All; DrillDownPageId = "Released Production Orders"; }
                field("Open Assembly"; Rec."Open Assembly") { ApplicationArea = All; DrillDownPageId = "Assembly Orders"; }
            }

            // ===== LICENSE PLATE =====
            cuegroup(LicensePlate)
            {
                Caption = 'License Plate';
                field("Open LPs"; Rec."Open LPs") { ApplicationArea = All; DrillDownPageId = "DOPSWHS LP List"; }
                field("Built LPs"; Rec."Built LPs") { ApplicationArea = All; DrillDownPageId = "DOPSWHS LP List"; }
                field("Assigned LPs"; Rec."Assigned LPs") { ApplicationArea = All; DrillDownPageId = "DOPSWHS LP List"; }
                field("Unbuilt LPs"; Rec."Unbuilt LPs") { ApplicationArea = All; DrillDownPageId = "DOPSWHS LP List"; }
            }

            // ===== SAYIM =====
            cuegroup(Sayim)
            {
                Caption = 'Sayım';
                field("Active Count Sheets"; Rec."Active Count Sheets") { ApplicationArea = All; DrillDownPageId = "DOPSWHS Count Sheet List"; }
                field("InProgress Counts"; Rec."InProgress Counts") { ApplicationArea = All; DrillDownPageId = "DOPSWHS Count Sheet List"; }
            }

            // ===== SİSTEM =====
            cuegroup(Sistem)
            {
                Caption = 'Sistem';
                field("Total Devices"; Rec."Total Devices") { ApplicationArea = All; DrillDownPageId = "DOPSWHS Device Reg List"; }
                field("Devices Online"; Rec."Devices Online") { ApplicationArea = All; DrillDownPageId = "DOPSWHS Device Reg List"; }
                field("Pending Sync Conflicts"; Rec."Pending Sync Conflicts") { ApplicationArea = All; DrillDownPageId = "DOPSWHS Sync Conflict List"; }
                field("Webhook Events Today"; Rec."Webhook Events Today") { ApplicationArea = All; }
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
