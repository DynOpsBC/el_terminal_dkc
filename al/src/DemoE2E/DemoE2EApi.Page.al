page 72283 "DOPSWHS Demo E2E API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'demoE2EResult';
    EntitySetName = 'demoE2EResults';
    SourceTable = "DOPSWHS Demo E2E Result";
    DelayedInsert = true;
    ODataKeyFields = "Function Code", "Transaction No.";
    Caption = 'Demo E2E Result API';

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(functionCode; Rec."Function Code") { Caption = 'functionCode'; }
                field(transactionNo; Rec."Transaction No.") { Caption = 'transactionNo'; }
                field(title; Rec.Title) { Caption = 'title'; }
                field(status; Rec.Status) { Caption = 'status'; }
                field(startedDateTime; Rec."Started DateTime") { Caption = 'startedDateTime'; }
                field(completedDateTime; Rec."Completed DateTime") { Caption = 'completedDateTime'; }
                field(durationMs; Rec."Duration Ms") { Caption = 'durationMs'; }
                field(lpNo; Rec."LP No.") { Caption = 'lpNo'; }
                field(sourceDocumentNo; Rec."Source Document No.") { Caption = 'sourceDocumentNo'; }
                field(itemNo; Rec."Item No.") { Caption = 'itemNo'; }
                field(quantity; Rec.Quantity) { Caption = 'quantity'; }
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; }
                field(surrogate; Rec.Surrogate) { Caption = 'surrogate'; }
                field(resultDetail; Rec."Result Detail") { Caption = 'resultDetail'; }
                field(errorMessage; Rec."Error Message") { Caption = 'errorMessage'; }
                field(runNo; Rec."Run No.") { Caption = 'runNo'; }
            }
        }
    }

    [ServiceEnabled]
    procedure runAll()
    var
        Suite: Codeunit "DOPSWHS Demo E2E Suite";
    begin
        Suite.RunAll();
    end;

    trigger OnOpenPage()
    var
        FilterMgmt: Codeunit "DOPSWHS App Role Filter Mgmt";
        RecRef: RecordRef;
    begin
        // No specific Filter Entity for Demo E2E — generic test result table, OPERATOR/admin sees all.
        // Role filter pattern intentionally omitted here.
    end;
}
