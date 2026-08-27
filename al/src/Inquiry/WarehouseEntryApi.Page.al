page 72215 "DOPSWHS Warehouse Entry API"
{
    // Bin Inquiry "Whse Entries" (raf hareket geçmişi) — müşteri isteği.
    // Salt-okunur; mobil app locationCode+binCode ile filtreleyip tarihe göre sıralar.
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'warehouseEntry';
    EntitySetName = 'warehouseEntries';
    SourceTable = "Warehouse Entry";
    ODataKeyFields = "Entry No.";
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(entryNo; Rec."Entry No.") { Caption = 'entryNo'; }
                field(itemNo; Rec."Item No.") { Caption = 'itemNo'; }
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; }
                field(binCode; Rec."Bin Code") { Caption = 'binCode'; }
                field(zoneCode; Rec."Zone Code") { Caption = 'zoneCode'; }
                field(entryType; Rec."Entry Type") { Caption = 'entryType'; }
                field(registeringDate; Rec."Registering Date") { Caption = 'registeringDate'; }
                field(quantity; Rec.Quantity) { Caption = 'quantity'; }
                field(qtyBase; Rec."Qty. (Base)") { Caption = 'qtyBase'; }
                field(lotNo; Rec."Lot No.") { Caption = 'lotNo'; }
                field(serialNo; Rec."Serial No.") { Caption = 'serialNo'; }
                field(lpNo; Rec."DOPSWHS LP No.") { Caption = 'lpNo'; }
            }
        }
    }
}
