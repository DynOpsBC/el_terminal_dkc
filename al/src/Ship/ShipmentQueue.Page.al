page 72084 "DOPSWHS Shipment Queue"
{
    PageType = ListPart;
    SourceTable = Integer;
    Caption = 'Shipment Queue';
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Queue)
            {
                field(SourceType; SourceType) { ApplicationArea = All; Caption = 'Source Type'; }
                field(DocumentNo; DocumentNo) { ApplicationArea = All; Caption = 'Document No.'; }
                field(SourceNo; SourceNo) { ApplicationArea = All; Caption = 'Source No.'; }
                field(ShipTo; ShipTo) { ApplicationArea = All; Caption = 'Ship-to'; }
                field(DueDate; DueDate) { ApplicationArea = All; Caption = 'Due Date'; }
                field(AssignedUser; AssignedUser) { ApplicationArea = All; Caption = 'Assigned User'; }
                field(LineCount; LineCount) { ApplicationArea = All; Caption = 'Line Count'; }
            }
        }
    }

    trigger OnOpenPage()
    begin
        BuildQueue();
    end;

    trigger OnAfterGetRecord()
    begin
        FillFields(Rec.Number);
    end;

    trigger OnFindRecord(Which: Text): Boolean
    begin
        if QueueCount = 0 then
            BuildQueue();
        if QueueCount = 0 then
            exit(false);
        Rec.Number := 1;
        FillFields(Rec.Number);
        exit(true);
    end;

    trigger OnNextRecord(Steps: Integer): Integer
    var
        NewNumber: Integer;
    begin
        NewNumber := Rec.Number + Steps;
        if NewNumber < 1 then
            NewNumber := 1;
        if NewNumber > QueueCount then
            exit(0);
        Rec.Number := NewNumber;
        FillFields(Rec.Number);
        exit(Steps);
    end;

    var
        SourceTypes: List of [Text];
        DocumentNos: List of [Code[20]];
        SourceNos: List of [Code[20]];
        ShipTos: List of [Text[100]];
        DueDates: List of [Date];
        AssignedUsers: List of [Code[50]];
        LineCounts: List of [Integer];
        QueueCount: Integer;
        SourceType: Text[20];
        DocumentNo: Code[20];
        SourceNo: Code[20];
        ShipTo: Text[100];
        DueDate: Date;
        AssignedUser: Code[50];
        LineCount: Integer;

    local procedure BuildQueue()
    begin
        Clear(SourceTypes);
        Clear(DocumentNos);
        Clear(SourceNos);
        Clear(ShipTos);
        Clear(DueDates);
        Clear(AssignedUsers);
        Clear(LineCounts);
        QueueCount := 0;
        AddWarehouseShipments();
        AddSalesOrders();
        AddTransferOrders();
    end;

    local procedure AddWarehouseShipments()
    var
        Header: Record "Warehouse Shipment Header";
        Line: Record "Warehouse Shipment Line";
        SourceNoValue: Code[20];
        ShipToValue: Text[100];
        DueDateValue: Date;
        CountValue: Integer;
        SalesHeader: Record "Sales Header";
    begin
        Header.SetRange(Status, Header.Status::Released);
        if Header.FindSet() then
            repeat
                Clear(SourceNoValue);
                Clear(ShipToValue);
                Clear(DueDateValue);
                Clear(CountValue);
                Line.SetRange("No.", Header."No.");
                if Line.FindSet() then
                    repeat
                        CountValue += 1;
                        if SourceNoValue = '' then begin
                            SourceNoValue := Line."Source No.";
                            DueDateValue := Line."Due Date";
                        end;
                    until Line.Next() = 0;
                if SalesHeader.Get(SalesHeader."Document Type"::Order, SourceNoValue) then
                    ShipToValue := SalesHeader."Ship-to Name";
                AddEntry('Whse', Header."No.", SourceNoValue, ShipToValue, DueDateValue, Header."Assigned User ID", CountValue);
            until Header.Next() = 0;
    end;

    local procedure AddSalesOrders()
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        CountValue: Integer;
    begin
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.SetRange("DOPSWHS Ship Direct Mobile", true);
        if SalesHeader.FindSet() then
            repeat
                CountValue := 0;
                SalesLine.SetRange("Document Type", SalesHeader."Document Type");
                SalesLine.SetRange("Document No.", SalesHeader."No.");
                SalesLine.SetFilter("Outstanding Quantity", '>0');
                CountValue := SalesLine.Count();
                if (SalesHeader."Shipping Agent Code" <> '') or (CountValue > 0) then
                    AddEntry('Sales', SalesHeader."No.", SalesHeader."External Document No.", SalesHeader."Ship-to Name", SalesHeader."Shipment Date", '', CountValue);
            until SalesHeader.Next() = 0;
    end;

    local procedure AddTransferOrders()
    var
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        CountValue: Integer;
    begin
        TransferHeader.SetRange(Status, TransferHeader.Status::Released);
        if TransferHeader.FindSet() then
            repeat
                TransferLine.SetRange("Document No.", TransferHeader."No.");
                TransferLine.SetFilter("Outstanding Quantity", '>0');
                CountValue := TransferLine.Count();
                if CountValue > 0 then
                    AddEntry('Transfer', TransferHeader."No.", TransferHeader."Transfer-from Code", TransferHeader."Transfer-to Name", TransferHeader."Shipment Date", '', CountValue);
            until TransferHeader.Next() = 0;
    end;

    local procedure AddEntry(NewSourceType: Text[20]; NewDocumentNo: Code[20]; NewSourceNo: Code[20]; NewShipTo: Text[100]; NewDueDate: Date; NewAssignedUser: Code[50]; NewLineCount: Integer)
    begin
        SourceTypes.Add(NewSourceType);
        DocumentNos.Add(NewDocumentNo);
        SourceNos.Add(NewSourceNo);
        ShipTos.Add(NewShipTo);
        DueDates.Add(NewDueDate);
        AssignedUsers.Add(NewAssignedUser);
        LineCounts.Add(NewLineCount);
        QueueCount += 1;
    end;

    local procedure FillFields(Index: Integer)
    begin
        SourceTypes.Get(Index, SourceType);
        DocumentNos.Get(Index, DocumentNo);
        SourceNos.Get(Index, SourceNo);
        ShipTos.Get(Index, ShipTo);
        DueDates.Get(Index, DueDate);
        AssignedUsers.Get(Index, AssignedUser);
        LineCounts.Get(Index, LineCount);
    end;
}
