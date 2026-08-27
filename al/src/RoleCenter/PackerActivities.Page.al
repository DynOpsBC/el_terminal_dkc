page 72348 "DOPSWHS Packer Activities"
{
    // Packer ana ekranı: tek sipariş paketleme kuyruğu.
    Caption = 'Packing Activities';
    PageType = CardPart;
    SourceTable = "DOPSWHS Warehouse Mgr Cue";
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            cuegroup(PackageWorksheets)
            {
                Caption = 'Sipariş Paketleme';
                field("Orders Ready for Packing"; Rec."Orders Ready for Packing")
                {
                    Caption = 'Paketleme Bekleyen';
                    ApplicationArea = All;
                    DrillDownPageId = "DOPSWHS Packing Order List";
                }
                field("Orders Being Packed"; Rec."Orders Being Packed")
                {
                    Caption = 'Paketlenen Siparişler';
                    ApplicationArea = All;
                    DrillDownPageId = "DOPSWHS Packing Order List";
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        if not Rec.Get('') then begin
            Rec.Init();
            Rec.Insert(true);
        end;
    end;
}
