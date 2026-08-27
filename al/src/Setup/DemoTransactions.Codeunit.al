codeunit 72059 "DOPSWHS Demo Transactions"
{
    // Transactional demo data: 5 built LP'yi sandbox'ın depo lokasyonunda
    // farklı bin'lerle/itemlarla oluşturur — Role Center'da Open/Built LP
    // cue'ları somut sayıyla gözüksün diye.
    Access = Public;

    trigger OnRun()
    begin
        CreateAllDemoTransactions();
    end;

    procedure CreateDemoLPs() ResultMsg: Text
    var
        Setup: Record "DOPSWHS Setup";
        LP1: Code[20];
        LP2: Code[20];
        LP3: Code[20];
        LP4: Code[20];
        LP5: Code[20];
        Created: Integer;
        Msg: Label 'Demo transaction tamamlandı.\n\n%1 yeni LP oluşturuldu (built durumunda):\n• %2 (CARTON-S)\n• %3 (CARTON-M)\n• %4 (PALLET-EUR)\n• %5 (TOTE-A)\n• %6 (PALLET-US)\n\nRole Center  License Plate cue grubu otomatik dolacak.';
        NoLocationMsg: Label 'Demo LP oluşturulamadı: Setup tablosunda Default Location Code boş veya geçersiz. Önce "Run Demo Setup" çalıştırın.';
    begin
        Setup.Get('');
        if Setup."Default Location Code" = '' then begin
            ResultMsg := NoLocationMsg;
            Message(ResultMsg);
            exit(ResultMsg);
        end;

        LP1 := CreateBuiltLP('CARTON-S', Setup."Default Location Code", '');
        LP2 := CreateBuiltLP('CARTON-M', Setup."Default Location Code", '');
        LP3 := CreateBuiltLP('PALLET-EUR', Setup."Default Location Code", '');
        LP4 := CreateBuiltLP('TOTE-A', Setup."Default Location Code", '');
        LP5 := CreateBuiltLP('PALLET-US', Setup."Default Location Code", '');

        if LP1 <> '' then Created += 1;
        if LP2 <> '' then Created += 1;
        if LP3 <> '' then Created += 1;
        if LP4 <> '' then Created += 1;
        if LP5 <> '' then Created += 1;

        ResultMsg := StrSubstNo(Msg, Created, LP1, LP2, LP3, LP4, LP5);
        Message(ResultMsg);
    end;

    procedure CreateActiveCountSheet() ResultMsg: Text
    var
        Setup: Record "DOPSWHS Setup";
        CountSheet: Record "DOPSWHS Count Sheet Header";
        CountSheetNo: Code[20];
        Msg: Label 'Demo count sheet oluşturuldu: %1 (Open, Location=%2, Mode=Blind).';
        AlreadyMsg: Label 'Aktif count sheet zaten mevcut: %1.';
    begin
        Setup.Get('');
        CountSheet.SetRange("Location Code", Setup."Default Location Code");
        CountSheet.SetRange(Status, CountSheet.Status::Open);
        if CountSheet.FindFirst() then begin
            ResultMsg := StrSubstNo(AlreadyMsg, CountSheet."No.");
            Message(ResultMsg);
            exit;
        end;

        Clear(CountSheet);
        CountSheet.Init();
        CountSheet."Location Code" := Setup."Default Location Code";
        CountSheet.Mode := CountSheet.Mode::Blind;
        CountSheet.Status := CountSheet.Status::Open;
        CountSheet.Insert(true);

        CountSheetNo := CountSheet."No.";
        ResultMsg := StrSubstNo(Msg, CountSheetNo, Setup."Default Location Code");
        Message(ResultMsg);
    end;

    procedure CreateAllDemoTransactions()
    var
        LpMsg: Text;
        CsMsg: Text;
    begin
        LpMsg := CreateDemoLPs();
        CsMsg := CreateActiveCountSheet();
    end;

    local procedure CreateBuiltLP(TemplateCode: Code[20]; LocationCode: Code[10]; BinCode: Code[20]) NewLPNo: Code[20]
    var
        LPHeader: Record "DOPSWHS LP Header";
        LPManagement: Codeunit "DOPSWHS LP Management";
        Template: Record "DOPSWHS LP Template";
        ResolvedBin: Code[20];
    begin
        if not Template.Get(TemplateCode) then
            exit('');

        ResolvedBin := BinCode;
        if ResolvedBin = '' then
            ResolvedBin := FindAnyBin(LocationCode);

        LPManagement.Build(TemplateCode, LocationCode, ResolvedBin, LPHeader);
        LPManagement.Stop(LPHeader, false);
        NewLPNo := LPHeader."No.";
    end;

    local procedure FindAnyBin(LocationCode: Code[10]): Code[20]
    var
        Bin: Record Bin;
    begin
        Bin.SetRange("Location Code", LocationCode);
        if Bin.FindFirst() then
            exit(Bin.Code);
        exit('');
    end;

}
