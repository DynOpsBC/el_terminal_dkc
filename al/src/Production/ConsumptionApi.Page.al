page 72222 "DOPSWHS Consumption API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'productionConsumption';
    EntitySetName = 'productionConsumption';
    SourceTable = "Prod. Order Component";
    SourceTableView = where(Status = const(Released));
    DelayedInsert = true;
    ODataKeyFields = Status, "Prod. Order No.", "Prod. Order Line No.", "Line No.";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(prodOrderNo; Rec."Prod. Order No.") { Caption = 'prodOrderNo'; }
                field(status; Rec.Status) { Caption = 'status'; }
                field(prodOrderLineNo; Rec."Prod. Order Line No.") { Caption = 'prodOrderLineNo'; }
                field(componentLineNo; Rec."Line No.") { Caption = 'componentLineNo'; }
                field(itemNo; Rec."Item No.") { Caption = 'itemNo'; }
                field(description; Rec.Description) { Caption = 'description'; }
                field(quantity; Rec.Quantity) { Caption = 'quantity'; }
                field(remainingQuantity; Rec."Remaining Quantity") { Caption = 'remainingQuantity'; }
                field(unitOfMeasureCode; Rec."Unit of Measure Code") { Caption = 'unitOfMeasureCode'; }
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; }
                field(binCode; Rec."Bin Code") { Caption = 'binCode'; }
                field(producedItemNo; ProducedItemNo) { Caption = 'producedItemNo'; }
                field(producedItemDescription; ProducedItemDescription) { Caption = 'producedItemDescription'; }
                field(productionQuantity; ProductionQuantity) { Caption = 'productionQuantity'; }
                field(dueDate; DueDate) { Caption = 'dueDate'; }
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        ProdOrderLine: Record "Prod. Order Line";
    begin
        Clear(ProducedItemNo);
        Clear(ProducedItemDescription);
        Clear(ProductionQuantity);
        Clear(DueDate);

        if ProdOrderLine.Get(Rec.Status, Rec."Prod. Order No.", Rec."Prod. Order Line No.") then begin
            ProducedItemNo := ProdOrderLine."Item No.";
            ProducedItemDescription := ProdOrderLine.Description;
            ProductionQuantity := ProdOrderLine.Quantity;
            DueDate := ProdOrderLine."Due Date";
        end;
    end;

    trigger OnOpenPage()
    var
        FilterMgmt: Codeunit "DOPSWHS App Role Filter Mgmt";
        RecRef: RecordRef;
    begin
        RecRef.GetTable(Rec);
        FilterMgmt.ApplyForCurrentUser(RecRef, Enum::"DOPSWHS App Filter Entity"::ProductionConsumption);
        RecRef.SetTable(Rec);
    end;

    [ServiceEnabled]
    procedure consume(prodOrderNo: Code[20]; componentLineNo: Integer; itemNo: Code[20]; qty: Decimal; lpNo: Code[20]; lotNo: Code[50]; serialNo: Code[50]; binCode: Code[20])
    var
        ProdMgmt: Codeunit "DOPSWHS Prod Mgmt";
    begin
        ProdMgmt.ConsumeByProdOrder(prodOrderNo, componentLineNo, itemNo, qty, lpNo, lotNo, serialNo, binCode);
    end;

    [ServiceEnabled]
    procedure createPick(): Code[20]
    var
        ProdMgmt: Codeunit "DOPSWHS Prod Mgmt";
    begin
        exit(ProdMgmt.CreateProductionPick(Rec."Prod. Order No."));
    end;

    [ServiceEnabled]
    procedure finish(updateUnitCost: Boolean): Code[20]
    var
        ProdMgmt: Codeunit "DOPSWHS Prod Mgmt";
    begin
        exit(ProdMgmt.FinishProductionOrder(Rec."Prod. Order No.", updateUnitCost));
    end;

    var
        ProducedItemNo: Code[20];
        ProducedItemDescription: Text[100];
        ProductionQuantity: Decimal;
        DueDate: Date;
}
