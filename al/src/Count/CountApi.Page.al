page 72221 "DOPSWHS Count API"
{
    PageType = API;
    APIPublisher = 'dynops';
    APIGroup = 'warehouse';
    APIVersion = 'v2.0';
    EntityName = 'countSheet';
    EntitySetName = 'countSheets';
    SourceTable = "DOPSWHS Count Sheet Header";
    DelayedInsert = true;
    ModifyAllowed = false;
    DeleteAllowed = false;
    ODataKeyFields = "No.";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(no; Rec."No.") { Caption = 'no'; }
                field(locationCode; Rec."Location Code") { Caption = 'locationCode'; }
                field(mode; Rec.Mode) { Caption = 'mode'; }
                field(status; Rec.Status) { Caption = 'status'; }
                field(createdDateTime; Rec."Created DateTime") { Caption = 'createdDateTime'; }
                field(v2ScanMode; Rec."V2 Scan Mode") { Caption = 'v2ScanMode'; }
                field(counter1UserId; Counter1UserId) { Caption = 'counter1UserId'; Editable = false; }
                field(counter2UserId; Counter2UserId) { Caption = 'counter2UserId'; Editable = false; }
                field(counter3UserId; Counter3UserId) { Caption = 'counter3UserId'; Editable = false; }
                part(lines; "DOPSWHS Count Sheet Line API")
                {
                    Caption = 'lines';
                    EntityName = 'countSheetLine';
                    EntitySetName = 'countSheetLines';
                    SubPageLink = "Sheet No." = field("No.");
                }
            }
        }
    }

    trigger OnOpenPage()
    var
        FilterMgmt: Codeunit "DOPSWHS App Role Filter Mgmt";
        RecRef: RecordRef;
    begin
        RecRef.GetTable(Rec);
        FilterMgmt.ApplyForCurrentUser(RecRef, Enum::"DOPSWHS App Filter Entity"::CountSheet);
        RecRef.SetTable(Rec);
    end;

    trigger OnAfterGetRecord()
    var
        Counter: Record "DOPSWHS Count Counter";
    begin
        Clear(Counter1UserId);
        Clear(Counter2UserId);
        Clear(Counter3UserId);
        Counter.SetRange("Sheet No.", Rec."No.");
        if Counter.FindSet() then
            repeat
                case Counter."Counter Slot" of
                    1:
                        Counter1UserId := Counter."User ID";
                    2:
                        Counter2UserId := Counter."User ID";
                    3:
                        Counter3UserId := Counter."User ID";
                end;
            until Counter.Next() = 0;
    end;

    [ServiceEnabled]
    procedure generateLines(): Integer
    var
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
    begin
        exit(CountMgmt.GenerateLines(Rec."No."));
    end;

    [ServiceEnabled]
    procedure addLine(itemNo: Code[20]; variantCode: Code[10]; binCode: Code[20]): Integer
    var
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
    begin
        exit(CountMgmt.AddLine(Rec."No.", itemNo, variantCode, binCode));
    end;

    [ServiceEnabled]
    procedure attachLpToBin(lpNo: Code[20]; binCode: Code[20]): Integer
    var
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
    begin
        exit(CountMgmt.AttachLpToBin(Rec."No.", lpNo, binCode));
    end;

    [ServiceEnabled]
    procedure addUnexpectedItem(itemNo: Code[20]; variantCode: Code[10]; binCode: Code[20]; unitOfMeasureCode: Code[10]; lotNo: Code[50]; serialNo: Code[50]; qty: Decimal; counterSlot: Integer): Integer
    var
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
    begin
        exit(CountMgmt.AddUnexpectedItem(
            Rec."No.", itemNo, variantCode, binCode, unitOfMeasureCode,
            lotNo, serialNo, qty, counterSlot));
    end;

    [ServiceEnabled]
    procedure addUnexpectedLp(lpNo: Code[20]; binCode: Code[20]; counterSlot: Integer): Integer
    var
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
    begin
        exit(CountMgmt.AddUnexpectedLp(Rec."No.", lpNo, binCode, counterSlot));
    end;

    [ServiceEnabled]
    procedure prepareV2()
    var
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
    begin
        CountMgmt.PrepareV2(Rec."No.");
    end;

    [ServiceEnabled]
    procedure scanV2Label(scanId: Guid; itemNo: Code[20]; variantCode: Code[10]; binCode: Code[20]; unitOfMeasureCode: Code[10]; lotNo: Code[50]; serialNo: Code[50]; qty: Decimal; counterSlot: Integer): Integer
    var
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
    begin
        exit(CountMgmt.ScanV2Label(
            Rec."No.", scanId, itemNo, variantCode, binCode, unitOfMeasureCode,
            lotNo, serialNo, qty, counterSlot));
    end;

    [ServiceEnabled]
    procedure undoV2Scan(scanId: Guid): Integer
    var
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
    begin
        exit(CountMgmt.UndoV2Scan(Rec."No.", scanId));
    end;

    [ServiceEnabled]
    procedure startRecount()
    var
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
    begin
        CountMgmt.StartRecount(Rec."No.");
    end;

    [ServiceEnabled]
    procedure postSheet()
    var
        CountMgmt: Codeunit "DOPSWHS Count Mgmt";
    begin
        CountMgmt.PostSheet(Rec."No.");
    end;


    var
        Counter1UserId: Code[50];
        Counter2UserId: Code[50];
        Counter3UserId: Code[50];
}
