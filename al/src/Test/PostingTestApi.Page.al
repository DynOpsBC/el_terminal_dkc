page 72253 "DOPSWHS Posting Test API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'postingTest';
    EntitySetName = 'postingTests';
    SourceTable = "DOPSWHS Posting Test Result";
    DelayedInsert = true;
    ODataKeyFields = "Domain";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(domain; Rec."Domain") { Caption = 'domain'; }
                field(sortOrder; Rec."Sort Order") { Caption = 'sortOrder'; }
                field(description; Rec."Description") { Caption = 'description'; }
                field(status; Rec.Status) { Caption = 'status'; }
                field(detail; Rec."Detail") { Caption = 'detail'; }
                field(postedDocNo; Rec."Posted Doc No.") { Caption = 'postedDocNo'; }
                field(runDateTime; Rec."Run DateTime") { Caption = 'runDateTime'; }
                field(durationMs; Rec."Duration (ms)") { Caption = 'durationMs'; }
            }
        }
    }

    /// <summary>Runs the full posting smoke test (all WMS posting actions) and returns a JSON summary.</summary>
    [ServiceEnabled]
    procedure runAll(): Text
    var
        PostingSmokeTest: Codeunit "DOPSWHS Posting Smoke Test";
    begin
        exit(PostingSmokeTest.RunAll());
    end;
}
