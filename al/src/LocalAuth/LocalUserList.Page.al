page 72285 "DOPSWHS Local User List"
{
    PageType = List;
    SourceTable = "DOPSWHS Local User";
    Caption = 'Local WMS Users (e-postasız operatörler)';
    ApplicationArea = All;
    UsageCategory = Lists;
    CardPageId = "DOPSWHS Local User Card";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Username"; Rec.Username) { ApplicationArea = All; }
                field("Display Name"; Rec."Display Name") { ApplicationArea = All; }
                field("Default Location Code"; Rec."Default Location Code") { ApplicationArea = All; }
                field("Disabled"; Rec.Disabled) { ApplicationArea = All; }
                field("Last Login DateTime"; Rec."Last Login DateTime") { ApplicationArea = All; }
                field("Failed Login Count"; Rec."Failed Login Count") { ApplicationArea = All; }
                field("Created DateTime"; Rec."Created DateTime") { ApplicationArea = All; Visible = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SeedDemo)
            {
                Caption = 'Seed Demo Operators';
                Image = SuggestLines;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = '4 demo yerel kullanıcı oluşturur (wms-op-01, wms-op-02, wms-receiver, wms-shipper) varsayılan şifre "wms1234" ile.';

                trigger OnAction()
                var
                    AuthMgt: Codeunit "DOPSWHS Local Auth Mgmt";
                    Setup: Record "DOPSWHS Setup";
                    DefaultLoc: Code[10];
                begin
                    if Setup.Get('') then DefaultLoc := Setup."Default Location Code";
                    AuthMgt.Register('wms-op-01',    'Picker Operator 01',   'wms1234', DefaultLoc, '');
                    AuthMgt.Register('wms-op-02',    'Picker Operator 02',   'wms1234', DefaultLoc, '');
                    AuthMgt.Register('wms-receiver', 'Receiving Operator',   'wms1234', DefaultLoc, '');
                    AuthMgt.Register('wms-shipper',  'Shipping Operator',    'wms1234', DefaultLoc, '');
                    CurrPage.Update();
                    Message('4 demo yerel kullanıcı oluşturuldu (şifre: wms1234). Roller için "WMS App Roles" sayfasında her birine PICKER/RECEIVER/SHIPPER atayın.');
                end;
            }
        }
    }
}
