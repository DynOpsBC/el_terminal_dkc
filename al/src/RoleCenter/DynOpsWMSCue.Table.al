table 72027 "DOPSWHS DynOps WMS Cue"
{
    Caption = 'DynOps Warehouse Management Cue';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10]) { Caption = 'Primary Key'; DataClassification = SystemMetadata; }

        // ===== RECEIVING (Mal Kabul) =====
        field(10; "Open Whse Receipts"; Integer) { Caption = 'Açık Mal Kabul'; FieldClass = FlowField; CalcFormula = count("Warehouse Receipt Header"); }
        field(11; "PO Pending Receive"; Integer) { Caption = 'Bekleyen PO'; FieldClass = FlowField; CalcFormula = count("Purchase Header" where("Document Type" = const(Order), Status = const(Released))); }
        field(12; "Transfer In Pending"; Integer) { Caption = 'Bekleyen Transfer In'; FieldClass = FlowField; CalcFormula = count("Transfer Header" where(Status = const(Released))); }

        // ===== PUT-AWAY (Yerleştirme) =====
        field(20; "Open PutAways"; Integer) { Caption = 'Açık Yerleştirme'; FieldClass = FlowField; CalcFormula = count("Warehouse Activity Header" where(Type = const("Put-away"))); }
        field(21; "Invt PutAways"; Integer) { Caption = 'Inventory Put-Away'; FieldClass = FlowField; CalcFormula = count("Warehouse Activity Header" where(Type = const("Invt. Put-away"))); }

        // ===== PICKING (Toplama) =====
        field(30; "Open Picks"; Integer) { Caption = 'Açık Toplama'; FieldClass = FlowField; CalcFormula = count("Warehouse Activity Header" where(Type = const(Pick))); }
        field(31; "Invt Picks"; Integer) { Caption = 'Inventory Pick'; FieldClass = FlowField; CalcFormula = count("Warehouse Activity Header" where(Type = const("Invt. Pick"))); }
        // TODO Sprint H+ post-deploy: restore date filter when activity-header due-date field is exposed in target symbols.
        field(32; "Late Picks"; Integer) { Caption = 'Geç Toplamalar'; FieldClass = FlowField; CalcFormula = count("Warehouse Activity Header" where(Type = const(Pick))); }

        // ===== SHIPPING (Sevkiyat) =====
        field(40; "Released Shipments"; Integer) { Caption = 'Released Sevkiyatlar'; FieldClass = FlowField; CalcFormula = count("Warehouse Shipment Header" where(Status = const(Released))); }
        field(41; "Sales Ship Pending"; Integer) { Caption = 'Sales Sevk Bekleyen'; FieldClass = FlowField; CalcFormula = count("Sales Header" where("Document Type" = const(Order), Status = const(Released))); }
        field(42; "Transfer Ship Pending"; Integer) { Caption = 'Transfer Sevk Bekleyen'; FieldClass = FlowField; CalcFormula = count("Transfer Header" where(Status = const(Released))); }

        // ===== MOVEMENTS (Hareketler) =====
        field(50; "Open Movements"; Integer) { Caption = 'Açık Hareketler'; FieldClass = FlowField; CalcFormula = count("Warehouse Activity Header" where(Type = const(Movement))); }
        field(51; "Invt Movements"; Integer) { Caption = 'Inventory Movement'; FieldClass = FlowField; CalcFormula = count("Warehouse Activity Header" where(Type = const("Invt. Movement"))); }

        // ===== PRODUCTION (Üretim) =====
        field(60; "Released Prod Orders"; Integer) { Caption = 'Açık Üretim Emirleri'; FieldClass = FlowField; CalcFormula = count("Production Order" where(Status = const(Released))); }

        // ===== ASSEMBLY (Montaj) =====
        field(65; "Open Assembly"; Integer) { Caption = 'Açık Montaj'; FieldClass = FlowField; CalcFormula = count("Assembly Header" where("Document Type" = const(Order))); }

        // ===== LICENSE PLATE (LP Yönetimi) =====
        field(70; "Open LPs"; Integer) { Caption = 'Açık LP'; FieldClass = FlowField; CalcFormula = count("DOPSWHS LP Header" where(Status = const(Open))); }
        field(71; "Built LPs"; Integer) { Caption = 'İnşa Edilmiş LP'; FieldClass = FlowField; CalcFormula = count("DOPSWHS LP Header" where(Status = const(Built))); }
        field(72; "Assigned LPs"; Integer) { Caption = 'Atanmış LP'; FieldClass = FlowField; CalcFormula = count("DOPSWHS LP Header" where(Status = const(Assigned))); }
        field(73; "Unbuilt LPs"; Integer) { Caption = 'Yıkılmış LP'; FieldClass = FlowField; CalcFormula = count("DOPSWHS LP Header" where(Status = const(Unbuilt))); }

        // ===== INVENTORY COUNT (Sayım) =====
        field(80; "Active Count Sheets"; Integer) { Caption = 'Aktif Sayım'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Count Sheet Header" where(Status = const(Open))); }
        field(81; "InProgress Counts"; Integer) { Caption = 'Devam Eden Sayım'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Count Sheet Header" where(Status = const(InProgress))); }

        // ===== SYSTEM ADMIN (Sistem) =====
        field(90; "Total Devices"; Integer) { Caption = 'Kayıtlı Cihazlar'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Device Registration"); }
        field(91; "Devices Online"; Integer) { Caption = 'Çevrimiçi Cihazlar'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Device Registration" where("Last Seen DateTime" = field("Online Since DateTime Filter"))); }
        field(92; "Pending Sync Conflicts"; Integer) { Caption = 'Bekleyen Sync Conflict'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Sync Conflict Buffer"); }
        field(93; "Webhook Events Today"; Integer) { Caption = 'Bugün Webhook'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Webhook Audit"); }

        // ===== FILTERS =====
        field(100; "Late Pick Date Filter"; Date) { Caption = 'Late Pick Date Filter'; FieldClass = FlowFilter; }
        field(110; "Online Since DateTime Filter"; DateTime) { Caption = 'Online Since DateTime Filter'; FieldClass = FlowFilter; }

        // ===== TEST CENTER =====
        field(200; "Total Test Cases"; Integer) { Caption = 'Toplam Test Case'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Test Case" where(Active = const(true))); }
        field(201; "Recent Test Runs"; Integer) { Caption = 'Test Run Adedi'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Test Run"); }
        field(202; "Last Run Pass Rate"; Integer) { Caption = 'Toplam PASS'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Test Run Result" where(Status = const(Passed))); }
        field(203; "Pending Manual Total"; Integer) { Caption = 'Manuel Bekleyen'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Test Run Result" where(Status = const(PendingManual))); }
        field(204; "Recent Failures 7d"; Integer) { Caption = 'Failed Adedi'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Test Run Result" where(Status = const(Failed))); }
        field(205; "Active Environments"; Integer) { Caption = 'Aktif Environment'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Test Environment" where(Active = const(true))); }
        field(206; "Active User Groups"; Integer) { Caption = 'Aktif Kullanıcı Grubu'; FieldClass = FlowField; CalcFormula = count("DOPSWHS Test User Group" where(Active = const(true))); }
    }

    keys { key(PK; "Primary Key") { Clustered = true; } }

    trigger OnInsert()
    begin
        "Primary Key" := '';
    end;
}
