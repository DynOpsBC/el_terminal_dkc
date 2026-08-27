page 72249 "DOPSWHS Test Run API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'testRun';
    EntitySetName = 'testRuns';
    SourceTable = "DOPSWHS Test Run";
    DelayedInsert = true;
    ODataKeyFields = SystemId;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Runs)
            {
                field(systemId; Rec.SystemId) { Caption = 'systemId'; Editable = false; }
                field(runNo; Rec."Run No.") { Caption = 'runNo'; }
                field(environmentCode; Rec."Environment Code") { Caption = 'environmentCode'; }
                field(userGroupCode; Rec."User Group Code") { Caption = 'userGroupCode'; }
                field(triggeredBy; Rec."Triggered By") { Caption = 'triggeredBy'; }
                field(startedDateTime; Rec."Started DateTime") { Caption = 'startedDateTime'; }
                field(completedDateTime; Rec."Completed DateTime") { Caption = 'completedDateTime'; }
                field(status; Rec.Status) { Caption = 'status'; }
                field(totalCases; Rec."Total Cases") { Caption = 'totalCases'; }
                field(passed; Rec.Passed) { Caption = 'passed'; }
                field(failed; Rec.Failed) { Caption = 'failed'; }
                field(skipped; Rec.Skipped) { Caption = 'skipped'; }
                field(pendingManual; Rec."Pending Manual") { Caption = 'pendingManual'; }
                field(durationSec; Rec."Duration (sec)") { Caption = 'durationSec'; }
                field(passRate; Rec."Pass Rate %") { Caption = 'passRate'; }
                field(notes; Rec.Notes) { Caption = 'notes'; }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetAutoCalcFields("Total Cases", Passed, Failed, Skipped, "Pending Manual");
    end;
}
