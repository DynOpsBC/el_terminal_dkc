page 72099 "DOPSWHS LP Browser Page"
{
    PageType = Card;
    Caption = 'LP Browser';
    ApplicationArea = All;
    UsageCategory = Tasks;  // searchable in "Tell me"

    layout
    {
        area(Content)
        {
            usercontrol(Tree; "DOPSWHS LP Browser")
            {
                ApplicationArea = All;

                trigger ControlReady()
                begin
                    CurrPage.Tree.SetLocale(Format(GlobalLanguage()));
                    CurrPage.Tree.SetData(BoardData.BuildLpTreeJson());
                end;

                trigger NestLp(childLpNo: Text; parentLpNo: Text)
                begin
                    BoardData.NestLp(CopyStr(childLpNo, 1, 20), CopyStr(parentLpNo, 1, 20));
                    CurrPage.Tree.SetData(BoardData.BuildLpTreeJson());
                end;

                trigger UnnestLp(childLpNo: Text)
                var
                    ChildLP: Record "DOPSWHS LP Header";
                    NestMgr: Codeunit "DOPSWHS LP Nest Manager";
                begin
                    if ChildLP.Get(CopyStr(childLpNo, 1, 20)) then
                        NestMgr.Unnest(ChildLP);
                    CurrPage.Tree.SetData(BoardData.BuildLpTreeJson());
                end;

                trigger PrintLabel(lpNo: Text; printerId: Text)
                begin
                    BoardData.PrintLpLabel(CopyStr(lpNo, 1, 20), CopyStr(printerId, 1, 50));
                end;

                trigger MoveLpToBin(lpNo: Text; binCode: Text)
                begin
                    BoardData.MoveLpToBin(CopyStr(lpNo, 1, 20), CopyStr(binCode, 1, 20));
                    CurrPage.Tree.SetData(BoardData.BuildLpTreeJson());
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
                Caption = 'Refresh';
                Image = Refresh;
                trigger OnAction()
                begin
                    CurrPage.Tree.SetData(BoardData.BuildLpTreeJson());
                end;
            }
        }
    }

    var
        BoardData: Codeunit "DOPSWHS Board Data";
}
