page 72098 "DOPSWHS Pick Board Page"
{
    PageType = Card;
    Caption = 'Toplama Atama Panosu';
    ApplicationArea = All;
    UsageCategory = Tasks;  // searchable in "Tell me"

    layout
    {
        area(Content)
        {
            usercontrol(Board; "DOPSWHS Pick Board")
            {
                ApplicationArea = All;

                trigger ControlReady()
                begin
                    CurrPage.Board.SetLocale(Format(GlobalLanguage()));
                    CurrPage.Board.SetData(BoardData.BuildPickBoardJson());
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
                    CurrPage.Board.SetData(BoardData.BuildPickBoardJson());
                end;

                trigger RequestRefresh()
                begin
                    CurrPage.Board.SetData(BoardData.BuildPickBoardJson());
                end;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Refresh)
            {
                ApplicationArea = All;
                Caption = 'Yenile';
                Image = Refresh;
                trigger OnAction()
                begin
                    CurrPage.Board.SetData(BoardData.BuildPickBoardJson());
                end;
            }
        }
    }

    var
        BoardData: Codeunit "DOPSWHS Board Data";
        PickNotFoundErr: Label 'Toplama belgesi %1 artık bulunamıyor. Panoyu yenileyip tekrar deneyin.', Comment = '%1 = toplama belge numarası';
        BoardAssignReasonLbl: Label 'Toplama atama panosundan atandı.';
        BoardReleaseReasonLbl: Label 'Toplama atama panosundan boşa alındı.';
}
