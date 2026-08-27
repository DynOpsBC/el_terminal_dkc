table 72007 "DOPSWHS IWX Report Selection"
{
    Caption = 'DOPSWHS IWX Report Selection';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Code"; Code[20]) { Caption = 'Code'; DataClassification = CustomerContent; }
        field(2; Usage; Enum "DOPSWHS IWX Report Usage") { Caption = 'Usage'; DataClassification = CustomerContent; }
        field(3; Sequence; Integer) { Caption = 'Sequence'; DataClassification = CustomerContent; }
        field(4; "Report ID"; Integer) { Caption = 'Report ID'; DataClassification = CustomerContent; TableRelation = AllObjWithCaption."Object ID" where("Object Type" = const(Report)); }
        field(5; "Use For Email"; Boolean) { Caption = 'Use For Email'; DataClassification = CustomerContent; }
    }

    keys { key(PK; "Code") { Clustered = true; } key(UsageSequence; Usage, Sequence) { } }
}
