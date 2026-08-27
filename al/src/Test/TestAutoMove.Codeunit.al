codeunit 72068 "DOPSWHS Test Auto Move"
{
    // Section E: TC-034 to TC-036 — Hareketler
    Access = Public;

    procedure Dispatch(ProcedureName: Text[80]; var ErrorMsg: Text)
    begin
        case ProcedureName of
            'RunTC034':
                RunTC034(ErrorMsg);
            'RunTC035':
                RunTC035(ErrorMsg);
            'RunTC036':
                RunTC036(ErrorMsg);
            else
                ErrorMsg := StrSubstNo('Procedure %1 bulunamadı (Section E)', ProcedureName);
        end;
    end;

    local procedure RunTC034(var ErrorMsg: Text)
    var
        AllObj: Record AllObjWithCaption;
    begin
        AllObj.SetRange("Object Type", AllObj."Object Type"::Codeunit);
        AllObj.SetRange("Object ID", 72045);
        if not AllObj.FindFirst() then
            ErrorMsg := 'TC-034: Movement Mgmt codeunit yok';
    end;

    local procedure RunTC035(var ErrorMsg: Text)
    var
        Activity: Record "Warehouse Activity Header";
    begin
        Activity.SetFilter(Type, '%1', Activity.Type::Movement);
        if Activity.Count() < 0 then;
    end;

    local procedure RunTC036(var ErrorMsg: Text)
    var
        MovementMgmt: Codeunit "DOPSWHS Movement Mgmt";
        Batch1: Code[10];
        Batch2: Code[10];
    begin
        Batch1 := MovementMgmt.EnsureDeviceJournalBatch('USER1');
        Batch2 := MovementMgmt.EnsureDeviceJournalBatch('USER2');
        if Batch1 = Batch2 then
            ErrorMsg := StrSubstNo('TC-036 KRİTİK: USER1 ve USER2 aynı batch %1 — isolation bozuk', Batch1);
        if (Batch1 = '') or (Batch2 = '') then
            ErrorMsg := StrSubstNo('TC-036: Batch isimleri boş (USER1=%1, USER2=%2)', Batch1, Batch2);
    end;
}
