page 72355 "DOPSWHS Picking Order Lines"
{
    PageType = ListPart;
    Caption = 'Sales Orders';
    SourceTable = "DOPSWHS Picking Order Line";
    AutoSplitKey = true;
    Editable = false;
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Sales Order No."; Rec."Sales Order No.") { ApplicationArea = All; }
                // ELOG: bu siparişin depo toplama durumu (Pick Yok / Pick Açık / Toplandı).
                field(PickStatusText; PickStatusText)
                {
                    ApplicationArea = All;
                    Caption = 'Toplama Durumu';
                    Editable = false;
                    StyleExpr = PickStatusStyle;
                    ToolTip = 'Bu satış siparişi için depo toplamasının (warehouse pick) durumunu gösterir.';
                }
                field("Sell-to Customer No."; Rec."Sell-to Customer No.") { ApplicationArea = All; }
                field("Sell-to Customer Name"; Rec."Sell-to Customer Name") { ApplicationArea = All; }
                field("Location Code"; Rec."Location Code") { ApplicationArea = All; }
                field("Shipment Date"; Rec."Shipment Date") { ApplicationArea = All; }
                field("Item Line Count"; Rec."Item Line Count") { ApplicationArea = All; }
                field("Total Quantity"; Rec."Total Quantity") { ApplicationArea = All; }
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        PickingOrderMgmt: Codeunit "DOPSWHS Picking Order Mgmt";
    begin
        case PickingOrderMgmt.GetSalesOrderPickStatus(Rec."Sales Order No.") of
            0:
                begin
                    PickStatusText := 'Pick Yok';
                    PickStatusStyle := 'Unfavorable';
                end;
            1:
                begin
                    PickStatusText := 'Pick Açık';
                    PickStatusStyle := 'Ambiguous';
                end;
            2:
                begin
                    PickStatusText := 'Toplandı';
                    PickStatusStyle := 'Favorable';
                end;
        end;
    end;

    var
        PickStatusText: Text[30];
        PickStatusStyle: Text;
}
