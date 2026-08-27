page 72288 "DOPSWHS App User Role List"
{
    // Tüm WMS rol atamalarını gösteren ana liste. AppUserRoles (ListPart
    // 72277) bir user kartının içinde tek-user görünümü içindi; bu page
    // tüm system için "kim hangi role sahip" tablo görünümü.
    //
    // Role Center " Atanmış Kullanıcılar" tıklandığında veya search
    // "App User Roles" ile açılır.
    PageType = List;
    SourceTable = "DOPSWHS App User Role";
    Caption = 'WMS Kullanıcı Rolleri';
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = true;
    CardPageId = "DOPSWHS Quick User Assign";
    InsertAllowed = true;
    ModifyAllowed = true;
    DeleteAllowed = true;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("User ID"; Rec."User ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Kullanıcı User Principal Name (UPN).';
                }
                field("Role Code"; Rec."Role Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'WMS rolü kodu.';
                }
                field("Priority"; Rec.Priority)
                {
                    ApplicationArea = All;
                    ToolTip = 'Birden fazla rol için sıralama (düşük öncelikli).';
                }
                field("Disabled"; Rec.Disabled)
                {
                    ApplicationArea = All;
                    ToolTip = 'Geçici devre dışı (silmeden role-erişim kes).';
                }
                field("Assigned DateTime"; Rec."Assigned DateTime")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Atamayı yapan tarih/saat.';
                }
                field("Assigned By"; Rec."Assigned By")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Atamayı yapan admin user.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(QuickAssign)
            {
                Caption = 'Hızlı Atama';
                ApplicationArea = All;
                Image = New;
                ToolTip = 'Yeni kullanıcı atamak için Quick User Assign kartını aç.';
                RunObject = page "DOPSWHS Quick User Assign";
            }
            action(SeedDemo)
            {
                Caption = 'Demo Seed';
                ApplicationArea = All;
                Image = SuggestLines;
                ToolTip = 'Pilot kullanıcı setini (Kaan + Deniz INV_ADMIN) idempotent ata.';
                trigger OnAction()
                var
                    Provisioner: Codeunit "DOPSWHS Quick User Provision";
                begin
                    Provisioner.ProvisionDemoUsers();
                end;
            }
            action(GetUsersFromM365)
            {
                Caption = 'M365 Senkronizasyonu';
                ApplicationArea = All;
                Image = Refresh;
                ToolTip = 'BC standart "Users" sayfasını açar; oradan M365 senkronu yapılır.';
                RunObject = page Users;
            }
            action(RoleCatalog)
            {
                Caption = 'Rol Kataloğu';
                ApplicationArea = All;
                Image = SetupList;
                ToolTip = 'Mevcut WMS rollerini gösterir (INV_ADMIN, PICKER, RECEIVER, vb.).';
                RunObject = page "DOPSWHS App Role List";
            }
        }
    }
}
