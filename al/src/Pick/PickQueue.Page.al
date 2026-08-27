page 72083 "DOPSWHS Pick Queue"
{
    PageType = ListPart;
    SourceTable = "Warehouse Activity Header";
    SourceTableView = where(Type = const(Pick));
    Caption = 'Toplama Kuyruğu';
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Picks)
            {
                field("Pick No."; Rec."No.") { ApplicationArea = All; Caption = 'Toplama No.'; }
                field("Source No."; SourceNo) { ApplicationArea = All; Caption = 'Kaynak No.'; }
                field("Assigned User"; Rec."Assigned User ID") { ApplicationArea = All; Caption = 'Atanan Toplayıcı'; }
                field(Lines; LineCount) { ApplicationArea = All; Caption = 'Satır'; }
                field("% Complete"; PercentComplete) { ApplicationArea = All; Caption = 'Tamamlanma %'; ExtendedDatatype = Ratio; }
                field(Created; Rec."Assignment Date") { ApplicationArea = All; Caption = 'Oluşturulma'; }
                field("Due Date"; DueDate) { ApplicationArea = All; Caption = 'Termin Tarihi'; }
            }
            usercontrol(PickBoard; "DOPSWHS Pick Board")
            {
                ApplicationArea = All;
                trigger ControlReady()
                begin
                    CurrPage.PickBoard.SetLocale(Format(GlobalLanguage()));
                    CurrPage.PickBoard.SetData(BuildBoardJson());
                end;

                trigger Reassign(PickNo: Code[20]; UserId: Code[50])
                var
                    Pick: Record "Warehouse Activity Header";
                    PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
                begin
                    if not Pick.Get(Pick.Type::Pick, PickNo) then
                        Error(PickNotFoundErr, PickNo);
                    if UserId = '' then
                        PickMgmt.ReleasePick(Pick, BoardReleaseReasonLbl)
                    else
                        PickMgmt.ReassignPick(Pick, UserId, BoardAssignReasonLbl);
                    CurrPage.Update(false);
                end;

                trigger RequestRefresh()
                begin
                    CurrPage.PickBoard.SetData(BuildBoardJson());
                end;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action("Manual Reassign")
            {
                ApplicationArea = All;
                Caption = 'Toplayıcı Ata / Değiştir';
                trigger OnAction()
                var
                    PickMgmt: Codeunit "DOPSWHS Pick Mgmt";
                    LocalUser: Record "DOPSWHS Local User";
                begin
                    LocalUser.SetRange(Disabled, false);
                    if Page.RunModal(Page::"DOPSWHS Local User List", LocalUser) <> Action::LookupOK then
                        exit;

                    if (Rec."Assigned User ID" <> '') and (Rec."Assigned User ID" <> LocalUser.Username) then
                        if not Confirm(TakeOverQst, false, PickMgmt.OperatorLabel(Rec."Assigned User ID"), LocalUser."Display Name") then
                            exit;

                    PickMgmt.ReassignPick(Rec, LocalUser.Username, ManualQueueReasonLbl);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        FillCalculatedFields();
    end;

    var
        SourceNo: Code[20];
        DueDate: Date;
        LineCount: Integer;
        PercentComplete: Integer;
        TakeOverQst: Label 'Bu toplama %1 kullanıcısında. %2 kullanıcısına devredilsin mi?', Comment = '%1 = mevcut operatör, %2 = yeni operatör';
        ManualQueueReasonLbl: Label 'Toplama kuyruğundan atandı.';
        BoardAssignReasonLbl: Label 'Toplama atama panosundan atandı.';
        BoardReleaseReasonLbl: Label 'Toplama atama panosundan boşa alındı.';
        PickNotFoundErr: Label 'Toplama belgesi %1 artık bulunamıyor. Kuyruğu yenileyip tekrar deneyin.', Comment = '%1 = toplama belge numarası';

    local procedure FillCalculatedFields()
    var
        PickLine: Record "Warehouse Activity Line";
        TotalQty: Decimal;
        HandledQty: Decimal;
    begin
        Clear(SourceNo);
        Clear(DueDate);
        Clear(LineCount);
        Clear(PercentComplete);
        PickLine.SetRange("Activity Type", Rec.Type);
        PickLine.SetRange("No.", Rec."No.");
        PickLine.SetRange("Action Type", PickLine."Action Type"::Take);
        if PickLine.FindSet() then
            repeat
                if SourceNo = '' then begin
                    SourceNo := PickLine."Source No.";
                    DueDate := PickLine."Due Date";
                end;
                LineCount += 1;
                TotalQty += PickLine.Quantity;
                HandledQty += PickLine."Qty. to Handle";
            until PickLine.Next() = 0;
        if TotalQty > 0 then begin
            PercentComplete := Round(HandledQty / TotalQty * 100, 1);
            if PercentComplete > 100 then
                PercentComplete := 100;
        end;
    end;

    local procedure BuildBoardJson(): Text
    var
        BoardData: Codeunit "DOPSWHS Board Data";
    begin
        exit(BoardData.BuildPickBoardJson());
    end;
}
