pageextension 72305 "DOPSWHS Transfer Order Ext" extends "Transfer Order"
{
    actions
    {
        addlast(Processing)
        {
            group("DOPSWHS Mobile")
            {
                Caption = 'DOPSWHS Mobile';

                action("DOPSWHS Receive via Mobile")
                {
                    ApplicationArea = All;
                    Caption = 'Receive via Mobile';
                    trigger OnAction()
                    var
                        LegacyWI: Codeunit "DOPSWHS Legacy WI Publisher";
                        DocNo: Code[20];
                    begin
                        DocNo := Rec."No.";
                        LegacyWI.FireGetTransferOrder(DocNo);
                        Message('Transfer order %1 is ready for mobile receive-side processing.', Rec."No.");
                    end;
                }

                action("DOPSWHS Start LP")
                {
                    ApplicationArea = All;
                    Caption = 'Start LP';
                    trigger OnAction()
                    begin
                        Message('Open the warehouse receipt created for transfer order %1 to start a receiving LP.', Rec."No.");
                    end;
                }

                action("DOPSWHS Stop LP")
                {
                    ApplicationArea = All;
                    Caption = 'Stop LP';
                    trigger OnAction()
                    begin
                        Message('Open the warehouse receipt created for transfer order %1 to stop and print the LP.', Rec."No.");
                    end;
                }
            }
        }
    }
}
