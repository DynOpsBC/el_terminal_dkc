codeunit 72069 "DOPSWHS Test Auto Count"
{
    // Section F: TC-037 to TC-040 — Inventory Count
    Access = Public;

    procedure Dispatch(ProcedureName: Text[80]; var ErrorMsg: Text)
    begin
        case ProcedureName of
            'RunTC037':
                RunTC037(ErrorMsg);
            'RunTC038':
                RunTC038(ErrorMsg);
            'RunTC039':
                RunTC039(ErrorMsg);
            'RunTC040':
                RunTC040(ErrorMsg);
            else
                ErrorMsg := StrSubstNo('Procedure %1 bulunamadı (Section F)', ProcedureName);
        end;
    end;

    local procedure RunTC037(var ErrorMsg: Text)
    var
        Setup: Record "DOPSWHS Setup";
        CountSheet: Record "DOPSWHS Count Sheet Header";
    begin
        Setup.Get('');
        if Setup."Default Location Code" = '' then begin
            ErrorMsg := 'TC-037: Default Location boş';
            exit;
        end;
        CountSheet.Init();
        CountSheet."Location Code" := Setup."Default Location Code";
        CountSheet.Mode := CountSheet.Mode::Blind;
        CountSheet.Status := CountSheet.Status::Open;
        CountSheet.Insert(true);
        if CountSheet."No." = '' then
            ErrorMsg := 'TC-037: CountSheet No. boş kaldı (NoSeries hatası olabilir)';
    end;

    local procedure RunTC038(var ErrorMsg: Text)
    var
        AllObj: Record AllObjWithCaption;
    begin
        AllObj.SetRange("Object Type", AllObj."Object Type"::Codeunit);
        AllObj.SetRange("Object ID", 72050);
        if not AllObj.FindFirst() then
            ErrorMsg := 'TC-038: Count Mgmt codeunit 72050 yok';
    end;

    local procedure RunTC039(var ErrorMsg: Text)
    var
        AllObj: Record AllObjWithCaption;
    begin
        AllObj.SetRange("Object Type", AllObj."Object Type"::Codeunit);
        AllObj.SetRange("Object ID", 72050);
        if not AllObj.FindFirst() then
            ErrorMsg := 'TC-039: Count Mgmt codeunit 72050 yok';
    end;

    local procedure RunTC040(var ErrorMsg: Text)
    var
        AllObj: Record AllObjWithCaption;
    begin
        AllObj.SetRange("Object Type", AllObj."Object Type"::Page);
        AllObj.SetRange("Object ID", 72085);
        if not AllObj.FindFirst() then
            ErrorMsg := 'TC-040: Variance Review page 72085 yok';
    end;
}
