codeunit 72070 "DOPSWHS Test Auto Production"
{
    // Section G: TC-041 to TC-045 — Üretim + Montaj
    Access = Public;

    procedure Dispatch(ProcedureName: Text[80]; var ErrorMsg: Text)
    begin
        case ProcedureName of
            'RunTC041':
                CheckProdMgmt(ErrorMsg);
            'RunTC042':
                CheckProdMgmt(ErrorMsg);
            'RunTC043':
                CheckLPTemplate(ErrorMsg);
            'RunTC044':
                CheckAssemblyMgmt(ErrorMsg);
            'RunTC045':
                CheckProdMgmt(ErrorMsg);
            else
                ErrorMsg := StrSubstNo('Procedure %1 bulunamadı (Section G)', ProcedureName);
        end;
    end;

    local procedure CheckProdMgmt(var ErrorMsg: Text)
    var
        AllObj: Record AllObjWithCaption;
    begin
        AllObj.SetRange("Object Type", AllObj."Object Type"::Codeunit);
        AllObj.SetRange("Object ID", 72048);
        if not AllObj.FindFirst() then
            ErrorMsg := 'Prod Mgmt codeunit 72048 yok';
    end;

    local procedure CheckLPTemplate(var ErrorMsg: Text)
    var
        Template: Record "DOPSWHS LP Template";
    begin
        if not Template.Get('CARTON-S') then
            ErrorMsg := 'TC-043: LP Template CARTON-S yok — Demo Setup çalıştırın';
    end;

    local procedure CheckAssemblyMgmt(var ErrorMsg: Text)
    var
        AllObj: Record AllObjWithCaption;
    begin
        AllObj.SetRange("Object Type", AllObj."Object Type"::Codeunit);
        AllObj.SetRange("Object ID", 72049);
        if not AllObj.FindFirst() then
            ErrorMsg := 'Assembly Mgmt codeunit 72049 yok';
    end;
}
