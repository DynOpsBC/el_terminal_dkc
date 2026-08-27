table 72018 "DOPSWHS Count Counter"
{
    Caption = 'Count Counter';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Sheet No."; Code[20]) { Caption = 'Sheet No.'; DataClassification = CustomerContent; TableRelation = "DOPSWHS Count Sheet Header"; }
        field(2; "Counter Slot"; Integer) { Caption = 'Counter Slot'; DataClassification = CustomerContent; MinValue = 1; MaxValue = 3; }
        field(10; "User ID"; Code[50])
        {
            Caption = 'User ID';
            DataClassification = EndUserIdentifiableInformation;
            TableRelation = "DOPSWHS Local User".Username where(Disabled = const(false));

            trigger OnValidate()
            var
                LocalUser: Record "DOPSWHS Local User";
            begin
                if "User ID" = '' then begin
                    "Assigned DateTime" := 0DT;
                    exit;
                end;

                if not LocalUser.Get(CopyStr("User ID", 1, MaxStrLen(LocalUser.Username))) then
                    Error(UserNotFoundErr, "User ID");
                if LocalUser.Disabled then
                    Error(UserDisabledErr, "User ID");

                "Assigned DateTime" := CurrentDateTime();
            end;
        }
        field(20; "Assigned DateTime"; DateTime) { Caption = 'Assigned DateTime'; DataClassification = CustomerContent; }
    }

    keys
    {
        key(PK; "Sheet No.", "Counter Slot") { Clustered = true; }
        key(User; "User ID") { }
    }

    trigger OnInsert()
    begin
        EnsureSheetIsMutable();
    end;

    trigger OnModify()
    begin
        EnsureSheetIsMutable();
    end;

    trigger OnDelete()
    begin
        EnsureSheetIsMutable();
    end;

    trigger OnRename()
    begin
        EnsureSheetIsMutable();
    end;

    local procedure EnsureSheetIsMutable()
    var
        CountHeader: Record "DOPSWHS Count Sheet Header";
    begin
        CountHeader.Get("Sheet No.");
        if CountHeader.Status = CountHeader.Status::Posted then
            Error(PostedSheetImmutableErr, "Sheet No.");
    end;

    var
        UserNotFoundErr: Label '%1 kullanıcısı Local WMS Users listesinde bulunamadı.';
        UserDisabledErr: Label '%1 kullanıcısı devre dışıdır. Etkin bir WMS kullanıcısı seçin.';
        PostedSheetImmutableErr: Label 'Posted count sheet %1 cannot be changed or deleted.';
}
