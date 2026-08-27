codeunit 72071 "DOPSWHS Test Auto System"
{
    // Section H: TC-046 to TC-050 — Sistem + SPA + API
    Access = Public;

    procedure Dispatch(ProcedureName: Text[80]; var ErrorMsg: Text)
    begin
        case ProcedureName of
            'RunTC046':
                RunTC046(ErrorMsg);
            'RunTC047':
                RunTC047(ErrorMsg);
            'RunTC048':
                RunTC048(ErrorMsg);
            'RunTC049':
                RunTC049(ErrorMsg);
            'RunTC050':
                RunTC050(ErrorMsg);
            else
                ErrorMsg := StrSubstNo('Procedure %1 bulunamadı (Section H)', ProcedureName);
        end;
    end;

    local procedure RunTC046(var ErrorMsg: Text)
    var
        Device: Record "DOPSWHS Device Registration";
    begin
        if Device.FindFirst() then begin
            Device."Last Seen DateTime" := CurrentDateTime();
            Device.Modify(true);
        end else begin
            ErrorMsg := 'TC-046: Hiç device registration yok — Demo Setup çalıştırın';
        end;
    end;

    local procedure RunTC047(var ErrorMsg: Text)
    var
        AllObj: Record AllObjWithCaption;
    begin
        AllObj.SetRange("Object Type", AllObj."Object Type"::Table);
        AllObj.SetRange("Object ID", 72019);
        if not AllObj.FindFirst() then
            ErrorMsg := 'TC-047: Sync Conflict Buffer tablo yok';
    end;

    local procedure RunTC048(var ErrorMsg: Text)
    var
        AllObj: Record AllObjWithCaption;
        ApiCount: Integer;
    begin
        AllObj.SetRange("Object Type", AllObj."Object Type"::Page);
        AllObj.SetFilter("Object ID", '72086|72087|72088|72226');
        ApiCount := AllObj.Count();
        if ApiCount < 4 then
            ErrorMsg := StrSubstNo('TC-048: 4 API page bekleniyor, bulunan %1', ApiCount);
    end;

    local procedure RunTC049(var ErrorMsg: Text)
    var
        AllObj: Record AllObjWithCaption;
    begin
        AllObj.SetRange("Object Type", AllObj."Object Type"::Codeunit);
        AllObj.SetRange("Object ID", 72053);
        if not AllObj.FindFirst() then
            ErrorMsg := 'TC-049: Webhook Mgmt codeunit 72053 yok';
    end;

    local procedure RunTC050(var ErrorMsg: Text)
    var
        AllObj: Record AllObjWithCaption;
    begin
        // ControlAddIn AllObj enum value yok — Page tipi olarak doğrulanır (host page var)
        AllObj.SetRange("Object Type", AllObj."Object Type"::Page);
        AllObj.SetRange("Object ID", 72083);
        if not AllObj.FindFirst() then
            ErrorMsg := 'TC-050: Pick Queue page (LP Browser host) 72083 yok';
    end;
}
