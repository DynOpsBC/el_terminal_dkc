page 72487 "DOPSWHS Count Sheet Line API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'countSheetLine';
    EntitySetName = 'countSheetLines';
    SourceTable = "DOPSWHS Count Sheet Line";
    DelayedInsert = true;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    ODataKeyFields = "Sheet No.", "Line No.";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(sheetNo; Rec."Sheet No.") { Caption = 'sheetNo'; }
                field(lineNo; Rec."Line No.") { Caption = 'lineNo'; }
                field(itemNo; Rec."Item No.") { Caption = 'itemNo'; }
                // Ek alanlar: benzer isimli ürünleri ayırt etmek için (Item'dan çözülür).
                field(description; ItemDescription) { Caption = 'description'; Editable = false; }
                field(unitOfMeasureCode; Rec."Unit of Measure Code") { Caption = 'unitOfMeasureCode'; }
                field(variantCode; Rec."Variant Code") { Caption = 'variantCode'; }
                field(binCode; Rec."Bin Code") { Caption = 'binCode'; }
                field(lpNo; Rec."LP No.") { Caption = 'lpNo'; }
                field(lpLineNo; Rec."LP Line No.") { Caption = 'lpLineNo'; }
                field(lotNo; Rec."Lot No.") { Caption = 'lotNo'; }
                field(serialNo; Rec."Serial No.") { Caption = 'serialNo'; }
                field(systemQty; Rec."System Qty") { Caption = 'systemQty'; }
                field(countedQty1; Rec."Counted Qty 1") { Caption = 'countedQty1'; }
                field(countedQty2; Rec."Counted Qty 2") { Caption = 'countedQty2'; }
                field(countedQty3; Rec."Counted Qty 3") { Caption = 'countedQty3'; }
                field(unexpectedStock; Rec."Unexpected Stock") { Caption = 'unexpectedStock'; }
                field(counted1; Rec."Counted 1") { Caption = 'counted1'; }
                field(counted2; Rec."Counted 2") { Caption = 'counted2'; }
                field(counted3; Rec."Counted 3") { Caption = 'counted3'; }
                field(variance; Rec.Variance) { Caption = 'variance'; }
                field(recountRequired; Rec."Recount Required") { Caption = 'recountRequired'; }
            }
        }
    }

    trigger OnOpenPage()
    var
        FilterMgmt: Codeunit "DOPSWHS App Role Filter Mgmt";
        RecRef: RecordRef;
    begin
        RecRef.GetTable(Rec);
        FilterMgmt.ApplyForCurrentUser(RecRef, Enum::"DOPSWHS App Filter Entity"::CountSheetLine);
        RecRef.SetTable(Rec);
    end;

    trigger OnAfterGetRecord()
    var
        Item: Record Item;
    begin
        Clear(ItemDescription);
        if (Rec."Item No." <> '') and Item.Get(Rec."Item No.") then begin
            ItemDescription := Item.Description;
            if Rec."Unit of Measure Code" = '' then
                Rec."Unit of Measure Code" := Item."Base Unit of Measure";
        end;
    end;

    [ServiceEnabled]
    procedure recordCount(counterSlot: Integer; qty: Decimal)
    var
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
    begin
        CountMgmt.RecordCount(Rec."Sheet No.", Rec."Line No.", counterSlot, qty);
    end;

    var
        ItemDescription: Text[100];
}
