page 72274 "DOPSWHS App Role List"
{
    PageType = List;
    SourceTable = "DOPSWHS App Role";
    Caption = 'WMS App Roles';
    ApplicationArea = All;
    UsageCategory = Lists;
    CardPageId = "DOPSWHS App Role Card";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Code"; Rec.Code) { ApplicationArea = All; }
                field("Description"; Rec.Description) { ApplicationArea = All; }
                field("Active"; Rec.Active) { ApplicationArea = All; }
                field("Is System"; Rec."Is System") { ApplicationArea = All; }
                field("Sort Order"; Rec."Sort Order") { ApplicationArea = All; }
                field("Member Count"; Rec."Member Count") { ApplicationArea = All; }
                field("Rule Count"; Rec."Rule Count") { ApplicationArea = All; }
                field("Hide Test Tools"; Rec."Hide Test Tools") { ApplicationArea = All; Visible = false; }
                field("Hide Admin Tools"; Rec."Hide Admin Tools") { ApplicationArea = All; Visible = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SeedSystemRoles)
            {
                Caption = 'Seed System Roles';
                Image = SuggestLines;
                ApplicationArea = All;
                ToolTip = 'Idempotent system role seed (OPERATOR / PICKER / RECEIVER / SHIPPER / COUNTER / QUALITY / INV_ADMIN).';

                trigger OnAction()
                var
                    Seed: Codeunit "DOPSWHS App Role Seed";
                begin
                    Seed.Seed();
                    CurrPage.Update();
                    Message('System roles seeded.');
                end;
            }
        }
    }
}
