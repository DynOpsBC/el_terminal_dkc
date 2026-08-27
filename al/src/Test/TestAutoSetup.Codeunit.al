codeunit 72064 "DOPSWHS Test Auto Setup"
{
    // Section A: TC-001 to TC-005 — Kurulum + Profile Doğrulama
    Access = Public;

    procedure Dispatch(ProcedureName: Text[80]; var ErrorMsg: Text)
    begin
        case ProcedureName of
            'RunTC001':
                RunTC001(ErrorMsg);
            'RunTC002':
                RunTC002(ErrorMsg);
            'RunTC003':
                RunTC003(ErrorMsg);
            'RunTC004':
                RunTC004(ErrorMsg);
            'RunTC005':
                RunTC005(ErrorMsg);
            else
                ErrorMsg := StrSubstNo('Procedure %1 bulunamadı (Section A)', ProcedureName);
        end;
    end;

    local procedure RunTC001(var ErrorMsg: Text)
    var
        DemoSetup: Codeunit "DOPSWHS Demo Data Setup";
        Setup: Record "DOPSWHS Setup";
        BarcodeRule: Record "DOPSWHS Barcode Rule";
        CountBefore: Integer;
    begin
        // Demo Data Setup idempotency: 2 kez çağrı side-effect üretmemeli
        DemoSetup.EnsureNumberSeries();
        BarcodeRule.Reset();
        CountBefore := BarcodeRule.Count();
        DemoSetup.EnsureNumberSeries();
        if BarcodeRule.Count() <> CountBefore then
            ErrorMsg := StrSubstNo('İdempotency bozuk: barcode rule sayısı değişti (%1 %2)', CountBefore, BarcodeRule.Count());
    end;

    local procedure RunTC002(var ErrorMsg: Text)
    var
        LP: Record "DOPSWHS LP Header";
        CountSheet: Record "DOPSWHS Count Sheet Header";
        BuiltLPCount: Integer;
        OpenCountSheetCount: Integer;
    begin
        LP.SetRange(Status, LP.Status::Built);
        BuiltLPCount := LP.Count();
        if BuiltLPCount < 1 then begin
            ErrorMsg := 'Built LP yok — önce Create Demo Transactions çalıştırın';
            exit;
        end;

        CountSheet.SetRange(Status, CountSheet.Status::Open);
        OpenCountSheetCount := CountSheet.Count();
        if OpenCountSheetCount < 1 then begin
            ErrorMsg := 'Open Count Sheet yok — Create Demo Transactions çalıştırın';
            exit;
        end;
    end;

    local procedure RunTC003(var ErrorMsg: Text)
    var
        AllObj: Record AllObjWithCaption;
    begin
        AllObj.SetRange("Object Type", AllObj."Object Type"::Page);
        AllObj.SetRange("Object ID", 72095);
        if not AllObj.FindFirst() then
            ErrorMsg := 'Page 72095 (DynOps WMS RC) bulunamadı'
        else if not (AllObj."Object Name" = 'DOPSWHS DynOps WMS RC') then
            ErrorMsg := StrSubstNo('Page 72095 object name beklenmedik: %1', AllObj."Object Name");
    end;

    local procedure RunTC004(var ErrorMsg: Text)
    var
        Cue: Record "DOPSWHS DynOps WMS Cue";
    begin
        if not Cue.Get('') then begin
            Cue.Init();
            Cue."Primary Key" := '';
            Cue.Insert(true);
        end;
        Cue.CalcFields("Open Whse Receipts", "Open Picks", "Released Shipments", "Open LPs", "Built LPs");
        // Hata fırlatmazsa cue FlowField'ları sağlam
    end;

    local procedure RunTC005(var ErrorMsg: Text)
    var
        TestCase: Record "DOPSWHS Test Case";
        AllObj: Record AllObjWithCaption;
        CatalogCount: Integer;
        AutoCount: Integer;
    begin
        // Production app içindeki Test Catalog kayıt sayısı (50 case bekleniyor)
        TestCase.Reset();
        CatalogCount := TestCase.Count();
        if CatalogCount < 50 then begin
            ErrorMsg := StrSubstNo('Test Case catalog count dusuk (%1 < 50) - Setup Test Catalog calistirin', CatalogCount);
            exit;
        end;
        // Production app'in 11 automation codeunit'i (72061-72071)
        AllObj.SetRange("Object Type", AllObj."Object Type"::Codeunit);
        AllObj.SetFilter("Object ID", '72061..72071');
        AutoCount := AllObj.Count();
        if AutoCount < 11 then
            ErrorMsg := StrSubstNo('Automation codeunit sayisi dusuk (%1 < 11)', AutoCount);
    end;
}
