codeunit 72373 "DOPSWHS Azure Dispatch Task"
{
    Access = Internal;
    TableNo = "DOPSWHS Print Job Queue";
    Permissions =
        tabledata "DOPSWHS Setup" = rimd,
        tabledata "DOPSWHS Printer" = rimd,
        tabledata "DOPSWHS Print Job Queue" = rimd,
        tabledata "DOPSWHS Print Job Log" = rimd;

    trigger OnRun()
    var
        AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
    begin
        if Rec."Job ID" <> 0 then
            AzureBridge.DispatchJob(Rec."Job ID");
    end;
}

codeunit 72374 "DOPSWHS Azure Print Worker"
{
    Access = Internal;
    Permissions =
        tabledata "DOPSWHS Setup" = rimd,
        tabledata "DOPSWHS Printer" = rimd,
        tabledata "DOPSWHS Print Job Queue" = rimd,
        tabledata "DOPSWHS Print Job Log" = rimd,
        tabledata "Job Queue Entry" = rimd,
        tabledata "Job Queue Log Entry" = rimd,
        tabledata "Error Message Register" = rimd,
        tabledata "Error Message" = rimd;

    trigger OnRun()
    var
        Setup: Record "DOPSWHS Setup";
        AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
        ErrorText: Text;
    begin
        if not Setup.Get('') then
            exit;
        if Setup."Print Channel" <> Setup."Print Channel"::AzureDirect then
            exit;
        AzureBridge.WarnIfBlobSasExpiresSoon();
        if not TryDispatchCycle() then begin
            ErrorText := CopyStr(GetLastErrorText(), 1, 250);
            ClearLastError();
            LogWorkerWarning('dispatch', ErrorText);
        end else
            Commit();
        if not TryStatusCycle() then begin
            ErrorText := CopyStr(GetLastErrorText(), 1, 250);
            ClearLastError();
            LogWorkerWarning('status', ErrorText);
        end else
            Commit();
        MarkStaleJobs();
    end;

    procedure RunNow()
    var
        AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
    begin
        AzureBridge.WarnIfBlobSasExpiresSoon();
        if not TryDispatchCycle() then
            Error('Azure print dispatch failed: %1', CopyStr(GetLastErrorText(), 1, 250));
        Commit();
        if not TryStatusCycle() then
            Error('Azure printer-status synchronization failed: %1', CopyStr(GetLastErrorText(), 1, 250));
        Commit();
        MarkStaleJobs();
    end;

    [TryFunction]
    local procedure TryDispatchCycle()
    var
        AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
    begin
        AzureBridge.ValidateConfiguration(false);
        AzureBridge.DispatchPending(20);
    end;

    [TryFunction]
    local procedure TryStatusCycle()
    var
        StatusSync: Codeunit "DOPSWHS Azure Print Status";
    begin
        StatusSync.Poll(20);
    end;

    local procedure MarkStaleJobs()
    var
        AzureBridge: Codeunit "DOPSWHS Azure Print Bridge";
        StatusSync: Codeunit "DOPSWHS Azure Print Status";
    begin
        AzureBridge.MarkStaleDispatched(100);
        StatusSync.MarkStalePrinters(100);
    end;

    procedure ScheduleWorkerJob()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"DOPSWHS Azure Print Worker");
        if JobQueueEntry.FindFirst() then begin
            if IsNullGuid(JobQueueEntry."System Task ID") then begin
                JobQueueEntry.Status := JobQueueEntry.Status::"On Hold";
                JobQueueEntry.Modify(true);
                JobQueueEntry.SetStatus(JobQueueEntry.Status::Ready);
            end;
            exit;
        end;

        JobQueueEntry.Init();
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := Codeunit::"DOPSWHS Azure Print Worker";
        JobQueueEntry.Description := CopyStr('DOPSWHS Azure Direct print worker', 1, MaxStrLen(JobQueueEntry.Description));
        JobQueueEntry."Recurring Job" := true;
        JobQueueEntry."Run on Mondays" := true;
        JobQueueEntry."Run on Tuesdays" := true;
        JobQueueEntry."Run on Wednesdays" := true;
        JobQueueEntry."Run on Thursdays" := true;
        JobQueueEntry."Run on Fridays" := true;
        JobQueueEntry."Run on Saturdays" := true;
        JobQueueEntry."Run on Sundays" := true;
        JobQueueEntry."Starting Time" := 000000T;
        JobQueueEntry."Ending Time" := 235959T;
        JobQueueEntry."No. of Minutes between Runs" := 1;
        JobQueueEntry.Status := JobQueueEntry.Status::"On Hold";
        JobQueueEntry.Insert(true);
        JobQueueEntry.SetStatus(JobQueueEntry.Status::Ready);
    end;

    local procedure LogWorkerWarning(Phase: Text; ErrorText: Text)
    var
        Telemetry: Codeunit "DOPSWHS Telemetry";
        Dimensions: Dictionary of [Text, Text];
    begin
        if ErrorText <> '' then
            Dimensions.Add('error', ErrorText);
        Dimensions.Add('phase', CopyStr(Phase, 1, 30));
        Telemetry.Log(
            'AzurePrint.WorkerFailed',
            'Azure Direct print worker could not complete its cycle.',
            Verbosity::Warning,
            Dimensions);
    end;
}
