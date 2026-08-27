page 72082 "DOPSWHS Receiving Queue"
{
    PageType = ListPart;
    SourceTable = "Warehouse Receipt Header";
    Caption = 'DOPSWHS Receiving Queue';
    Editable = false;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("No."; Rec."No.") { ApplicationArea = All; }
                field("Source No."; SourceNo) { ApplicationArea = All; Caption = 'Source No.'; }
                field("Source Type"; SourceType) { ApplicationArea = All; Caption = 'Source Type'; }
                field("Vendor/Source Name"; VendorSourceName) { ApplicationArea = All; Caption = 'Vendor/Source Name'; }
                field("Due Date"; DueDate) { ApplicationArea = All; Caption = 'Due Date'; }
                field("Assigned User"; Rec."Assigned User ID") { ApplicationArea = All; Caption = 'Assigned User'; }
                field("% Complete"; PercentComplete)
                {
                    ApplicationArea = All;
                    Caption = '% Complete';
                    ExtendedDatatype = Ratio;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action("Assign to User")
            {
                ApplicationArea = All;
                Caption = 'Assign to User';
                trigger OnAction()
                var
                    ReceiptMgmt: Codeunit "DOPSWHS Receipt Mgmt";
                    UserId: Code[50];
                begin
                    UserId := PickUser();
                    if UserId = '' then
                        exit;
                    ReceiptMgmt.AssignUser(Rec, UserId);
                    CurrPage.Update(false);
                end;
            }
            action("Open in BC")
            {
                ApplicationArea = All;
                Caption = 'Open in BC';
                trigger OnAction()
                begin
                    Page.Run(Page::"Warehouse Receipt", Rec);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        FillCalculatedFields();
    end;

    var
        SourceNo: Code[20];
        SourceType: Text[30];
        VendorSourceName: Text[100];
        DueDate: Date;
        PercentComplete: Integer;

    local procedure FillCalculatedFields()
    var
        WhseReceiptLine: Record "Warehouse Receipt Line";
        PurchaseHeader: Record "Purchase Header";
        TransferHeader: Record "Transfer Header";
        TotalQty: Decimal;
        ReceivedQty: Decimal;
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
                ReceivedQty += WhseReceiptLine."Qty. Received";
            until WhseReceiptLine.Next() = 0;

        if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, SourceNo) then
            VendorSourceName := PurchaseHeader."Buy-from Vendor Name"
        else
            if TransferHeader.Get(SourceNo) then
                VendorSourceName := TransferHeader."Transfer-from Name";

        if TotalQty <> 0 then
            PercentComplete := Round(ReceivedQty / TotalQty * 100, 1);
    end;

    local procedure PickUser(): Code[50]
    var
        User: Record User;
    begin
        if Page.RunModal(Page::"User Lookup", User) = Action::LookupOK then
            exit(User."User Name");
        exit('');
    end;
}
