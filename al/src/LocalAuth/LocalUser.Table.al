table 72284 "DOPSWHS Local User"
{
    // E-postası/AAD hesabı olmayan operatörler için BC içi yerel kullanıcı kaydı.
    // Mobile app `/localUsers('<username>')/Microsoft.NAV.verify` bound action'ı ile
    // şifreyi doğrular, sonrasında her API çağrısında bu username "DOPSWHS App User Role"
    // mantığıyla rol/filter resolve'unda kullanılır (paylaşımlı bir admin AAD token ile).
    //
    // Şifre hash'i SHA-256(salt + password). Salt her kayıt için unique (GUID).
    Caption = 'Local WMS User';
    DataClassification = EndUserIdentifiableInformation;
    Access = Public;
    LookupPageId = "DOPSWHS Local User List";
    DrillDownPageId = "DOPSWHS Local User List";

    fields
    {
        field(1;  "Username"; Code[20])
        {
            Caption = 'Username';
            NotBlank = true;
            DataClassification = EndUserIdentifiableInformation;
        }
        field(10; "Display Name"; Text[100])  { Caption = 'Display Name'; }
        field(20; "Password Hash"; Text[128])  { Caption = 'Password Hash (SHA-256)'; Editable = false; }
        field(21; "Password Salt"; Text[40])   { Caption = 'Password Salt'; Editable = false; }
        field(30; "Default Location Code"; Code[10]) { Caption = 'Default Location'; TableRelation = Location; }
        field(31; "Default Bin Code"; Code[20])
        {
            Caption = 'Default Bin';
            TableRelation = Bin.Code where("Location Code" = field("Default Location Code"));
        }
        field(40; "Locale"; Code[10]) { Caption = 'Locale'; ToolTip = 'tr / en / de'; }
        field(50; "Hide Test Tools"; Boolean)  { Caption = 'Hide Test Tools'; InitValue = true; }
        field(51; "Hide Admin Tools"; Boolean) { Caption = 'Hide Admin Tools'; InitValue = true; }
        field(60; "Disabled"; Boolean)         { Caption = 'Disabled'; }
        field(70; "Last Login DateTime"; DateTime) { Caption = 'Last Login'; Editable = false; }
        field(71; "Failed Login Count"; Integer)   { Caption = 'Failed Logins'; Editable = false; }
        field(80; "Created DateTime"; DateTime) { Caption = 'Created'; Editable = false; }
        field(81; "Created By"; Code[50])       { Caption = 'Created By'; Editable = false; }
        field(99; "Last Modified DateTime"; DateTime) { Caption = 'Modified'; Editable = false; }
    }

    keys
    {
        key(PK; "Username") { Clustered = true; }
        key(Disabled; Disabled) { }
    }

    trigger OnInsert()
    begin
        if "Created DateTime" = 0DT then "Created DateTime" := CurrentDateTime();
        if "Created By" = '' then "Created By" := CopyStr(UserId(), 1, 50);
        "Last Modified DateTime" := CurrentDateTime();
    end;

    trigger OnModify()
    begin
        "Last Modified DateTime" := CurrentDateTime();
    end;
}
