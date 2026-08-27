table 72352 "DOPSWHS Picking Order Header"
{
    Caption = 'Toplanacak Siparişler';
    DataClassification = CustomerContent;
    LookupPageId = "DOPSWHS Picking Order List";
    DrillDownPageId = "DOPSWHS Picking Order List";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
            DataClassification = CustomerContent;
        }
        field(10; Description; Text[100]) { Caption = 'Description'; DataClassification = CustomerContent; }
        field(20; "Location Code"; Code[10]) { Caption = 'Location Code'; TableRelation = Location; DataClassification = CustomerContent; }
        field(30; Status; Enum "DOPSWHS Picking Order Status") { Caption = 'Status'; DataClassification = CustomerContent; Editable = false; }
        // Toplama grubunun ELOG akış tipi. Multi/Mono/Tek SKU liste sayfaları
        // (72364/72365/72366) kaynağı bu alanla filtreler; boş = mod atanmamış
        // standart BC pick'i, "Tümü" görünümünde çıkar.
        field(35; "Order Flow Mode"; Enum "DOPSWHS Pick Mode") { Caption = 'V2 Sipariş Tipi'; DataClassification = CustomerContent; }
        // Atama yalnızca "Toplayıcı Ata" aksiyonundan yapılır. Değer hem
        // yerel WMS kullanıcısı hem BC kullanıcısı olabileceği için tek bir
        // tabloya TableRelation vermek doğru değildir.
        field(40; "Assigned User ID"; Code[50]) { Caption = 'Assigned User ID'; DataClassification = EndUserIdentifiableInformation; }
        field(50; "Warehouse Pick No."; Code[20]) { Caption = 'Warehouse Pick No.'; Editable = false; DataClassification = CustomerContent; }
        field(60; "Warehouse Shipment No."; Code[20]) { Caption = 'Warehouse Shipment No.'; Editable = false; DataClassification = CustomerContent; }
        field(70; "Created By User"; Code[50]) { Caption = 'Created By User'; Editable = false; DataClassification = EndUserIdentifiableInformation; }
        field(80; "Created DateTime"; DateTime) { Caption = 'Created DateTime'; Editable = false; DataClassification = CustomerContent; }
        field(90; "Completed DateTime"; DateTime) { Caption = 'Completed DateTime'; Editable = false; DataClassification = CustomerContent; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(StatusKey; Status, "Created DateTime") { }
    }

    trigger OnInsert()
    begin
        Status := Status::Open;
        "Created By User" := CopyStr(UserId(), 1, MaxStrLen("Created By User"));
        "Created DateTime" := CurrentDateTime();
    end;

    trigger OnDelete()
    var
        PickingOrderLine: Record "DOPSWHS Picking Order Line";
    begin
        if Status <> Status::Open then
            Error('Only open picking orders can be deleted.');
        PickingOrderLine.SetRange("Header Entry No.", "Entry No.");
        PickingOrderLine.DeleteAll(true);
    end;
}
