table 72026 "DOPSWHS Warehouse Mgr Cue"
{
    Caption = 'Warehouse Manager Cues';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10]) { Caption = 'Primary Key'; DataClassification = SystemMetadata; }
        // TODO Sprint H+ post-deploy: restore status filter if the target BC app exposes receipt/activity status fields.
        field(10; "Open Receipts"; Integer) { Caption = 'Open Receipts'; FieldClass = FlowField; CalcFormula = count("Warehouse Receipt Header"); }
        field(20; "Open Picks"; Integer) { Caption = 'Open Picks'; FieldClass = FlowField; CalcFormula = count("Warehouse Activity Header" where(Type = const(Pick))); }
        field(30; "Open Shipments"; Integer) { Caption = 'Open Shipments'; FieldClass = FlowField; CalcFormula = count("Warehouse Shipment Header" where(Status = const(Released))); }
        // TODO Sprint H+ post-deploy: restore late-pick date filter if the target BC app exposes due date on activity headers.
        field(40; "Late Picks"; Integer) { Caption = 'Late Picks'; FieldClass = FlowField; CalcFormula = count("Warehouse Activity Header" where(Type = const(Pick))); }
        field(50; "Unbuilt LPs"; Integer) { Caption = 'Unbuilt LPs'; FieldClass = FlowField; CalcFormula = count("DOPSWHS LP Header" where(Status = const(Open))); }
        field(60; "Count Discrepancies"; Integer) { Caption = 'Count Discrepancies'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Count Sheet Header" where(Status = const(InProgress))); }
        field(70; "Devices Online"; Integer) { Caption = 'Devices Online'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Device Registration" where("Last Seen DateTime" = field("Online Since DateTime Filter"))); }
        // ELOG dashboard: 3 ayrı Pack Station bölümü (Solo/Bulk/Mono-SKU).
        field(80; "Open Solo Pack Sessions"; Integer) { Caption = 'Open Solo Pack Sessions'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Pack Session" where(Status = const(Open), Mode = const(Solo))); }
        field(81; "Open Bulk Pack Sessions"; Integer) { Caption = 'Open Bulk Pack Sessions'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Pack Session" where(Status = const(Open), Mode = const(Bulk))); }
        field(82; "Open Batch Pack Sessions"; Integer) { Caption = 'Open Mono-SKU Pack Sessions'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Pack Session" where(Status = const(Open), Mode = const(Batch))); }
        field(83; "Orders Ready for Packing"; Integer) { Caption = 'Orders Ready for Packing'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Packing Order" where(Status = const(Ready))); }
        field(84; "Orders Being Packed"; Integer) { Caption = 'Orders Being Packed'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Packing Order" where(Status = const("In Progress"))); }
        field(85; "Open Picking Orders"; Integer) { Caption = 'Open Picking Orders'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Picking Order Header" where(Status = const(Open))); }
        field(100; "Late Pick Date Filter"; Date) { Caption = 'Late Pick Date Filter'; FieldClass = FlowFilter; }
        field(110; "Online Since DateTime Filter"; DateTime) { Caption = 'Online Since DateTime Filter'; FieldClass = FlowFilter; }
    }

    keys { key(PK; "Primary Key") { Clustered = true; } }

    trigger OnInsert()
    begin
        "Primary Key" := '';
    end;
}
