tableextension 72403 "DOPSWHS Whse Activity Line" extends "Warehouse Activity Line"
{
    fields
    {
        field(72403; "LP No."; Code[20])
        {
            Caption = 'LP No.';
            DataClassification = CustomerContent;
            TableRelation = "DOPSWHS LP Header"."No.";

            trigger OnValidate()
            begin
                FillActivityLinesFromLP();
            end;
        }
        field(72404; "Target LP No."; Code[20])
        {
            Caption = 'Target LP No.';
            DataClassification = CustomerContent;
            TableRelation = "DOPSWHS LP Header"."No.";
        }
    }

    local procedure FillActivityLinesFromLP()
    var
        LPLine: Record "DOPSWHS LP Line";
        WhseActivityLine: Record "Warehouse Activity Line";
    begin
        if "LP No." = '' then
            exit;

        LPLine.SetRange("LP No.", "LP No.");
        if LPLine.IsEmpty() then
            exit;

        WhseActivityLine.SetRange("Activity Type", "Activity Type");
        WhseActivityLine.SetRange("No.", "No.");
        if WhseActivityLine.FindSet(true) then
            repeat
                LPLine.SetRange("Item No.", WhseActivityLine."Item No.");
                if not LPLine.IsEmpty() then
                    if WhseActivityLine."LP No." = '' then begin
                        WhseActivityLine."LP No." := "LP No.";
                        WhseActivityLine.Modify(true);
                    end;
                LPLine.SetRange("Item No.");
            until WhseActivityLine.Next() = 0;
    end;
}
