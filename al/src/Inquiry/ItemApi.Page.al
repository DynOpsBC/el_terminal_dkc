page 72086 "DOPSWHS Item API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'item';
    EntitySetName = 'items';
    SourceTable = Item;
    DelayedInsert = true;
    ODataKeyFields = "No.";
    ApplicationArea = All;
    Permissions = tabledata "Item Tracking Code" = R;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(no; Rec."No.") { Caption = 'no'; }
                field(description; Rec.Description) { Caption = 'description'; }
                field(baseUnitOfMeasure; Rec."Base Unit of Measure") { Caption = 'baseUnitOfMeasure'; }
                field(lotTrackingRequired; LotTrackingRequired)
                {
                    Caption = 'lotTrackingRequired';
                    Editable = false;
                }
                field(serialTrackingRequired; SerialTrackingRequired)
                {
                    Caption = 'serialTrackingRequired';
                    Editable = false;
                }
                field(itemCategoryCode; Rec."Item Category Code") { Caption = 'itemCategoryCode'; }
                field(blocked; Rec.Blocked) { Caption = 'blocked'; }
                field(defaultLpTemplateCode; Rec."DOPSWHS Default LP Template") { Caption = 'defaultLpTemplateCode'; }
                field(defaultPrintRuleCode; Rec."DOPSWHS Default Print Rule") { Caption = 'defaultPrintRuleCode'; }
                // PDF feedback (Item Inquiry section 1): clients reported
                // "stok yok" because Inventory FlowField was missing.
                // Exposes the standard Inventory + on-order quantities so
                // mobile/web can render a real stock card.
                field(inventory; Rec.Inventory)
                {
                    Caption = 'inventory';
                    Editable = false;
                }
                field(quantityOnPurchOrder; Rec."Qty. on Purch. Order")
                {
                    Caption = 'quantityOnPurchOrder';
                    Editable = false;
                }
                field(quantityOnSalesOrder; Rec."Qty. on Sales Order")
                {
                    Caption = 'quantityOnSalesOrder';
                    Editable = false;
                }
                field(quantityOnProdOrder; Rec."Qty. on Prod. Order")
                {
                    Caption = 'quantityOnProdOrder';
                    Editable = false;
                }
                field(reservedQtyOnInventory; Rec."Reserved Qty. on Inventory")
                {
                    Caption = 'reservedQtyOnInventory';
                    Editable = false;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        // FlowField'lar API page'inde otomatik hesaplanmaz; explicit CalcFields
        // çağrılmazsa response'da Inventory=0 döner ve Item Inquiry "stok yok"
        // göstermeye devam eder (Codex review Finding 6).
        Rec.CalcFields(
            Inventory,
            "Qty. on Purch. Order",
            "Qty. on Sales Order",
            "Qty. on Prod. Order",
            "Reserved Qty. on Inventory");

        Clear(LotTrackingRequired);
        Clear(SerialTrackingRequired);
        if (Rec."Item Tracking Code" <> '') and ItemTrackingCode.Get(Rec."Item Tracking Code") then begin
            LotTrackingRequired :=
                ItemTrackingCode."Lot Specific Tracking" or
                ItemTrackingCode."Lot Warehouse Tracking";
            SerialTrackingRequired :=
                ItemTrackingCode."SN Specific Tracking" or
                ItemTrackingCode."SN Warehouse Tracking";
        end;
    end;

    var
        LotTrackingRequired: Boolean;
        SerialTrackingRequired: Boolean;

    [ServiceEnabled]
    procedure printLabel(printerId: Code[50]; copies: Integer)
    var
        Dispatcher: Codeunit "DOPSWHS Print Dispatcher";
    begin
        Dispatcher.PrintItemLabel(Rec, printerId, copies);
    end;
}
