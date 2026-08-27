table 72012 "DOPSWHS LP Movement Ledger"
{
    Caption = 'DOPSWHS LP Movement Ledger';
    DataClassification = CustomerContent;
    LookupPageId = "DOPSWHS LP Movement Ledger";
    DrillDownPageId = "DOPSWHS LP Movement Ledger";

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'Entry No.'; DataClassification = CustomerContent; AutoIncrement = true; }
        field(10; "LP No."; Code[20]) { Caption = 'LP No.'; DataClassification = CustomerContent; TableRelation = "DOPSWHS LP Header"; }
        field(20; Action; Enum "DOPSWHS LP Action") { Caption = 'Action'; DataClassification = CustomerContent; }
        field(30; "From Bin"; Code[20]) { Caption = 'From Bin'; DataClassification = CustomerContent; }
        field(31; "To Bin"; Code[20]) { Caption = 'To Bin'; DataClassification = CustomerContent; }
        field(40; Quantity; Decimal) { Caption = 'Quantity'; DataClassification = CustomerContent; }
        field(50; "Item No."; Code[20]) { Caption = 'Item No.'; DataClassification = CustomerContent; TableRelation = Item; }
        field(60; "Lot Serial"; Code[50]) { Caption = 'Lot Serial'; DataClassification = CustomerContent; }
        field(70; "User ID"; Code[50]) { Caption = 'User ID'; DataClassification = CustomerContent; }
        field(80; "Device ID"; Code[50]) { Caption = 'Device ID'; DataClassification = CustomerContent; }
        field(90; DateTime; DateTime) { Caption = 'DateTime'; DataClassification = CustomerContent; }
        field(100; "Related Document"; Code[40]) { Caption = 'Related Document'; DataClassification = CustomerContent; }
    }

    keys { key(PK; "Entry No.") { Clustered = true; } key(LP; "LP No.", DateTime) { } }

    trigger OnModify()
    begin
        Error('LP movement ledger entries are immutable.');
    end;

    trigger OnDelete()
    begin
        Error('LP movement ledger entries are immutable.');
    end;
}
