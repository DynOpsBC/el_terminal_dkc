page 72250 "DOPSWHS Test Run Result API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'testRunResult';
    EntitySetName = 'testRunResults';
    SourceTable = "DOPSWHS Test Run Result";
    DelayedInsert = true;
    ODataKeyFields = SystemId;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(systemId; Rec.SystemId) { Caption = 'systemId'; Editable = false; }
                field(runNo; Rec."Run No.") { Caption = 'runNo'; }
                field(testCaseCode; Rec."Test Case Code") { Caption = 'testCaseCode'; }
                field(status; Rec.Status) { Caption = 'status'; }
                field(section; Rec.Section) { Caption = 'section'; }
                field(title; Rec.Title) { Caption = 'title'; }
                field(startedDateTime; Rec."Started DateTime") { Caption = 'startedDateTime'; }
                field(completedDateTime; Rec."Completed DateTime") { Caption = 'completedDateTime'; }
                field(durationMs; Rec."Duration Ms") { Caption = 'durationMs'; }
                field(errorMessage; Rec."Error Message") { Caption = 'errorMessage'; }
                field(surrogateUsed; Rec."Surrogate Used") { Caption = 'surrogateUsed'; }
                field(automationType; Rec."Automation Type") { Caption = 'automationType'; }
                field(notes; Rec.Notes) { Caption = 'notes'; }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetAutoCalcFields(Section, Title, "Automation Type");
    end;
}
