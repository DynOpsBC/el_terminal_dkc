pageextension 72312 "DOPSWHS Sales Order Ship Ext" extends "Sales Order"
{
    layout
    {
        addlast("Shipping and Billing")
        {
            field("DOPSWHS Ship Direct Mobile"; Rec."DOPSWHS Ship Direct Mobile")
            {
                ApplicationArea = All;
                Caption = 'Ship Direct from Mobile';
                ToolTip = 'Specifies whether this sales order can be shipped directly from the mobile shipping flow.';
            }
        }
    }

    actions
    {
        addlast(Processing)
        {
            group("DOPSWHS Ship Invoice")
            {
                Caption = 'Ship & Invoice';

                action("DOPSWHS Mobile Ship Invoice")
                {
                    ApplicationArea = All;
                    Caption = 'Mobile Ship & Invoice';
                    Image = PostDocument;

                    trigger OnAction()
                    var
                        ShipmentMgmt: Codeunit "DOPSWHS Shipment Mgmt";
                    begin
                        ShipmentMgmt.PostSalesOrderShipAndInvoice(Rec);
                    end;
                }
            }
        }
    }
}
