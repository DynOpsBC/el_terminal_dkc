pageextension 72309 "DOPSWHS Assembly Header Ext" extends "Assembly Order"
{
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
                    Image = Components;

                    trigger OnAction()
                    begin
                        Message('Use the DOPSWHS mobile app Assembly flow to consume components for assembly order %1.', Rec."No.");
                    end;
                }
                action("DOPSWHS Mobile Post")
                {
                    ApplicationArea = All;
                    Caption = 'Mobile Post';
                    Image = PostDocument;

                    trigger OnAction()
                    var
                        AssemblyMgmt: Codeunit "DOPSWHS Assembly Mgmt";
                    begin
                        AssemblyMgmt.PostAssembly(Rec);
                    end;
                }
            }
        }
    }
}
