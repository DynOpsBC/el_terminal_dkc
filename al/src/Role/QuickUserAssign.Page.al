page 72287 "DOPSWHS Quick User Assign"
{
    // Hızlı rol atama kartı. Role Center " Hızlı Kullanıcı Atama"
    // tıklandığında veya search'ten "Quick User Assign" ile açılır.
    //
    // Operasyonel akış:
    //   1. Email yaz (kaanodabas@dynamicsops.com)
    //   2. Role dropdown'undan seç (INV_ADMIN, PICKER, vb.)
    // 3. "Ata" butonu Codeunit 72281 EnsureUserRole çağırır
    //   4. Result message ekrana basılır (PASS / zaten var / hata)
    //
    // Aynı kartta "Demo Seed (Kaan + Deniz)" tek-tık aksiyonu da var.
    PageType = StandardDialog;
    Caption = 'Hızlı Kullanıcı Atama';
    ApplicationArea = All;
    UsageCategory = Tasks;
    SourceTable = "DOPSWHS App User Role";
    SourceTableTemporary = true;
    DataCaptionExpression = 'WMS Kullanıcı Atama';

    layout
    {
        area(Content)
        {
            group(AssignInputs)
            {
                Caption = 'Atama';
                field(Email; UserEmail)
                {
                    Caption = 'Email / User ID';
                    ApplicationArea = All;
                    ExtendedDatatype = EMail;
                    NotBlank = true;
                    ToolTip = 'Kullanıcının User Principal Name değeri (örn: kaanodabas@dynamicsops.com). M365 invite + BC sync edilmiş olmalı.';
                }
                field(RoleCode; SelectedRole)
                {
                    Caption = 'Rol';
                    ApplicationArea = All;
                    TableRelation = "DOPSWHS App Role".Code where(Active = const(true));
                    ToolTip = 'WMS rol kodu (INV_ADMIN, PICKER, RECEIVER, vb.). AppRoleSeed ile dolu olmalı.';
                }
            }
            group(Suggestions)
            {
                Caption = 'Tek-tık örnekler';
                field(KaanShortcut; KaanLabel)
                {
                    Caption = 'Kaan (pilot)';
                    Editable = false;
                    ToolTip = 'Hızlı doldurmak için: kaanodabas@dynamicsops.com + INV_ADMIN';
                    trigger OnDrillDown()
                    begin
                        UserEmail := 'kaanodabas@dynamicsops.com';
                        SelectedRole := 'INV_ADMIN';
                        CurrPage.Update(false);
                    end;
                }
                field(DenizShortcut; DenizLabel)
                {
                    Caption = 'Deniz (admin)';
                    Editable = false;
                    ToolTip = 'Hızlı doldurmak için: Deniz@dynamicsops.com + INV_ADMIN';
                    trigger OnDrillDown()
                    begin
                        UserEmail := 'Deniz@dynamicsops.com';
                        SelectedRole := 'INV_ADMIN';
                        CurrPage.Update(false);
                    end;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(DoAssign)
            {
                Caption = 'Ata';
                ApplicationArea = All;
                Image = AddAction;
                ToolTip = 'Email + Role kombinasyonunu kaydet. Mevcut atama varsa "zaten var" mesajı; yoksa yeni satır + permission set.';
                trigger OnAction()
                var
                    Provisioner: Codeunit "DOPSWHS Quick User Provision";
                begin
                    Provisioner.AssignWithFeedback(UserEmail, SelectedRole);
                end;
            }
            action(SeedDemo)
            {
                Caption = 'Demo Seed (Kaan + Deniz)';
                ApplicationArea = All;
                Image = SuggestLines;
                ToolTip = 'Pilot kullanıcılarını tek tıkla INV_ADMIN olarak atar. Idempotent — tekrar çalıştırılabilir.';
                trigger OnAction()
                var
                    Provisioner: Codeunit "DOPSWHS Quick User Provision";
                begin
                    Provisioner.ProvisionDemoUsers();
                end;
            }
            action(OpenUserRoleList)
            {
                Caption = 'Atanmışları Gör';
                ApplicationArea = All;
                Image = ViewDetails;
                ToolTip = 'Tüm aktif rol atamalarının listesini açar.';
                RunObject = page "DOPSWHS App User Role List";
            }
        }
    }

    var
        UserEmail: Code[50];
        SelectedRole: Code[20];
        KaanLabel: Label 'kaanodabas@dynamicsops.com INV_ADMIN';
        DenizLabel: Label 'Deniz@dynamicsops.com INV_ADMIN';
}
