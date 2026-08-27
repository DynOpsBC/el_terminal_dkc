page 72232 "DOPSWHS Count Ops API"
{
    // Hosts count operations that do not belong to an existing sheet.  The
    // singleton Setup record gives mobile a stable key:
    //   POST countOps('')/Microsoft.NAV.createV2
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'countOp';
    EntitySetName = 'countOps';
    SourceTable = "DOPSWHS Setup";
    ODataKeyFields = "Primary Key";
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
                field(primaryKey; Rec."Primary Key") { Caption = 'primaryKey'; Editable = false; }
            }
        }
    }

    [ServiceEnabled]
    procedure createV2(locationCode: Code[10]; userId: Code[50]): Code[20]
    var
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
    begin
        exit(CountMgmt.CreateV2Sheet(locationCode, userId));
    end;
}
