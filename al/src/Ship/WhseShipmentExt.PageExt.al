pageextension 72307 "DOPSWHS Whse Shipment Ext" extends "Warehouse Shipment"
{
    layout
    {
        addlast(FactBoxes)
        {
            part("DOPSWHS Shipping LPs"; "DOPSWHS Shipment LP Factbox")
            {
                ApplicationArea = All;
                Caption = 'Shipping LPs';
                SubPageLink = "Assigned Document Type" = const(WhseShipment), "Assigned Document No." = field("No.");
            }
        }
    }

    actions
    {
        addlast(Processing)
        {
            group("DOPSWHS Mobile")
            {
                Caption = 'DOPSWHS Mobile';

                action("DOPSWHS Post Mobile")
                {
                    ApplicationArea = All;
                    Caption = 'Post Mobile';
                    Image = PostDocument;

                    trigger OnAction()
                    var
                        ShipmentMgmt: Codeunit "DOPSWHS Shipment Mgmt";
                    begin
                        ShipmentMgmt.PostShipment(Rec, false, false);
                    end;
                }
                action("DOPSWHS Print Packing Slip")
                {
                    ApplicationArea = All;
                    Caption = 'Print Packing Slip';
                    Image = Print;

                    trigger OnAction()
                    var
                        ShipmentMgmt: Codeunit "DOPSWHS Shipment Mgmt";
                    begin
                        ShipmentMgmt.PostShipment(Rec, true, false);
                    end;
                }
            }
        }
    }
}
