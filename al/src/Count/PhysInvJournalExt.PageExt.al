pageextension 72310 "DOPSWHS Phys Inv Journal Ext" extends "Phys. Inventory Journal"
{
    layout
    {
        addlast(Control1)
        {
            field("DOPSWHS Source Count Sheet"; SourceCountSheetNo)
            {
                Caption = 'Source Count Sheet';
                ApplicationArea = All;
                Editable = false;
                TableRelation = "DOPSWHS Count Sheet Header";
                trigger OnDrillDown()
                var
                    CountHeader: Record "DOPSWHS Count Sheet Header";
                begin
                    if SourceCountSheetNo = '' then
                        exit;
                    CountHeader.Get(SourceCountSheetNo);
                    Page.Run(Page::"DOPSWHS Count Sheet Card", CountHeader);
                end;
            }
        }
    }

    actions
    {
        addlast(Processing)
        {
            action(OpenCountSheetCard)
            {
                Caption = 'Open Count Sheet Card';
                ApplicationArea = All;
                Image = ViewDocumentLine;
                trigger OnAction()
                var
                    CountHeader: Record "DOPSWHS Count Sheet Header";
                begin
                    if not CountHeader.Get(SourceCountSheetNo) then
                        Error('No count sheet is linked to batch %1.', Rec."Journal Batch Name");
                    Page.Run(Page::"DOPSWHS Count Sheet Card", CountHeader);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        SourceCountSheetNo := FindSourceCountSheet();
    end;

    local procedure FindSourceCountSheet(): Code[20]
    var
        CountHeader: Record "DOPSWHS Count Sheet Header";
    begin
        CountHeader.SetRange("Source Phys. Inv. Journal Batch", Rec."Journal Batch Name");
        if CountHeader.FindFirst() then
            exit(CountHeader."No.");
        exit('');
    end;

    var
        SourceCountSheetNo: Code[20];
}
