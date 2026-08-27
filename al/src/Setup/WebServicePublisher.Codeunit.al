codeunit 72257 "DOPSWHS Web Svc Publisher"
{
    // Publishes standard BC pages as tenant web services so operations that have NO extension-accessible
    // AL API (e.g. directed Pick creation) can be driven from outside via OData (data) / SOAP (page
    // actions such as CreatePick). Auto-run on install/upgrade and idempotent. The published OData V4
    // endpoints live at: /ODataV4/Company('<company>')/<serviceName>; SOAP at /WS/<company>/Page/<name>.
    Access = Public;

    procedure PublishAll()
    begin
        // Outbound / picking (the no-extension-API gap): SOAP exposes the page's CreatePick action.
        PublishPage(7335, 'DOPSWHSWarehouseShipment');
        PublishPage(5779, 'DOPSWHSWarehousePick');
        PublishPage(5797, 'DOPSWHSRegdWhseActivity');     // registered picks/put-aways (OData read)
        // Inbound / put-away: SOAP exposes CreatePutAway.
        PublishPage(5768, 'DOPSWHSWarehouseReceipt');
        PublishPage(5770, 'DOPSWHSWarehousePutAway');
        // Movement on directed locations.
        PublishPage(393, 'DOPSWHSItemReclassJournal');
        PublishPage(7324, 'DOPSWHSWhseItemJournal');
        // Production.
        PublishPage(99000831, 'DOPSWHSReleasedProdOrder');
        PublishPage(5510, 'DOPSWHSProductionJournal');
        // Our own posting/quality surfaces (extra OData V4 access alongside the custom API).
        PublishPage(72253, 'DOPSWHSPostingTests');
        PublishPage(72256, 'DOPSWHSQualityOrders');
    end;

    local procedure PublishPage(ObjectId: Integer; ServiceName: Text[240])
    var
        TenantWebService: Record "Tenant Web Service";
        AllObjWithCaption: Record AllObjWithCaption;
    begin
        // Guard: never abort install/upgrade if a page id is absent in this app version.
        if not AllObjWithCaption.Get(AllObjWithCaption."Object Type"::Page, ObjectId) then
            exit;

        if TenantWebService.Get(TenantWebService."Object Type"::Page, ServiceName) then begin
            if not TenantWebService.Published then begin
                TenantWebService.Validate(Published, true);
                TenantWebService.Modify(true);
            end;
            exit;
        end;
        TenantWebService.Init();
        TenantWebService.Validate("Object Type", TenantWebService."Object Type"::Page);
        TenantWebService.Validate("Object ID", ObjectId);
        TenantWebService.Validate("Service Name", ServiceName);
        TenantWebService.Validate(Published, true);
        if TenantWebService.Insert(true) then;
    end;
}
