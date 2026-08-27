page 72341 "DOPSWHS Pack Session Subform"
{
    // Pack Station satır alt sayfası — ELOG ekranındaki gibi bekleyen satırlar
    // KIRMIZI (Unfavorable), tamamlananlar YEŞİL (Favorable) gösterilir.
    PageType = ListPart;
    Caption = 'Packed Lines';
    SourceTable = "DOPSWHS Pack Session Line";
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Source Order No."; Rec."Source Order No.") { ApplicationArea = All; StyleExpr = LineStyle; }
                field("Item No."; Rec."Item No.") { ApplicationArea = All; StyleExpr = LineStyle; }
                field(GTIN; Rec.GTIN) { ApplicationArea = All; StyleExpr = LineStyle; }
                field(Description; Rec.Description) { ApplicationArea = All; StyleExpr = LineStyle; }
                field("Qty. Expected"; Rec."Qty. Expected") { ApplicationArea = All; StyleExpr = LineStyle; }
                field("Qty. Packed"; Rec."Qty. Packed") { ApplicationArea = All; StyleExpr = LineStyle; }
                field("Unit of Measure Code"; Rec."Unit of Measure Code") { ApplicationArea = All; }
                field("Box LP No."; Rec."Box LP No.") { ApplicationArea = All; }
                field("Order Completed"; Rec."Order Completed") { ApplicationArea = All; StyleExpr = LineStyle; }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        if (Rec."Qty. Expected" > 0) and (Rec."Qty. Packed" >= Rec."Qty. Expected") then
            LineStyle := 'Favorable'
        else
            LineStyle := 'Unfavorable';
    end;

    var
        LineStyle: Text;
}
