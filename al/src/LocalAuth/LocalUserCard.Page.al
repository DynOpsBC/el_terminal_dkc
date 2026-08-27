page 72286 "DOPSWHS Local User Card"
{
    PageType = Card;
    SourceTable = "DOPSWHS Local User";
    Caption = 'Local WMS User';
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("Username"; Rec.Username) { ApplicationArea = All; }
                field("Display Name"; Rec."Display Name") { ApplicationArea = All; }
                field("Disabled"; Rec.Disabled) { ApplicationArea = All; }
            }
            group(Security)
            {
                Caption = 'Şifre';
                field(PasswordTemp; PasswordTemp)
                {
                    ApplicationArea = All;
                    Caption = 'Yeni Şifre';
                    ExtendedDatatype = Masked;
                    ToolTip = 'Yeni şifre belirleyin, Enter sonrası otomatik kaydedilir';

                    trigger OnValidate()
                    begin
                        if PasswordTemp <> '' then
                        begin
                            AuthMgt.Register(Rec.Username, Rec."Display Name", PasswordTemp, Rec."Default Location Code", Rec."Default Bin Code");
                            Message('Şifre kaydedildi.');
                            PasswordTemp := '';
                        end;
                    end;
                }
            }
            group(Defaults)
            {
                Caption = 'Mobil Varsayılanları';
                field("Default Location Code"; Rec."Default Location Code") { ApplicationArea = All; }
                field("Default Bin Code"; Rec."Default Bin Code") { ApplicationArea = All; }
                field("Locale"; Rec.Locale) { ApplicationArea = All; ToolTip = 'tr / en / de'; }
                field("Hide Test Tools"; Rec."Hide Test Tools") { ApplicationArea = All; }
                field("Hide Admin Tools"; Rec."Hide Admin Tools") { ApplicationArea = All; }
            }
            group(Telemetry)
            {
                Caption = 'Telemetri';
                field("Last Login DateTime"; Rec."Last Login DateTime") { ApplicationArea = All; Editable = false; }
                field("Failed Login Count"; Rec."Failed Login Count") { ApplicationArea = All; Editable = false; }
                field("Created DateTime"; Rec."Created DateTime") { ApplicationArea = All; Editable = false; }
                field("Created By"; Rec."Created By") { ApplicationArea = All; Editable = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SetPassword)
            {
                Caption = 'Şifre Belirle / Sıfırla';
                Image = EncryptionKeys;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Bu kullanıcı için yeni şifre belirler. Mobil app bu şifreyle "WMS Hesabı" girişini yapar.';

                trigger OnAction()
                begin
                    if Rec.Username = '' then
                        Error('Önce kullanıcı kaydını oluşturun ve username belirleyin.');
                    if not Dialog.Confirm('Bu kullanıcının şifresini "wms1234" olarak ayarla?', true) then
                        exit;
                    AuthMgt.Register(Rec.Username, Rec."Display Name", 'wms1234', Rec."Default Location Code", Rec."Default Bin Code");
                    Message('Şifre belirlendi: wms1234');
                end;
            }
        }
    }

    var
        AuthMgt: Codeunit "DOPSWHS Local Auth Mgmt";
        PasswordTemp: Text;
}
