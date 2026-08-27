codeunit 72062 "DOPSWHS Test Runner"
{
    // Test Run orchestrator: aktif test case'leri sırayla çağırır,
    // her birinin automation procedure'ını invoke eder, Pass/Fail kaydeder.
    Access = Public;

    var
        ResultHelper: Codeunit "DOPSWHS Test Result Helper";

    procedure CreateNewRun(EnvironmentCode: Code[20]; UserGroupCode: Code[20]; Notes: Text[250]): Code[20]
    var
        Run: Record "DOPSWHS Test Run";
    begin
        Run.Init();
        Run."Environment Code" := EnvironmentCode;
        Run."User Group Code" := UserGroupCode;
        Run.Notes := Notes;
        Run.Status := Run.Status::Open;
        Run.Insert(true);
        exit(Run."Run No.");
    end;

    procedure StartRun(RunNo: Code[20])
    var
        Run: Record "DOPSWHS Test Run";
        TestCase: Record "DOPSWHS Test Case";
    begin
        if not Run.Get(RunNo) then
            Error('Test Run %1 not found', RunNo);
        if Run.Status = Run.Status::Running then
            Error('Test Run %1 already running', RunNo);

        Run.Status := Run.Status::Running;
        Run."Started DateTime" := CurrentDateTime();
        Run.Modify(true);

        TestCase.SetRange(Active, true);
        TestCase.SetCurrentKey(Section, "Sort Order");
        if TestCase.FindSet() then
            repeat
                ExecuteTestCase(RunNo, TestCase);
            until TestCase.Next() = 0;

        ResultHelper.UpdateRunAggregate(RunNo);
    end;

    procedure StartRunForFailedOnly(RunNo: Code[20])
    var
        Result: Record "DOPSWHS Test Run Result";
        TestCase: Record "DOPSWHS Test Case";
    begin
        Result.SetRange("Run No.", RunNo);
        Result.SetRange(Status, Result.Status::Failed);
        if Result.FindSet() then
            repeat
                if TestCase.Get(Result."Test Case Code") and TestCase.Active then
                    ExecuteTestCase(RunNo, TestCase);
            until Result.Next() = 0;
        ResultHelper.UpdateRunAggregate(RunNo);
    end;

    procedure ExecuteSingleCase(RunNo: Code[20]; CaseCode: Code[20])
    var
        TestCase: Record "DOPSWHS Test Case";
    begin
        if not TestCase.Get(CaseCode) then
            Error('Test Case %1 not found', CaseCode);
        if not TestCase.Active then
            Error('Test Case %1 inaktif — Active=Yes yapın', CaseCode);

        ExecuteTestCase(RunNo, TestCase);
        ResultHelper.UpdateRunAggregate(RunNo);
    end;

    local procedure ExecuteTestCase(RunNo: Code[20]; TestCase: Record "DOPSWHS Test Case")
    var
        ErrorMsg: Text;
        SurrogateUsed: Boolean;
        InvokedOk: Boolean;
    begin
        ResultHelper.StartCase(RunNo, TestCase."Code");

        SurrogateUsed := (TestCase."Automation Type" = TestCase."Automation Type"::Surrogate);

        case TestCase."Automation Type" of
            TestCase."Automation Type"::Manual:
                begin
                    ResultHelper.RecordPendingManual(RunNo, TestCase."Code", 'Manual verification required');
                    exit;
                end;
        end;

        InvokedOk := TryInvokeProcedure(TestCase."Automation Codeunit ID", TestCase."Automation Procedure", ErrorMsg);
        if InvokedOk then
            ResultHelper.RecordPass(RunNo, TestCase."Code", SurrogateUsed)
        else begin
            if ErrorMsg = '' then
                ErrorMsg := GetLastErrorText();
            ResultHelper.RecordFail(RunNo, TestCase."Code", ErrorMsg, SurrogateUsed);
        end;
    end;

    [TryFunction]
    local procedure TryInvokeProcedure(CodeunitId: Integer; ProcedureName: Text[80]; var ErrorMsg: Text)
    begin
        InvokeProcedureSafe(CodeunitId, ProcedureName, ErrorMsg);
    end;

    local procedure InvokeProcedureSafe(CodeunitId: Integer; ProcedureName: Text[80]; var ErrorMsg: Text)
    var
        AutoSetup: Codeunit "DOPSWHS Test Auto Setup";
        AutoLP: Codeunit "DOPSWHS Test Auto LP";
        AutoReceive: Codeunit "DOPSWHS Test Auto Receive";
        AutoPickShip: Codeunit "DOPSWHS Test Auto Pick Ship";
        AutoMove: Codeunit "DOPSWHS Test Auto Move";
        AutoCount: Codeunit "DOPSWHS Test Auto Count";
        AutoProduction: Codeunit "DOPSWHS Test Auto Production";
        AutoSystem: Codeunit "DOPSWHS Test Auto System";
    begin
        case CodeunitId of
            72064:
                AutoSetup.Dispatch(ProcedureName, ErrorMsg);
            72065:
                AutoLP.Dispatch(ProcedureName, ErrorMsg);
            72066:
                AutoReceive.Dispatch(ProcedureName, ErrorMsg);
            72067:
                AutoPickShip.Dispatch(ProcedureName, ErrorMsg);
            72068:
                AutoMove.Dispatch(ProcedureName, ErrorMsg);
            72069:
                AutoCount.Dispatch(ProcedureName, ErrorMsg);
            72070:
                AutoProduction.Dispatch(ProcedureName, ErrorMsg);
            72071:
                AutoSystem.Dispatch(ProcedureName, ErrorMsg);
            else
                Error('Automation Codeunit ID %1 desteklenmiyor', CodeunitId);
        end;
        if ErrorMsg <> '' then
            Error(ErrorMsg);
    end;
}
