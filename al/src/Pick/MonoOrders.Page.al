page 72365 "DOPSWHS Mono Orders"
{
    PageType = List;
    Caption = 'Mono Siparişler';
    SourceTable = "DOPSWHS Picking Order Header";
    SourceTableView = sorting("Entry No.") order(descending) where("Order Flow Mode" = const(Batch));
    CardPageId = "DOPSWHS Picking Order Card";
    ApplicationArea = All;
    UsageCategory = Tasks;
    Editable = false;

    layout
    {
        area(Content)
        {
            group(FlowInfo)
            {
                Caption = 'Mono Akışı';
                InstructionalText = 'Her sipariş tek ürün içerir ve gruptaki her siparişin ürünü farklıdır. Ürün ve sipariş bire bir ilerler.';
            }
            repeater(Orders)
            {
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; Caption = 'Grup No.'; }
                field(Description; Rec.Description) { ApplicationArea = All; Caption = 'Açıklama'; }
                field(OrderCount; OrderCount) { ApplicationArea = All; Caption = 'Sipariş'; Editable = false; }
                field(Status; Rec.Status) { ApplicationArea = All; Caption = 'Durum'; StyleExpr = StatusStyle; }
                field("Assigned User ID"; Rec."Assigned User ID") { ApplicationArea = All; Caption = 'Toplayıcı'; }
                field("Location Code"; Rec."Location Code") { ApplicationArea = All; Caption = 'Lokasyon'; }
                field("Warehouse Pick No."; Rec."Warehouse Pick No.") { ApplicationArea = All; Caption = 'Toplama'; }
                field("Created DateTime"; Rec."Created DateTime") { ApplicationArea = All; Caption = 'Oluşturma'; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(NewGroup)
            {
                Caption = 'Yeni Mono Grubu';
                ApplicationArea = All;
                Image = NewDocument;
                Promoted = true;
                PromotedCategory = New;

                trigger OnAction()
                var
                    Header: Record "DOPSWHS Picking Order Header";
                begin
                    Header.Init();
                    Header."Order Flow Mode" := Header."Order Flow Mode"::Batch;
                    Header.Description := 'Mono';
                    Header.Insert(true);
                    Page.Run(Page::"DOPSWHS Picking Order Card", Header);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        Line: Record "DOPSWHS Picking Order Line";
    begin
        Line.SetRange("Header Entry No.", Rec."Entry No.");
        OrderCount := Line.Count();
        case Rec.Status of
            Rec.Status::Open: StatusStyle := 'Attention';
            Rec.Status::"Pick Created": StatusStyle := 'Ambiguous';
            Rec.Status::Completed: StatusStyle := 'Favorable';
        end;
    end;

    var
        OrderCount: Integer;
        StatusStyle: Text;
}
