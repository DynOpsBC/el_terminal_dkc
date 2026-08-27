codeunit 72495 "DOPSWHS Pack Station Tests"
{
    Subtype = Test;

    [Test]
    procedure ClosedSessionRetryReturnsExistingBox()
    var
        PackSession: Record "DOPSWHS Pack Session";
        PackLine: Record "DOPSWHS Pack Session Line";
        PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
        Assert: Codeunit "Library Assert";
        OrderNo: Code[20];
        BoxBarcode: Code[50];
        ResultBarcode: Code[50];
    begin
        OrderNo := NewCode('ORDER');
        BoxBarcode := NewCode('BOX');
        CreateSession(PackSession, PackSession.Status::Completed);
        CreateLine(PackLine, PackSession."Entry No.", OrderNo, BoxBarcode);

        ResultBarcode := PackMgmt.SetBoxForOrder(PackSession."Entry No.", OrderNo, BoxBarcode, '');

        Assert.AreEqual(BoxBarcode, ResultBarcode,
          'A retry with the same order and box must be idempotent even after the session closed.');
    end;

    [Test]
    procedure BoxBarcodeCannotBeReusedForAnotherOrder()
    var
        FirstSession: Record "DOPSWHS Pack Session";
        TargetSession: Record "DOPSWHS Pack Session";
        ExistingLine: Record "DOPSWHS Pack Session Line";
        TargetLine: Record "DOPSWHS Pack Session Line";
        PackMgmt: Codeunit "DOPSWHS Pack Station Mgmt";
        Assert: Codeunit "Library Assert";
        FirstOrderNo: Code[20];
        TargetOrderNo: Code[20];
        BoxBarcode: Code[50];
    begin
        FirstOrderNo := NewCode('ORDER-A');
        TargetOrderNo := NewCode('ORDER-B');
        BoxBarcode := NewCode('BOX');
        CreateSession(FirstSession, FirstSession.Status::Completed);
        CreateLine(ExistingLine, FirstSession."Entry No.", FirstOrderNo, BoxBarcode);
        CreateSession(TargetSession, TargetSession.Status::Open);
        CreateLine(TargetLine, TargetSession."Entry No.", TargetOrderNo, '');

        asserterror PackMgmt.SetBoxForOrder(TargetSession."Entry No.", TargetOrderNo, BoxBarcode, '');

        Assert.ExpectedError('koli barkodu daha önce');
    end;

    local procedure CreateSession(var PackSession: Record "DOPSWHS Pack Session"; Status: Enum "DOPSWHS Pack Status")
    begin
        PackSession.Init();
        PackSession.Status := Status;
        PackSession.Mode := PackSession.Mode::Solo;
        PackSession."Created DateTime" := CurrentDateTime();
        PackSession.Insert(true);
    end;

    local procedure CreateLine(var PackLine: Record "DOPSWHS Pack Session Line"; SessionEntryNo: Integer; OrderNo: Code[20]; BoxBarcode: Code[50])
    begin
        PackLine.Init();
        PackLine."Session Entry No." := SessionEntryNo;
        PackLine."Line No." := 10000;
        PackLine."Source Order No." := OrderNo;
        PackLine."Qty. Expected" := 1;
        PackLine."Box Barcode" := BoxBarcode;
        PackLine.Insert(true);
    end;

    local procedure NewCode(Prefix: Text): Code[50]
    begin
        exit(CopyStr(Prefix + '-' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, 50));
    end;
}
