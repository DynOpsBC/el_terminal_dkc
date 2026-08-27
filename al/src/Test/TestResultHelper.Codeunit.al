codeunit 72063 "DOPSWHS Test Result Helper"
{
    // Test Run Result satırlarını yönetir — Pass/Fail/Skip kaydı + duration ölçümü.
    Access = Public;

    procedure StartCase(RunNo: Code[20]; CaseCode: Code[20])
    var
        Result: Record "DOPSWHS Test Run Result";
    begin
        if not Result.Get(RunNo, CaseCode) then begin
            Result.Init();
            Result."Run No." := RunNo;
            Result."Test Case Code" := CaseCode;
            Result.Insert(true);
        end;
        Result.Status := Result.Status::Running;
        Result."Started DateTime" := CurrentDateTime();
        Clear(Result."Error Message");
        Result."Completed DateTime" := 0DT;
        Result."Duration Ms" := 0;
        Result.Modify(true);
    end;

    procedure RecordPass(RunNo: Code[20]; CaseCode: Code[20]; SurrogateUsed: Boolean)
    var
        Result: Record "DOPSWHS Test Run Result";
    begin
        if not Result.Get(RunNo, CaseCode) then
            exit;
        Result.Status := Result.Status::Passed;
        Result."Completed DateTime" := CurrentDateTime();
        Result."Duration Ms" := CalculateDurationMs(Result."Started DateTime", Result."Completed DateTime");
        Result."Surrogate Used" := SurrogateUsed;
        Result."Error Message" := '';
        Result.Modify(true);
    end;

    procedure RecordFail(RunNo: Code[20]; CaseCode: Code[20]; ErrorMsg: Text; SurrogateUsed: Boolean)
    var
        Result: Record "DOPSWHS Test Run Result";
    begin
        if not Result.Get(RunNo, CaseCode) then
            exit;
        Result.Status := Result.Status::Failed;
        Result."Completed DateTime" := CurrentDateTime();
        Result."Duration Ms" := CalculateDurationMs(Result."Started DateTime", Result."Completed DateTime");
        Result."Surrogate Used" := SurrogateUsed;
        Result."Error Message" := CopyStr(ErrorMsg, 1, MaxStrLen(Result."Error Message"));
        Result.Modify(true);
    end;

    procedure RecordSkip(RunNo: Code[20]; CaseCode: Code[20]; Reason: Text)
    var
        Result: Record "DOPSWHS Test Run Result";
    begin
        if not Result.Get(RunNo, CaseCode) then begin
            Result.Init();
            Result."Run No." := RunNo;
            Result."Test Case Code" := CaseCode;
            Result.Insert(true);
        end;
        Result.Status := Result.Status::Skipped;
        Result."Started DateTime" := CurrentDateTime();
        Result."Completed DateTime" := CurrentDateTime();
        Result."Duration Ms" := 0;
        Result."Error Message" := CopyStr(Reason, 1, MaxStrLen(Result."Error Message"));
        Result.Modify(true);
    end;

    procedure RecordPendingManual(RunNo: Code[20]; CaseCode: Code[20]; Reason: Text)
    var
        Result: Record "DOPSWHS Test Run Result";
    begin
        if not Result.Get(RunNo, CaseCode) then begin
            Result.Init();
            Result."Run No." := RunNo;
            Result."Test Case Code" := CaseCode;
            Result.Insert(true);
        end;
        Result.Status := Result.Status::PendingManual;
        Result."Started DateTime" := CurrentDateTime();
        Result."Completed DateTime" := CurrentDateTime();
        Result."Error Message" := CopyStr(Reason, 1, MaxStrLen(Result."Error Message"));
        Result.Modify(true);
    end;

    procedure MarkPassedManually(var Result: Record "DOPSWHS Test Run Result"; UserNotes: Text)
    begin
        Result.Status := Result.Status::Passed;
        Result."Manual Verified By" := CopyStr(UserId(), 1, MaxStrLen(Result."Manual Verified By"));
        Result."Manual Verified DateTime" := CurrentDateTime();
        if UserNotes <> '' then
            Result.Notes := CopyStr(UserNotes, 1, MaxStrLen(Result.Notes));
        Result.Modify(true);
    end;

    procedure MarkFailedManually(var Result: Record "DOPSWHS Test Run Result"; ErrorNotes: Text)
    begin
        Result.Status := Result.Status::Failed;
        Result."Manual Verified By" := CopyStr(UserId(), 1, MaxStrLen(Result."Manual Verified By"));
        Result."Manual Verified DateTime" := CurrentDateTime();
        if ErrorNotes <> '' then
            Result.Notes := CopyStr(ErrorNotes, 1, MaxStrLen(Result.Notes));
        Result.Modify(true);
    end;

    local procedure CalculateDurationMs(StartedAt: DateTime; CompletedAt: DateTime): Integer
    var
        Duration: Duration;
    begin
        if (StartedAt = 0DT) or (CompletedAt = 0DT) then
            exit(0);
        Duration := CompletedAt - StartedAt;
        exit(Duration);
    end;

    procedure UpdateRunAggregate(RunNo: Code[20])
    var
        Run: Record "DOPSWHS Test Run";
        Result: Record "DOPSWHS Test Run Result";
        TotalCount: Integer;
        PassCount: Integer;
        FailCount: Integer;
        PendingCount: Integer;
        Duration: Duration;
    begin
        if not Run.Get(RunNo) then
            exit;

        Result.SetRange("Run No.", RunNo);
        TotalCount := Result.Count();
        Result.SetRange(Status, Result.Status::Passed);
        PassCount := Result.Count();
        Result.SetRange(Status, Result.Status::Failed);
        FailCount := Result.Count();
        Result.SetRange(Status, Result.Status::PendingManual);
        PendingCount := Result.Count();

        Run."Completed DateTime" := CurrentDateTime();
        if Run."Started DateTime" <> 0DT then begin
            Duration := Run."Completed DateTime" - Run."Started DateTime";
            Run."Duration (sec)" := Duration / 1000;
        end;

        if TotalCount > 0 then
            Run."Pass Rate %" := Round((PassCount / TotalCount) * 100, 0.1)
        else
            Run."Pass Rate %" := 0;

        if PendingCount > 0 then
            Run.Status := Run.Status::Completed
        else if FailCount > 0 then
            Run.Status := Run.Status::PartialPass
        else if PassCount = TotalCount then
            Run.Status := Run.Status::Completed
        else
            Run.Status := Run.Status::Failed;

        Run.Modify(true);
    end;
}
