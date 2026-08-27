page 72087 "DOPSWHS Bin API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'bin';
    EntitySetName = 'bins';
    SourceTable = Bin;
    DelayedInsert = true;
    ODataKeyFields = "Location Code", Code;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; }
                field(code; Rec.Code) { Caption = 'code'; }
                field(description; Rec.Description) { Caption = 'description'; }
                field(zoneCode; Rec."Zone Code") { Caption = 'zoneCode'; }
                field(binTypeCode; Rec."Bin Type Code") { Caption = 'binTypeCode'; }
                field(warehouseClassCode; Rec."Warehouse Class Code") { Caption = 'warehouseClassCode'; }
                field(blockMovement; Rec."Block Movement") { Caption = 'blockMovement'; }
                field(binRanking; Rec."Bin Ranking") { Caption = 'binRanking'; }
                field(maximumCubage; Rec."Maximum Cubage") { Caption = 'maximumCubage'; }
                field(maximumWeight; Rec."Maximum Weight") { Caption = 'maximumWeight'; }
            }
        }
    }

    [ServiceEnabled]
    procedure printLabel(printerId: Code[50]; copies: Integer)
    var
        Dispatcher: Codeunit "DOPSWHS Print Dispatcher";
    begin
        Dispatcher.PrintBinLabel(Rec, printerId, copies);
    end;
}
