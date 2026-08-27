page 72481 "DOPSWHS Count Sheet Line Part"
{
    Caption = 'Count Sheet Lines';
    PageType = ListPart;
    SourceTable = "DOPSWHS Count Sheet Line";
    ApplicationArea = All;
    AutoSplitKey = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                // Sayıldı: herhangi bir sayıcı slotuna miktar girildi mi?
                // Satır stili de buradan beslenir: sayıldı+fark yok = yeşil,
                // sayıldı+fark var = dikkat, sayılmadı = standart.
                field(Counted; CountedFlag)
                {
                    Caption = 'Sayıldı';
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = LineStyle;
                }
                field("Item No."; Rec."Item No.") { ApplicationArea = All; StyleExpr = LineStyle; }
                field(ItemDescription; ItemDescription)
                {
                    Caption = 'Description';
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = LineStyle;
                }
                field("Variant Code"; Rec."Variant Code") { ApplicationArea = All; }
                field("Bin Code"; Rec."Bin Code") { ApplicationArea = All; StyleExpr = LineStyle; }
                field("LP No."; Rec."LP No.") { ApplicationArea = All; StyleExpr = LineStyle; }
                field("LP Line No."; Rec."LP Line No.") { ApplicationArea = All; }
                field("Lot No."; Rec."Lot No.") { ApplicationArea = All; }
                field("Serial No."; Rec."Serial No.") { ApplicationArea = All; }
                field("Unit of Measure Code"; Rec."Unit of Measure Code") { ApplicationArea = All; }
                field("System Qty"; Rec."System Qty") { ApplicationArea = All; StyleExpr = LineStyle; }
                field("Counted Qty 1"; Rec."Counted Qty 1") { ApplicationArea = All; StyleExpr = LineStyle; }
                field("Counted Qty 2"; Rec."Counted Qty 2") { ApplicationArea = All; }
                field("Counted Qty 3"; Rec."Counted Qty 3") { ApplicationArea = All; }
                field(Variance; Rec.Variance) { ApplicationArea = All; StyleExpr = VarianceStyle; }
                field("Recount Required"; Rec."Recount Required") { ApplicationArea = All; StyleExpr = VarianceStyle; }
                field("Unexpected Stock"; Rec."Unexpected Stock") { ApplicationArea = All; StyleExpr = VarianceStyle; }
                field("Line No."; Rec."Line No.") { ApplicationArea = All; Visible = false; }
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        Item: Record Item;
    begin
        CountedFlag :=
            Rec."Counted 1" or Rec."Counted 2" or Rec."Counted 3" or
            (Rec."Counted Qty 1" <> 0) or (Rec."Counted Qty 2" <> 0) or (Rec."Counted Qty 3" <> 0);

        Clear(ItemDescription);
        if (Rec."Item No." <> '') and Item.Get(Rec."Item No.") then
            ItemDescription := Item.Description;

        // Fark: sayım girilmişse kazanan slotla anlık kıyas (post öncesi Variance
        // alanı henüz hesaplanmamış olabilir, o yüzden Counted Qty 1'e bakılır).
        if not CountedFlag then begin
            LineStyle := 'Standard';
            VarianceStyle := 'Subordinate';
        end else
            if (Rec.Variance <> 0) or (Rec."Counted Qty 1" <> Rec."System Qty") then begin
                LineStyle := 'Attention';
                VarianceStyle := 'Unfavorable';
            end else begin
                LineStyle := 'Favorable';
                VarianceStyle := 'Favorable';
            end;
        if Rec."Recount Required" then
            VarianceStyle := 'Unfavorable';
    end;

    var
        CountedFlag: Boolean;
        ItemDescription: Text[100];
        LineStyle: Text;
        VarianceStyle: Text;
}
