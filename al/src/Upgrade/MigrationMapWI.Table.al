table 72025 "DOPSWHS Migration Map WI"
{
    Caption = 'DOPSWHS Migration Map WI';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'Entry No.'; AutoIncrement = true; DataClassification = SystemMetadata; }
        field(10; "WI Table No."; Integer) { Caption = 'WI Table No.'; DataClassification = CustomerContent; }
        field(20; "DOPSWHS Table No."; Integer) { Caption = 'DOPSWHS Table No.'; DataClassification = CustomerContent; }
        field(30; "WI Field No."; Integer) { Caption = 'WI Field No.'; DataClassification = CustomerContent; }
        field(40; "DOPSWHS Field No."; Integer) { Caption = 'DOPSWHS Field No.'; DataClassification = CustomerContent; }
        field(50; "Map Note"; Text[250]) { Caption = 'Map Note'; DataClassification = CustomerContent; }
    }

    keys { key(PK; "Entry No.") { Clustered = true; } }

    procedure InsertDefaultMappings()
    begin
        InsertMapping(50000, Database::"DOPSWHS LP Header", 1, 1, 'WI LP header number to DOPSWHS LP number');
        InsertMapping(50001, Database::"DOPSWHS LP Line", 1, 1, 'WI LP line parent to DOPSWHS LP line parent');
        InsertMapping(50002, Database::"DOPSWHS LP Movement Ledger", 1, 1, 'WI movement history to movement ledger');
        InsertMapping(50003, Database::"DOPSWHS LP Template", 1, 1, 'WI template code to DOPSWHS template code');
        InsertMapping(50004, Database::"DOPSWHS IWX Report Selection", 1, 1, 'WI report selection to DOPSWHS print selection');
    end;

    local procedure InsertMapping(WITableNo: Integer; TargetTableNo: Integer; WIFieldNo: Integer; TargetFieldNo: Integer; Note: Text[250])
    var
        Existing: Record "DOPSWHS Migration Map WI";
    begin
        Existing.SetRange("WI Table No.", WITableNo);
        Existing.SetRange("DOPSWHS Table No.", TargetTableNo);
        Existing.SetRange("WI Field No.", WIFieldNo);
        Existing.SetRange("DOPSWHS Field No.", TargetFieldNo);
        if not Existing.IsEmpty() then
            exit;
        Init();
        "WI Table No." := WITableNo;
        "DOPSWHS Table No." := TargetTableNo;
        "WI Field No." := WIFieldNo;
        "DOPSWHS Field No." := TargetFieldNo;
        "Map Note" := Note;
        Insert(true);
    end;
}
