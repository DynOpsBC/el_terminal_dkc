pageextension 72311 "DOPSWHS Whse Pick Header Ext" extends "Warehouse Pick"
{
    layout
    {
        addlast(General)
        {
            field("DOPSWHS Assigned User"; Rec."Assigned User ID")
            {
                ApplicationArea = All;
                Caption = 'Assigned User (WMS)';
                ToolTip = 'Specifies the WMS operator assigned to this pick. Use the "Assign to WMS Operator" action to change it — direct entry is disabled because the underlying field validates against Warehouse Employee, which silently cleared operators that have no such record.';
                // Alan SALT-OKUNUR. Sebebi: "Assigned User ID" alanının
                // TableRelation'ı Warehouse Employee'dir. WMS operatörleri
                // (DOPSWHS Local User) her zaman Warehouse Employee değil;
                // kullanıcı elle yazınca standart Validate atamayı sessizce geri
                // alıyor, alan boşalıyordu. Atama "Assign to WMS Operator"
                // aksiyonundan yapılır; orada değer Validate tetiklemeden
                // doğrudan yazılır (bkz. PickMgmt.ReassignPick).
                Editable = false;
                DrillDown = false;
            }
            field("DOPSWHS Vehicle No."; Rec."DOPSWHS Vehicle No.")
            {
                ApplicationArea = All;
                Caption = 'Vehicle No.';
                ToolTip = 'Specifies the vehicle (forklift/pallet truck) assigned to this pick. Entered by the desk supervisor; shown read-only on the handheld.';
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
                action("DOPSWHS Start Shipping LP")
                {
                    ApplicationArea = All;
                    Caption = 'Start Shipping LP';
                    trigger OnAction()
                    var
                        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
                    begin
                        Message('Started LP %1.', PickMgmt.StartShippingLP(Rec, 'PALLET-EUR'));
                    end;
                }
                action("DOPSWHS Stop Shipping LP")
                {
                    ApplicationArea = All;
                    Caption = 'Stop Shipping LP';
                    trigger OnAction()
                    var
                        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
                        LP: Record "DOPSWHS LP Header";
                        LpNo: Code[20];
                    begin
                        if Page.RunModal(Page::"DOPSWHS LP List", LP) <> Action::LookupOK then
                            exit;
                        LpNo := LP."No.";
                        Message('SSCC %1.', PickMgmt.StopShippingLP(Rec, LpNo, true));
                    end;
                }
                action("DOPSWHS Reassign to User")
                {
                    ApplicationArea = All;
                    Caption = 'Assign to WMS Operator';
                    Image = UserSetup;
                    Promoted = true;
                    PromotedCategory = Process;
                    ToolTip = 'Assigns this pick to a WMS operator. The list shows local WMS users (the accounts operators sign in with on the handheld), not Business Central users. This is the supervisor override: a pick already held by another operator can only be handed over here — on the handheld a second operator is refused.';
                    trigger OnAction()
                    var
                        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
                        LocalUser: Record "DOPSWHS Local User";
                    begin
                        // Terminal operatörleri BC kullanıcısı değil, "DOPSWHS
                        // Local User" kaydıdır. Eskiden BC User Lookup açılıyordu;
                        // seçilen BC kullanıcısı terminaldeki operatörle eşleşmediği
                        // için atama terminalde görünmüyordu.
                        LocalUser.SetRange(Disabled, false);
                        if Page.RunModal(Page::"DOPSWHS Local User List", LocalUser) <> Action::LookupOK then
                            exit;

                        // Belge başkasındaysa bu bir ZORLA DEVİR: operatör toplamanın
                        // ortasında olabilir, sorumlu bilerek onaylasın.
                        if (Rec."Assigned User ID" <> '') and (Rec."Assigned User ID" <> LocalUser.Username) then
                            if not Confirm(TakeOverQst, false, PickMgmt.OperatorLabel(Rec."Assigned User ID"), LocalUser."Display Name") then
                                exit;

                        PickMgmt.ReassignPick(Rec, LocalUser.Username, AssignedFromCardLbl);
                        CurrPage.Update(false);
                        Message(AssignedMsg, Rec."No.", LocalUser."Display Name");
                    end;
                }
                action("DOPSWHS Clear Assignment")
                {
                    ApplicationArea = All;
                    Caption = 'Clear Assignment';
                    Image = UnApply;
                    ToolTip = 'Clears the operator assignment. The pick becomes claimable again on the handheld: the first operator who takes it owns it.';
                    trigger OnAction()
                    var
                        PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
                    begin
                        if Rec."Assigned User ID" = '' then
                            exit;
                        // Atama kaldırılınca belge terminalde herkese açılır;
                        // toplamaya başlamış operatörün işi yarıda kalabilir.
                        if not Confirm(ClearAssignmentQst, false, PickMgmt.OperatorLabel(Rec."Assigned User ID")) then
                            exit;
                        PickMgmt.ReleasePick(Rec, ClearedFromCardLbl);
                        CurrPage.Update(false);
                    end;
                }
                action("DOPSWHS Mark Short")
                {
                    ApplicationArea = All;
                    Caption = 'Mark Short';
                    trigger OnAction()
                    begin
                        Page.Run(Page::"DOPSWHS Short Pick Reason List");
                    end;
                }
            }
        }
    }

    var
        TakeOverQst: Label 'Bu toplama %1 kullanıcısında. %2 kullanıcısına devredilsin mi?', Comment = '%1 = mevcut operatör, %2 = yeni operatör';
        ClearAssignmentQst: Label '%1 kullanıcısının ataması kaldırılsın mı? Toplama terminalde yeniden herkese açılır.', Comment = '%1 = mevcut operatör';
        AssignedMsg: Label 'Toplama %1, %2 kullanıcısına atandı.', Comment = '%1 = Toplama no., %2 = operatör';
        AssignedFromCardLbl: Label 'Toplama belgesi kartından atandı.';
        ClearedFromCardLbl: Label 'Toplama belgesi kartından atama kaldırıldı.';
}
