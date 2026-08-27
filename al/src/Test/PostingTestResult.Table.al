table 72251 "DOPSWHS Posting Test Result"
{
    Caption = 'Posting Test Result';
    DataClassification = CustomerContent;
    Access = Public;

    fields
    {
        field(1; "Domain"; Code[20]) { Caption = 'Domain'; DataClassification = CustomerContent; }
        field(2; "Sort Order"; Integer) { Caption = 'Sort Order'; DataClassification = CustomerContent; }
        field(10; "Description"; Text[100]) { Caption = 'Description'; DataClassification = CustomerContent; }
        field(20; "Status"; Option)
        {
            Caption = 'Status';
            DataClassification = CustomerContent;
            OptionMembers = NotRun,Running,Passed,Failed,Skipped;
            OptionCaption = 'Not Run,Running,Passed,Failed,Skipped';
        }
        field(30; "Detail"; Text[250]) { Caption = 'Detail'; DataClassification = CustomerContent; }
        field(40; "Posted Doc No."; Code[35]) { Caption = 'Posted Doc No.'; DataClassification = CustomerContent; }
        field(50; "Run DateTime"; DateTime) { Caption = 'Run DateTime'; DataClassification = CustomerContent; }
        field(60; "Duration (ms)"; Integer) { Caption = 'Duration (ms)'; DataClassification = CustomerContent; }
    }

    keys
    {
        key(PK; "Domain") { Clustered = true; }
        key(Sort; "Sort Order") { }
    }
}
