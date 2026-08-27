codeunit 72136 "DOPSWHS Ship Invoice Tests"
{
    Subtype = Test;

    [Test]
    procedure SalesOrderShipAndInvoicePostsShipmentAndInvoice()
    var
        SalesHeader: Record "Sales Header";
        SalesShipmentHeader: Record "Sales Shipment Header";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        ShipmentMgmt: Codeunit "DOPSWHS Shipment Mgmt";
        Assert: Codeunit Assert;
    begin
        CreateSalesOrder(SalesHeader, 'SO-T6-SI');
        ShipmentMgmt.PostSalesOrderShipAndInvoice(SalesHeader);
        SalesShipmentHeader.SetRange("Order No.", SalesHeader."No.");
        SalesInvoiceHeader.SetRange("Order No.", SalesHeader."No.");
        Assert.IsFalse(SalesShipmentHeader.IsEmpty(), 'Posted sales shipment must exist.');
        Assert.IsFalse(SalesInvoiceHeader.IsEmpty(), 'Posted sales invoice must exist.');
    end;

    local procedure CreateSalesOrder(var SalesHeader: Record "Sales Header"; No: Code[20])
    begin
        if SalesHeader.Get(SalesHeader."Document Type"::Order, No) then
            SalesHeader.Delete(true);
        SalesHeader.Init();
        SalesHeader."Document Type" := SalesHeader."Document Type"::Order;
        SalesHeader."No." := No;
        SalesHeader."Sell-to Customer No." := '10000';
        SalesHeader."DOPSWHS Ship Direct Mobile" := true;
        SalesHeader.Status := SalesHeader.Status::Released;
        SalesHeader.Insert(true);
    end;
}
