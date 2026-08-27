page 72342 "DOPSWHS Pick Tote Assignments"
{
    // Sepet–sipariş eşleştirmeleri: hangi tote hangi pick'te hangi siparişe
    // bağlı, paketlendi mi — ofis görünümü ve sorun giderme için.
    PageType = List;
    Caption = 'Pick Tote Assignments';
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "DOPSWHS Pick Tote Assignment";
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Assignments)
            {
                field("Pick No."; Rec."Pick No.") { ApplicationArea = All; }
                field("Source Order No."; Rec."Source Order No.") { ApplicationArea = All; }
                field("LP No."; Rec."LP No.") { ApplicationArea = All; }
                field("Location Code"; Rec."Location Code") { ApplicationArea = All; }
                field(Packed; Rec.Packed) { ApplicationArea = All; }
                field("Assigned By User"; Rec."Assigned By User") { ApplicationArea = All; }
                field("Assigned DateTime"; Rec."Assigned DateTime") { ApplicationArea = All; }
            }
        }
    }
}
