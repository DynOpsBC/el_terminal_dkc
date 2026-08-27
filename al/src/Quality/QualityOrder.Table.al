table 72254 "DOPSWHS Quality Order"
{
    Caption = 'Quality Order';
    DataClassification = CustomerContent;
    Access = Public;

    fields
    {
        field(1; "No."; Code[20]) { Caption = 'No.'; DataClassification = CustomerContent; }
        field(10; "Source Type"; Option)
        {
            Caption = 'Source Type';
            DataClassification = CustomerContent;
            OptionMembers = Manual,Receipt,Production,Shipment,Return;
            OptionCaption = 'Manual,Receipt,Production,Shipment,Return';
        }
        field(11; "Source No."; Code[20]) { Caption = 'Source No.'; DataClassification = CustomerContent; }
        field(20; "Item No."; Code[20]) { Caption = 'Item No.'; DataClassification = CustomerContent; TableRelation = Item; }
        field(21; "Item Description"; Text[100]) { Caption = 'Item Description'; DataClassification = CustomerContent; }
        field(30; "Quantity"; Decimal) { Caption = 'Quantity'; DataClassification = CustomerContent; }
        field(31; "Sample Size"; Decimal) { Caption = 'Sample Size'; DataClassification = CustomerContent; }
        field(40; "Location Code"; Code[10]) { Caption = 'Location Code'; DataClassification = CustomerContent; TableRelation = Location; }
        field(41; "Bin Code"; Code[20]) { Caption = 'Bin Code'; DataClassification = CustomerContent; }
        field(42; "LP No."; Code[20]) { Caption = 'LP No.'; DataClassification = CustomerContent; }
        field(50; "Status"; Option)
        {
            Caption = 'Status';
            DataClassification = CustomerContent;
            OptionMembers = Open,InProgress,Passed,Failed,Closed;
            OptionCaption = 'Open,In Progress,Passed,Failed,Closed';
        }
        field(60; "Inspector"; Code[50]) { Caption = 'Inspector'; DataClassification = EndUserIdentifiableInformation; }
        field(61; "Inspected DateTime"; DateTime) { Caption = 'Inspected DateTime'; DataClassification = CustomerContent; }
        field(70; "Result Notes"; Text[250]) { Caption = 'Result Notes'; DataClassification = CustomerContent; }
        field(71; "Reject Reason"; Code[20]) { Caption = 'Reject Reason'; DataClassification = CustomerContent; }
        field(72; "Quarantine Bin"; Code[20]) { Caption = 'Quarantine Bin'; DataClassification = CustomerContent; }
        field(80; "Created DateTime"; DateTime) { Caption = 'Created DateTime'; DataClassification = CustomerContent; }
        field(81; "Due Date"; Date) { Caption = 'Due Date'; DataClassification = CustomerContent; }
    }

    keys
    {
        key(PK; "No.") { Clustered = true; }
        key(Status; "Status") { }
        key(Source; "Source Type", "Source No.") { }
    }
}
