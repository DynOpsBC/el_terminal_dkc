page 72344 "DOPSWHS Pack Station Solo"
{
    // ELOG "Solo Package Worksheet" muadili: bir sepet = bir sipariş.
    // Mod sabit Solo. İş mantığı codeunit 72334'te (ProcessScan /
    // GetSessionDisplay); bu sayfa yalnızca UI kabuğudur. Düzen ELOG
    // worksheet'iyle hizalı: DETAILS (Order/Location/Unpacked...) +
    // SCANNING (Scan Here / Current Tote / Current Item / Last Scan).
    PageType = Card;
    Caption = 'Solo Package Worksheet';
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "DOPSWHS Pack Session";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(Details)
            {
                Caption = 'Details';
                field(OrderNo; CurrentOrderNo) { Caption = 'Order'; ApplicationArea = All; Editable = false; }
                field(LocationCode; Rec."Location Code") { Caption = 'Location'; ApplicationArea = All; Editable = false; }
                field(PickNo; Rec."Pick No.") { Caption = 'Pick No.'; ApplicationArea = All; Editable = false; }
                field(OrdersProgress; StrSubstNo('%1 / %2', Rec."Orders Completed", Rec."Orders Total"))
                {
                    Caption = 'Orders Completed';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(UnpackedQty; UnpackedQty) { Caption = 'Unpacked Quantity'; ApplicationArea = All; Editable = false; }
                field(UnpackedLines; UnpackedLines) { Caption = 'Unpacked Lines'; ApplicationArea = All; Editable = false; }
                field(SessionStatus; Rec.Status) { Caption = 'Status'; ApplicationArea = All; Editable = false; }
            }
            group(Scanning)
            {
                Caption = 'Scanning';
                InstructionalText = 'Scan a license plate to pack';
                field(ScanInput; ScanInput)
                {
                    Caption = 'Scan Here';
                    ApplicationArea = All;

                    trigger OnValidate()
                    begin
                        HandleScan(ScanInput);
                    end;
                }
                field(NextStep; NextStep) { Caption = 'Next Step'; ApplicationArea = All; Editable = false; }
                field(ToteLpNo; Rec."Tote LP No.") { Caption = 'Current Tote'; ApplicationArea = All; Editable = false; }
                field(CurrentPackage; Rec."Box LP No.") { Caption = 'Current Package'; ApplicationArea = All; Editable = false; }
                field(CurrentItem; CurrentItem) { Caption = 'Current Item'; ApplicationArea = All; Editable = false; }
                field(LastScan; LastScan) { Caption = 'Last Scan'; ApplicationArea = All; Editable = false; }
                field(LastPackedOrder; LastPackedOrder) { Caption = 'Last Packed Order'; ApplicationArea = All; Editable = false; }
            }
            part(Lines; "DOPSWHS Pack Session Subform")
            {
                Caption = 'Packed Lines';
                ApplicationArea = All;
                SubPageLink = "Session Entry No." = field("Entry No.");
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(PrintLastPackedOrder)
            {
                Caption = 'Print Last Packed Order';
                ApplicationArea = All;
                Image = Print;

                trigger OnAction()
                var
                    PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
                begin
                    if LastPackedOrder <> '' then
                        PackMgmt.ReprintOrderReceipt(CopyStr(LastPackedOrder, 1, 20));
                end;
            }
            action(CancelSession)
            {
                Caption = 'Cancel Session';
                ApplicationArea = All;
                Image = Cancel;
                Enabled = Rec.Status = Rec.Status::Open;

                trigger OnAction()
                var
                    PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
                begin
                    if Rec."Entry No." = 0 then
                        exit;
                    PackMgmt.CancelSession(Rec."Entry No.");
                    CurrPage.Update(false);
                end;
            }
            action(Refresh)
            {
                Caption = 'Refresh';
                ApplicationArea = All;
                Image = Refresh;

                trigger OnAction()
                begin
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(Sessions)
            {
                Caption = 'Pack Sessions';
                ApplicationArea = All;
                Image = History;
                RunObject = page "DOPSWHS Pack Session List";
            }
        }
    }

    trigger OnOpenPage()
    begin
        if Rec."Entry No." <> 0 then
            exit;
        Rec.SetRange("Created By User", CopyStr(UserId(), 1, 50));
        Rec.SetRange(Mode, Rec.Mode::Solo);
        if Rec.FindLast() then;
    end;

    trigger OnAfterGetRecord()
    begin
        RefreshDisplay();
    end;

    local procedure HandleScan(Value: Text)
    var
        PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
        SessionId: Integer;
        Completed: Text;
        WasItemScan: Boolean;
    begin
        if Value.Trim() = '' then
            exit;
        LastScan := CopyStr(Value.Trim(), 1, MaxStrLen(LastScan));
        ScanInput := '';

        WasItemScan := (Rec."Entry No." <> 0) and (Rec.Status = Rec.Status::Open) and
            (PackMgmt.BoxNeededOrder(Rec."Entry No.") = '');

        SessionId := Rec."Entry No.";
        Completed := PackMgmt.ProcessScan(SessionId, Enum::"DOPSWHS Pack Mode"::Solo, LastScan);
        if WasItemScan then
            CurrentItem := LastScan;
        if Completed <> '' then
            LastPackedOrder := CopyStr(Completed, 1, MaxStrLen(LastPackedOrder));

        if SessionId <> 0 then
            Rec.Get(SessionId);
        RefreshDisplay();
        CurrPage.Update(false);
    end;

    local procedure RefreshDisplay()
    var
        PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
    begin
        PackMgmt.GetSessionDisplay(Rec."Entry No.", UnpackedQty, UnpackedLines, CurrentOrderNo, NextStep);
    end;

    var
        ScanInput: Text;
        LastScan: Text[50];
        CurrentItem: Text[50];
        LastPackedOrder: Text[100];
        CurrentOrderNo: Code[20];
        NextStep: Text;
        UnpackedQty: Decimal;
        UnpackedLines: Integer;
}
