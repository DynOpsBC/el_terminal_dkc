pageextension 72308 "DOPSWHS Prod Order Ext" extends "Released Production Order"
{
    layout
    {
        addlast(FactBoxes)
        {
            part("DOPSWHS Production LPs"; "DOPSWHS Prod LP Factbox")
            {
                ApplicationArea = All;
                Caption = 'Mobile Production LPs';
                SubPageLink = "Assigned Document No." = field("No.");
            }
        }
    }

    actions
    {
        addlast(Processing)
        {
            group("DOPSWHS Mobile")
            {
                Caption = 'DOPSWHS Mobile';

                action("DOPSWHS Mobile Consume")
                {
                    ApplicationArea = All;
                    Caption = 'Mobile Consume';
                    Image = ConsumptionJournal;

                    trigger OnAction()
                    begin
                        Message('Use the DOPSWHS mobile app Consume flow for production order %1.', Rec."No.");
                    end;
                }
                action("DOPSWHS Mobile Output")
                {
                    ApplicationArea = All;
                    Caption = 'Mobile Output';
                    Image = OutputJournal;

                    trigger OnAction()
                    begin
                        Message('Use the DOPSWHS mobile app Output flow for production order %1.', Rec."No.");
                    end;
                }
            }
        }
    }
}
