page 72223 "DOPSWHS Output API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'productionOutput';
    EntitySetName = 'productionOutput';
    SourceTable = "Prod. Order Routing Line";
    SourceTableView = where(Status = const(Released));
    DelayedInsert = true;
    ODataKeyFields = Status, "Prod. Order No.", "Routing Reference No.", "Routing No.", "Operation No.";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(prodOrderNo; Rec."Prod. Order No.") { Caption = 'prodOrderNo'; }
                field(status; Rec.Status) { Caption = 'status'; }
                field(routingLineNo; Rec."Routing Reference No.") { Caption = 'routingLineNo'; }
                field(lineNo; Rec."Routing Reference No.") { Caption = 'lineNo'; }
                field(routingNo; Rec."Routing No.") { Caption = 'routingNo'; }
                field(operationNo; Rec."Operation No.") { Caption = 'operationNo'; }
                field(workCenterNo; Rec."No.") { Caption = 'workCenterNo'; }
                field(description; Rec.Description) { Caption = 'description'; }
                field(runTime; Rec."Run Time") { Caption = 'runTime'; }
            }
        }
    }

    trigger OnOpenPage()
    var
        FilterMgmt: Codeunit "DOPSWHS App Role Filter Mgmt";
        RecRef: RecordRef;
    begin
        RecRef.GetTable(Rec);
        FilterMgmt.ApplyForCurrentUser(RecRef, Enum::"DOPSWHS App Filter Entity"::ProductionOutput);
        RecRef.SetTable(Rec);
    end;

    [ServiceEnabled]
    procedure report(prodOrderNo: Code[20]; routingLineNo: Integer; outputQty: Decimal; scrapQty: Decimal; runtime: Decimal; newLpTemplate: Code[20]; binCode: Code[20]): Code[20]
    var
        ProdMgmt: Codeunit "DOPSWHS Prod Mgmt";
    begin
        exit(ProdMgmt.ReportOutputByProdOrder(prodOrderNo, routingLineNo, outputQty, scrapQty, runtime, newLpTemplate, binCode));
    end;
}
