codeunit 72138 "DOPSWHS Transfer Ship Tests"
{
    Subtype = Test;

    [Test]
    procedure TransferOrderShipPostsTransferShipment()
    var
        TransferHeader: Record "Transfer Header";
        TransferShipmentHeader: Record "Transfer Shipment Header";
        ShipmentMgmt: Codeunit "DOPSWHS Shipment Mgmt";
        Assert: Codeunit Assert;
    begin
        CreateTransferOrder(TransferHeader, 'TO-T6-SHIP');
        ShipmentMgmt.PostTransferShip(TransferHeader);
        TransferShipmentHeader.SetRange("Transfer Order No.", TransferHeader."No.");
        Assert.IsFalse(TransferShipmentHeader.IsEmpty(), 'Transfer shipment must be posted.');
    end;

    local procedure CreateTransferOrder(var TransferHeader: Record "Transfer Header"; No: Code[20])
    begin
        if TransferHeader.Get(No) then
            TransferHeader.Delete(true);
        TransferHeader.Init();
        TransferHeader."No." := No;
        TransferHeader."Transfer-from Code" := 'BLUE';
        TransferHeader."Transfer-to Code" := 'RED';
        TransferHeader.Status := TransferHeader.Status::Released;
        TransferHeader.Insert(true);
    end;
}
