page 72090 "DOPSWHS Receipt API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'receipt';
    EntitySetName = 'receipts';
    SourceTable = "Warehouse Receipt Header";
    DelayedInsert = true;
    ODataKeyFields = "No.";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(no; Rec."No.") { Caption = 'no'; }
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; }
                field(assignedUserId; Rec."Assigned User ID") { Caption = 'assignedUserId'; }
                field(sourceNo; SourceNo) { Caption = 'sourceNo'; }
                field(sourceType; SourceType) { Caption = 'sourceType'; }
                field(vendorSourceName; VendorSourceName) { Caption = 'vendorSourceName'; }
                field(dueDate; DueDate) { Caption = 'dueDate'; }
                field(percentComplete; PercentComplete) { Caption = 'percentComplete'; }
                part(lines; "DOPSWHS Receipt Line API")
                {
                    Caption = 'lines';
                    EntityName = 'receiptLine';
                    EntitySetName = 'receiptLines';
                    SubPageLink = "No." = field("No.");
                }
            }
        }
    }

    trigger OnOpenPage()
    var
        FilterMgmt: Codeunit "DOPSWHS App Role Filter Mgmt";
        RecRef: RecordRef;
    begin
        RecRef.GetTable(Rec);
        FilterMgmt.ApplyForCurrentUser(RecRef, Enum::"DOPSWHS App Filter Entity"::Receipt);
        RecRef.SetTable(Rec);
    end;

    trigger OnAfterGetRecord()
    begin
        FillCalculatedFields();
    end;

    [ServiceEnabled]
    procedure assignToUser(userId: Code[50])
    var
        ReceiptMgmt: Codeunit "DOPSWHS Receipt Mgmt";
        LegacyWI: Codeunit "DOPSWHS Legacy WI Publisher";
        DocNo: Code[20];
    begin
        DocNo := Rec."No.";
        LegacyWI.FireGetReceiptDocument(DocNo);
        ReceiptMgmt.AssignUser(Rec, userId);
    end;

    [ServiceEnabled]
    procedure startLP(lpTemplateCode: Code[20]): Text
    var
        ReceiptMgmt: Codeunit "DOPSWHS Receipt Mgmt";
        LegacyWI: Codeunit "DOPSWHS Legacy WI Publisher";
        DocNo: Code[20];
        LpNo: Code[20];
    begin
        DocNo := Rec."No.";
        LegacyWI.FireGetReceiptDocument(DocNo);
        LpNo := ReceiptMgmt.StartLP(Rec, lpTemplateCode);
        exit(LpNo);
    end;

    [ServiceEnabled]
    procedure stopLP(lpNo: Code[20]; printLabel: Boolean)
    var
        ReceiptMgmt: Codeunit "DOPSWHS Receipt Mgmt";
        LegacyWI: Codeunit "DOPSWHS Legacy WI Publisher";
        DocNo: Code[20];
    begin
        DocNo := Rec."No.";
        LegacyWI.FireGetReceiptDocument(DocNo);
        ReceiptMgmt.StopLP(Rec, lpNo, printLabel);
    end;

    [ServiceEnabled]
    procedure stopLPToPrinter(lpNo: Code[20]; printLabel: Boolean; printerId: Code[50])
    var
        ReceiptMgmt: Codeunit "DOPSWHS Receipt Mgmt";
        LegacyWI: Codeunit "DOPSWHS Legacy WI Publisher";
        DocNo: Code[20];
    begin
        DocNo := Rec."No.";
        LegacyWI.FireGetReceiptDocument(DocNo);
        ReceiptMgmt.StopLP(Rec, lpNo, printLabel, printerId);
    end;

    [ServiceEnabled]
    procedure post(print: Boolean; invoice: Boolean)
    var
        ReceiptMgmt: Codeunit "DOPSWHS Receipt Mgmt";
        LegacyWI: Codeunit "DOPSWHS Legacy WI Publisher";
        DocNo: Code[20];
    begin
        DocNo := Rec."No.";
        LegacyWI.FireGetReceiptDocument(DocNo);
        ReceiptMgmt.PostReceipt(Rec, print, invoice);
    end;

    [ServiceEnabled]
    procedure postToPrinter(print: Boolean; invoice: Boolean; printerId: Code[50])
    var
        ReceiptMgmt: Codeunit "DOPSWHS Receipt Mgmt";
        LegacyWI: Codeunit "DOPSWHS Legacy WI Publisher";
        DocNo: Code[20];
    begin
        DocNo := Rec."No.";
        LegacyWI.FireGetReceiptDocument(DocNo);
        ReceiptMgmt.PostReceipt(Rec, print, invoice, '', printerId);
    end;

    var
        SourceNo: Code[20];
        SourceType: Text[30];
        VendorSourceName: Text[100];
        DueDate: Date;
        PercentComplete: Decimal;

    local procedure FillCalculatedFields()
    var
        WhseReceiptLine: Record "Warehouse Receipt Line";
        PurchaseHeader: Record "Purchase Header";
        TransferHeader: Record "Transfer Header";
        TotalQty: Decimal;
        HandledQty: Decimal;
    begin
        Clear(SourceNo);
        Clear(SourceType);
        Clear(VendorSourceName);
        Clear(DueDate);
        Clear(PercentComplete);

        WhseReceiptLine.SetRange("No.", Rec."No.");
        if WhseReceiptLine.FindSet() then
            repeat
                if SourceNo = '' then begin
                    SourceNo := WhseReceiptLine."Source No.";
                    SourceType := Format(WhseReceiptLine."Source Type");
                    DueDate := WhseReceiptLine."Due Date";
                end;
                TotalQty += WhseReceiptLine.Quantity;
                HandledQty += WhseReceiptLine."Qty. Received";
            until WhseReceiptLine.Next() = 0;

        if SourceType = Format(Database::"Purchase Line") then
            if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, SourceNo) then
                VendorSourceName := PurchaseHeader."Buy-from Vendor Name";
        if SourceType = Format(Database::"Transfer Line") then
            if TransferHeader.Get(SourceNo) then
                VendorSourceName := TransferHeader."Transfer-from Name";

        if TotalQty <> 0 then
            PercentComplete := Round(HandledQty / TotalQty * 100, 1);
    end;
}
