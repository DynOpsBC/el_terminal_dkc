page 72484 "DOPSWHS Supplier Lot API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'supplierLot';
    EntitySetName = 'supplierLots';
    SourceTable = "Lot No. Information";
    ODataKeyFields = SystemId;
    DelayedInsert = true;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(id; Rec.SystemId) { Caption = 'id'; }
                field(itemNo; Rec."Item No.") { Caption = 'itemNo'; }
                field(itemDescription; ItemDescription) { Caption = 'itemDescription'; Editable = false; }
                field(variantCode; Rec."Variant Code") { Caption = 'variantCode'; }
                field(lotNo; Rec."Lot No.") { Caption = 'lotNo'; }
                // APK sözleşmesi değişmez; alan artık BadeProduction'ın
                // mevcut Tedarikçi Lotu kaynağına (Description) bağlıdır.
                field(supplierLotNo; Rec.Description) { Caption = 'supplierLotNo'; }
                field(description; Rec.Description) { Caption = 'description'; }
                field(inventory; Rec.Inventory) { Caption = 'inventory'; }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetFilter(Description, '<>%1', '');
    end;

    trigger OnAfterGetRecord()
    var
        Item: Record Item;
    begin
        Clear(ItemDescription);
        if Item.Get(Rec."Item No.") then
            ItemDescription := Item.Description;
    end;

    var
        ItemDescription: Text[100];
}
