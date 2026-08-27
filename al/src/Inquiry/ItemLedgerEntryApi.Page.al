page 72214 "DOPSWHS Item Ledger Entry API"
{
    // Item Inquiry "Son Hareketler" (recent transactions) — müşteri isteği.
    // Salt-okunur; mobil app itemNo ile filtreleyip postingDate'e göre sıralar.
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'itemLedgerEntry';
    EntitySetName = 'itemLedgerEntries';
    SourceTable = "Item Ledger Entry";
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
                field(postingDate; Rec."Posting Date") { Caption = 'postingDate'; }
                field(entryType; Rec."Entry Type") { Caption = 'entryType'; }
                field(documentNo; Rec."Document No.") { Caption = 'documentNo'; }
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; }
                field(quantity; Rec.Quantity) { Caption = 'quantity'; }
                field(lotNo; Rec."Lot No.") { Caption = 'lotNo'; }
                field(serialNo; Rec."Serial No.") { Caption = 'serialNo'; }
                field(lpNo; Rec."DOPSWHS LP No.") { Caption = 'lpNo'; }
            }
        }
    }
}
