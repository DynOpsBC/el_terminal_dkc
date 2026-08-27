table 72011 "DOPSWHS LP Line"
{
    Caption = 'DOPSWHS LP Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "LP No."; Code[20]) { Caption = 'LP No.'; DataClassification = CustomerContent; TableRelation = "DOPSWHS LP Header"; }
        field(2; "Line No."; Integer) { Caption = 'Line No.'; DataClassification = CustomerContent; }
        field(10; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            DataClassification = CustomerContent;
            TableRelation = Item;
            trigger OnValidate()
            begin
                if ("Item No." <> '') and ("Child LP No." <> '') then
                    Error('A line can reference either an item or a child LP, not both.');
                RefreshLineWeight();
            end;
        }
        field(11; "Variant Code"; Code[10]) { Caption = 'Variant Code'; DataClassification = CustomerContent; TableRelation = "Item Variant".Code where("Item No." = field("Item No.")); }
        field(12; "Unit of Measure"; Code[10]) { Caption = 'Unit of Measure'; DataClassification = CustomerContent; TableRelation = "Unit of Measure"; }
        field(20; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            trigger OnValidate()
            begin
                RefreshLineWeight();
            end;
        }
        field(30; "Lot No."; Code[50]) { Caption = 'Lot No.'; DataClassification = CustomerContent; }
        field(31; "Serial No."; Code[50]) { Caption = 'Serial No.'; DataClassification = CustomerContent; }
        field(32; "Package No."; Code[50]) { Caption = 'Package No.'; DataClassification = CustomerContent; }
        field(40; "Child LP No."; Code[20])
        {
            Caption = 'Child LP No.';
            DataClassification = CustomerContent;
            TableRelation = "DOPSWHS LP Header";
            trigger OnValidate()
            begin
                if ("Child LP No." <> '') and ("Item No." <> '') then
                    Error('A line can reference either an item or a child LP, not both.');
            end;
        }
        field(50; "Expiration Date"; Date) { Caption = 'Expiration Date'; DataClassification = CustomerContent; }
        // ELOG LP kurma akışı: LP okut ürün + adet KAYNAK BİN okut.
        // Ürünün hangi raftan alınıp LP'ye konduğunun izi (satır bazında).
        field(55; "Source Bin Code"; Code[20]) { Caption = 'Source Bin Code'; DataClassification = CustomerContent; TableRelation = Bin.Code; }
        field(60; "Source Document Type"; Enum "DOPSWHS Assigned Doc Type") { Caption = 'Source Document Type'; DataClassification = CustomerContent; }
        field(61; "Source Document No."; Code[20]) { Caption = 'Source Document No.'; DataClassification = CustomerContent; }
        field(62; "Source Document Line No."; Integer) { Caption = 'Source Document Line No.'; DataClassification = CustomerContent; }
        field(63; "Source Document Quantity"; Decimal)
        {
            Caption = 'Source Document Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(90; "Line Weight kg"; Decimal) { Caption = 'Line Weight kg'; DataClassification = CustomerContent; Editable = false; }
    }

    keys
    {
        key(PK; "LP No.", "Line No.") { Clustered = true; }
        key(Item; "Item No.") { }
        key(Child; "Child LP No.") { }
    }

    trigger OnInsert()
    var
        LPLine: Record "DOPSWHS LP Line";
        Telemetry: Codeunit "DOPSWHS Telemetry";
    begin
        if "Line No." = 0 then begin
            LPLine.SetRange("LP No.", "LP No.");
            if LPLine.FindLast() then
                "Line No." := LPLine."Line No." + 10000
            else
                "Line No." := 10000;
        end;
        RefreshLineWeight();
        Telemetry.LogInfo('LP.LineAdded', "LP No.");
    end;

    local procedure RefreshLineWeight()
    var
        Item: Record Item;
    begin
        "Line Weight kg" := 0;
        if ("Item No." <> '') and Item.Get("Item No.") then
            "Line Weight kg" := Item."Net Weight" * Quantity;
    end;
}
