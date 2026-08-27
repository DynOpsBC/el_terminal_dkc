page 72294 "DOPSWHS Sales Source API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'salesSource';
    EntitySetName = 'salesSources';
    SourceTable = "Sales Header";
    SourceTableView = where("Document Type" = const(Order));
    DelayedInsert = true;
    Editable = false;
    ODataKeyFields = "No.";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(no; Rec."No.") { Caption = 'no'; }
                field(customerNo; Rec."Sell-to Customer No.") { Caption = 'customerNo'; }
                field(customerName; Rec."Sell-to Customer Name") { Caption = 'customerName'; }
                field(shipToName; Rec."Ship-to Name") { Caption = 'shipToName'; }
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; }
                field(orderDate; Rec."Order Date") { Caption = 'orderDate'; }
                field(shipmentDate; Rec."Shipment Date") { Caption = 'shipmentDate'; }
                field(status; Rec.Status) { Caption = 'status'; }
                field(lineCount; LineCount) { Caption = 'lineCount'; }
                field(outstandingQty; OutstandingQty) { Caption = 'outstandingQty'; }
                field(percentComplete; PercentComplete) { Caption = 'percentComplete'; }
                field(requiresWhseShipment; RequiresWhseShipment) { Caption = 'requiresWhseShipment'; }
                field(directShipAllowed; DirectShipAllowed) { Caption = 'directShipAllowed'; }
                part(lines; "DOPSWHS Sales Source Line API")
                {
                    Caption = 'lines';
                    EntityName = 'salesSourceLine';
                    EntitySetName = 'salesSourceLines';
                    SubPageLink = "Document Type" = const(Order), "Document No." = field("No.");
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        FillCalculatedFields();
    end;

    [ServiceEnabled]
    procedure ship(invoice: Boolean): Text
    var
        Mgmt: Codeunit "DOPSWHS Sales Source Mgmt";
    begin
        exit(Mgmt.ShipOrder(Rec."No.", invoice));
    end;

    var
        LineCount: Integer;
        OutstandingQty: Decimal;
        PercentComplete: Decimal;
        RequiresWhseShipment: Boolean;
        DirectShipAllowed: Boolean;

    local procedure FillCalculatedFields()
    var
        SL: Record "Sales Line";
        Loc: Record Location;
        TotalQty: Decimal;
        ShippedQty: Decimal;
    begin
        Clear(LineCount); Clear(OutstandingQty); Clear(PercentComplete);
        Clear(RequiresWhseShipment); Clear(DirectShipAllowed);
        SL.SetRange("Document Type", SL."Document Type"::Order);
        SL.SetRange("Document No.", Rec."No.");
        SL.SetFilter(Type, '<>%1', SL.Type::" ");
        if SL.FindSet() then
            repeat
                LineCount += 1;
                OutstandingQty += SL."Outstanding Quantity";
                TotalQty += SL.Quantity;
                ShippedQty += SL."Quantity Shipped";
            until SL.Next() = 0;
        if TotalQty <> 0 then
            PercentComplete := Round(ShippedQty / TotalQty * 100, 1);

        if Rec."Location Code" = '' then begin
            RequiresWhseShipment := false;
            DirectShipAllowed := true;
        end else if Loc.Get(Rec."Location Code") then begin
            RequiresWhseShipment := Loc."Require Shipment";
            DirectShipAllowed := not Loc."Require Shipment";
        end else begin
            RequiresWhseShipment := false;
            DirectShipAllowed := true;
        end;
    end;
}
