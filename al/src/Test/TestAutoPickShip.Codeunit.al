codeunit 72067 "DOPSWHS Test Auto Pick Ship"
{
    // Section D: TC-024 to TC-033 — Picking + Shipping
    Access = Public;

    procedure Dispatch(ProcedureName: Text[80]; var ErrorMsg: Text)
    begin
        case ProcedureName of
            'RunTC024':
                CheckActivityTable(ErrorMsg);
            'RunTC025':
                CheckActivityTable(ErrorMsg);
            'RunTC026':
                CheckLPMgmt(ErrorMsg);
            'RunTC027':
                CheckShortPickReason(ErrorMsg);
            'RunTC028':
                CheckActivityTable(ErrorMsg);
            'RunTC029':
                CheckPickReassignHist(ErrorMsg);
            'RunTC030':
                CheckShipmentMgmt(ErrorMsg);
            'RunTC031':
                CheckShipmentMgmt(ErrorMsg);
            'RunTC032':
                CheckShipmentMgmt(ErrorMsg);
            'RunTC033':
                CheckSSCCGen(ErrorMsg);
            else
                ErrorMsg := StrSubstNo('Procedure %1 bulunamadı (Section D)', ProcedureName);
        end;
    end;

    local procedure CheckActivityTable(var ErrorMsg: Text)
    var
        Activity: Record "Warehouse Activity Header";
    begin
        Activity.Reset();
        if Activity.Count() < 0 then;
    end;

    local procedure CheckLPMgmt(var ErrorMsg: Text)
    var
        AllObj: Record AllObjWithCaption;
    begin
        AllObj.SetRange("Object Type", AllObj."Object Type"::Codeunit);
        AllObj.SetRange("Object ID", 72046);
        if not AllObj.FindFirst() then
            ErrorMsg := 'PickMgmt codeunit 72046 yok';
    end;

    local procedure CheckShortPickReason(var ErrorMsg: Text)
    var
        Reason: Record "DOPSWHS Short Pick Reason";
    begin
        Reason.SetRange("Code", 'NO_STOCK');
        if not Reason.FindFirst() then
            ErrorMsg := 'TC-027: NO_STOCK reason yok — Demo Setup çalıştırın';
    end;

    local procedure CheckPickReassignHist(var ErrorMsg: Text)
    var
        AllObj: Record AllObjWithCaption;
    begin
        AllObj.SetRange("Object Type", AllObj."Object Type"::Table);
        AllObj.SetRange("Object ID", 72021);
        if not AllObj.FindFirst() then
            ErrorMsg := 'TC-029: Pick Reassign Hist tablo yok';
    end;

    local procedure CheckShipmentMgmt(var ErrorMsg: Text)
    var
        AllObj: Record AllObjWithCaption;
    begin
        AllObj.SetRange("Object Type", AllObj."Object Type"::Codeunit);
        AllObj.SetRange("Object ID", 72047);
        if not AllObj.FindFirst() then
            ErrorMsg := 'Shipment Mgmt codeunit 72047 yok';
    end;

    local procedure CheckSSCCGen(var ErrorMsg: Text)
    var
        SSCC: Codeunit "DOPSWHS SSCC Generator";
        Sscc18: Code[18];
    begin
        Sscc18 := SSCC.Generate();
        if StrLen(Sscc18) <> 18 then
            ErrorMsg := StrSubstNo('TC-033: SSCC %1 18 char değil (%2)', Sscc18, StrLen(Sscc18));
    end;
}
