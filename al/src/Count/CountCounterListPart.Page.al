page 72482 "DOPSWHS Count Counter Part"
{
    Caption = 'Count Counters';
    PageType = ListPart;
    SourceTable = "DOPSWHS Count Counter";
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Counters)
            {
                field("Counter Slot"; Rec."Counter Slot") { ApplicationArea = All; }
                field("User ID"; Rec."User ID")
                {
                    ApplicationArea = All;
                    Caption = 'User ID';
                    Lookup = true;
                    ToolTip = 'Bu sayıcı slotuna atanacak etkin terminal operatörünü Local WMS Users listesinden seçin.';

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        LocalUser: Record "DOPSWHS Local User";
                    begin
                        LocalUser.SetRange(Disabled, false);
                        if Page.RunModal(Page::"DOPSWHS Local User List", LocalUser) <> Action::LookupOK then
                            exit(true);

                        Rec.Validate("User ID", LocalUser.Username);
                        CurrPage.Update(false);
                        exit(true);
                    end;
                }
                field("Assigned DateTime"; Rec."Assigned DateTime")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
            }
        }
    }
}
