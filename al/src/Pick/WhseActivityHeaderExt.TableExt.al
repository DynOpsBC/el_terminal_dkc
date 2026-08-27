tableextension 72429 "DOPSWHS Whse Activity Hdr Ext" extends "Warehouse Activity Header"
{
    fields
    {
        // Terminal pick listesi bu alana göre Multi/Bulk/Batch sekmelerine
        // ayrılır. MultiOrderPick.CreateGroupedPick oluşturduğu pick'e damgalar.
        field(72400; "DOPSWHS Pick Mode"; Enum "DOPSWHS Pick Mode")
        {
            Caption = 'Pick Mode (WMS)';
            DataClassification = CustomerContent;
        }
        // ELOG: aracı ekran başındaki sorumlu (masa) girer; terminaldeki
        // toplayıcı sadece görür. Toplama başlığında tutulur.
        field(72401; "DOPSWHS Vehicle No."; Code[20])
        {
            Caption = 'Vehicle No. (WMS)';
            DataClassification = CustomerContent;
        }
        // ELOG ana sepet: toplayıcı pick'e başlarken okuttuğu sepet/LP.
        // Terminalde yalnız ekran state'inde tutuluyordu; ekrandan çıkıp
        // girince kayboluyordu. Burada kalıcı: paketleme "ürünler hangi
        // sepette" bilgisini buradan okur.
        field(72402; "DOPSWHS Main LP No."; Code[20])
        {
            Caption = 'Ana Sepet (LP)';
            DataClassification = CustomerContent;
            TableRelation = "DOPSWHS LP Header"."No." where("Location Code" = field("Location Code"));
            ValidateTableRelation = true;

            trigger OnValidate()
            var
                LP: Record "DOPSWHS LP Header";
            begin
                if "DOPSWHS Main LP No." = '' then
                    exit;
                if not LP.Get("DOPSWHS Main LP No.") then
                    Error('Ana sepet %1 kayıtlı bir LP değildir.', "DOPSWHS Main LP No.");
                TestField("Location Code");
                if LP."Location Code" <> "Location Code" then
                    Error(
                        'Ana sepet %1, %2 lokasyonundadır; pick %3 lokasyonundadır.',
                        LP."No.", LP."Location Code", "Location Code");
                if LP.Status in [LP.Status::Used, LP.Status::Unbuilt] then
                    Error('Ana sepet %1 kullanılamaz; LP durumu %2.', LP."No.", LP.Status);
                if (LP.Status = LP.Status::Assigned) and
                   ((LP."Assigned Document Type" <> LP."Assigned Document Type"::WhsePick) or
                    (LP."Assigned Document No." <> "No."))
                then
                    Error(
                        'Ana sepet %1 başka bir belgeye atanmıştır (%2 %3).',
                        LP."No.", LP."Assigned Document Type", LP."Assigned Document No.");
            end;
        }
    }
}
