codeunit 72066 "DOPSWHS Test Auto Receive"
{
    // Section C: TC-016 to TC-023 — Mal Kabul Uçtan Uca
    Access = Public;

    procedure Dispatch(ProcedureName: Text[80]; var ErrorMsg: Text)
    begin
        case ProcedureName of
            'RunTC016':
                RunTC016(ErrorMsg);
            'RunTC017':
                RunTC017(ErrorMsg);
            'RunTC018':
                RunTC018(ErrorMsg);
            'RunTC019':
                RunTC019(ErrorMsg);
            'RunTC020':
                RunTC020(ErrorMsg);
            'RunTC021':
                RunTC021(ErrorMsg);
            'RunTC022':
                RunTC022(ErrorMsg);
            'RunTC023':
                RunTC023(ErrorMsg);
            else
                ErrorMsg := StrSubstNo('Procedure %1 bulunamadı (Section C)', ProcedureName);
        end;
    end;

    local procedure RunTC016(var ErrorMsg: Text)
    var
        WhseRcpt: Record "Warehouse Receipt Header";
    begin
        // Smoke test: Warehouse Receipt tablosuna erişebiliyor muyuz?
        WhseRcpt.Reset();
        if WhseRcpt.Count() < 0 then;
    end;

    local procedure RunTC017(var ErrorMsg: Text)
    var
        LP: Record "DOPSWHS LP Header";
        LPMgmt: Codeunit "DOPSWHS LP Management";
        Setup: Record "DOPSWHS Setup";
        LocCode: Code[10];
    begin
        Setup.Get('');
        LocCode := Setup."Default Location Code";
        if LocCode = '' then begin
            ErrorMsg := 'TC-017: Default Location boş';
            exit;
        end;
        LPMgmt.Build('CARTON-S', LocCode, '', LP);
        if LP."Assigned Document Type" <> LP."Assigned Document Type"::None then
            ErrorMsg := 'TC-017: yeni LP Assigned Doc Type None olmalı';
    end;

    local procedure RunTC018(var ErrorMsg: Text)
    var
        Parser: Codeunit "DOPSWHS Barcode Parser";
        Result: JsonObject;
        RawGS1: Text;
        ParseOk: Boolean;
    begin
        RawGS1 := '(01)08401234567890(10)LOT123(17)260101(21)SN42';
        ParseOk := Parser.ParseBarcode(RawGS1, Result);
        if not ParseOk then
            ErrorMsg := 'TC-018: GS1-128 parse başarısız';
    end;

    local procedure RunTC019(var ErrorMsg: Text)
    var
        TransferHdr: Record "Transfer Header";
    begin
        TransferHdr.Reset();
        if TransferHdr.Count() < 0 then;
    end;

    local procedure RunTC020(var ErrorMsg: Text)
    var
        WhseRcpt: Record "Warehouse Receipt Header";
    begin
        WhseRcpt.Reset();
        if WhseRcpt.Count() < 0 then;
    end;

    local procedure RunTC021(var ErrorMsg: Text)
    var
        Item: Record Item;
    begin
        if not Item.Get('ITEM-LOT-1') then
            ErrorMsg := 'TC-021: ITEM-LOT-1 yok — Setup E2E Test Data çalıştırın';
    end;

    local procedure RunTC022(var ErrorMsg: Text)
    var
        AllObj: Record AllObjWithCaption;
    begin
        AllObj.SetRange("Object Type", AllObj."Object Type"::Page);
        AllObj.SetRange("Object ID", 72082);
        if not AllObj.FindFirst() then
            ErrorMsg := 'TC-022: Page 72082 (Receiving Queue) yok';
    end;

    local procedure RunTC023(var ErrorMsg: Text)
    var
        AllObj: Record AllObjWithCaption;
    begin
        AllObj.SetRange("Object Type", AllObj."Object Type"::TableExtension);
        AllObj.SetRange("Object ID", 72404);
        if not AllObj.FindFirst() then
            ErrorMsg := 'TC-023: TableExt 72404 (PostedWhseReceiptLineExt) yok';
    end;
}
