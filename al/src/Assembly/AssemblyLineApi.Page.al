page 72230 "DOPSWHS Assembly Line API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'assemblyLine';
    EntitySetName = 'assemblyLines';
    SourceTable = "Assembly Line";
    DelayedInsert = true;
    ODataKeyFields = "Document Type", "Document No.", "Line No.";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(documentNo; Rec."Document No.") { Caption = 'documentNo'; Editable = false; }
                field(documentType; Rec."Document Type") { Caption = 'documentType'; Editable = false; }
                field(lineNo; Rec."Line No.") { Caption = 'lineNo'; Editable = false; }
                field(type; Rec.Type) { Caption = 'type'; Editable = false; }
                field(itemNo; Rec."No.") { Caption = 'itemNo'; Editable = false; }
                field(description; Rec.Description) { Caption = 'description'; Editable = false; }
                field(quantity; Rec.Quantity) { Caption = 'quantity'; Editable = false; }
                field(consumedQuantity; Rec."Consumed Quantity") { Caption = 'consumedQuantity'; Editable = false; }
                // Assembly Line'daki gercek giris alanidir. Mobil istemci bu
                // degeri gosterip/degistirir; post islemi de ayni alani kullanir.
                field(qtyToAssemble; Rec."Quantity to Consume") { Caption = 'qtyToAssemble'; }
                field(remainingQuantity; Rec."Remaining Quantity") { Caption = 'remainingQuantity'; Editable = false; }
                field(quantityPer; Rec."Quantity per") { Caption = 'quantityPer'; Editable = false; }
                field(unitOfMeasureCode; Rec."Unit of Measure Code") { Caption = 'unitOfMeasureCode'; Editable = false; }
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; Editable = false; }
                field(binCode; Rec."Bin Code") { Caption = 'binCode'; }
            }
        }
    }
    trigger OnOpenPage()
    var
        FilterMgmt: Codeunit "DOPSWHS App Role Filter Mgmt";
        RecRef: RecordRef;
    begin
        RecRef.GetTable(Rec);
        FilterMgmt.ApplyForCurrentUser(RecRef, Enum::"DOPSWHS App Filter Entity"::AssemblyLine);
        RecRef.SetTable(Rec);
    end;

}
