page 72219 "DOPSWHS Ops Console Page"
{
    PageType = Card;
    Caption = 'WMS Ops Console';
    ApplicationArea = All;
    UsageCategory = Tasks; // "Tell me" içinde aranabilir

    layout
    {
        area(Content)
        {
            usercontrol(Console; "DOPSWHS Ops Console")
            {
                ApplicationArea = All;

                trigger ControlReady()
                begin
                    CurrPage.Console.SetLocale(Format(GlobalLanguage()));
                    CurrPage.Console.SetData(BoardData.BuildOpsConsoleJson());
                end;

                trigger AssignDoc(DocType: Text; DocNo: Code[20]; UserId: Code[50])
                begin
                    BoardData.AssignDoc(DocType, DocNo, UserId);
                    CurrPage.Console.SetData(BoardData.BuildOpsConsoleJson());
                end;

                trigger RequestRefresh()
                begin
                    CurrPage.Console.SetData(BoardData.BuildOpsConsoleJson());
                end;

                trigger CreateMultiPick(OrderNosCsv: Text; UserId: Code[50])
                begin
                    CurrPage.Console.NotifyResult(BoardData.CreateMultiPick(OrderNosCsv, UserId));
                    CurrPage.Console.SetData(BoardData.BuildOpsConsoleJson());
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
                    CurrPage.Console.SetData(BoardData.BuildOpsConsoleJson());
                end;
            }
        }
    }

    var
        BoardData: Codeunit "DOPSWHS Board Data";
}
