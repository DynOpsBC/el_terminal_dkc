codeunit 72054 "DOPSWHS Legacy WI Publisher"
{
    Access = Public;

    procedure FireGetReceiptDocument(var DocNo: Code[20])
    begin
        OnGetReceiptDocument(DocNo);
    end;

    procedure FireGetPurchaseOrder(var DocNo: Code[20])
    begin
        OnGetPurchaseOrder(DocNo);
    end;

    procedure FireGetTransferOrder(var DocNo: Code[20])
    begin
        OnGetTransferOrder(DocNo);
    end;

    [IntegrationEvent(false, false)]
    procedure OnGetReceiptDocument(var DocNo: Code[20])
    begin
    end;

    [IntegrationEvent(false, false)]
    procedure OnGetPurchaseOrder(var DocNo: Code[20])
    begin
    end;

    [IntegrationEvent(false, false)]
    procedure OnGetTransferOrder(var DocNo: Code[20])
    begin
    end;
}
