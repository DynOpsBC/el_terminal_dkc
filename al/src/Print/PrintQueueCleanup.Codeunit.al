codeunit 72370 "DOPSWHS Print Queue Cleanup"
{
    Access = Internal;
    Permissions =
        tabledata "DOPSWHS Print Job Queue" = rimd,
        tabledata "DOPSWHS Print Job Log" = rimd,
        tabledata "Job Queue Entry" = rimd,
        tabledata "Job Queue Log Entry" = rimd,
        tabledata "Error Message Register" = rimd,
        tabledata "Error Message" = rimd;

    trigger OnRun()
    begin
        DeleteCompletedBefore(CurrentDateTime() - (30 * OneDay()), false);
        DeleteCompletedBefore(CurrentDateTime() - (90 * OneDay()), true);
    end;

    procedure ScheduleCleanupJob()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"DOPSWHS Print Queue Cleanup");
        if JobQueueEntry.FindFirst() then begin
            // Repair a row created by an older build that inserted Status=Ready
            // without actually scheduling a system task.
            if IsNullGuid(JobQueueEntry."System Task ID") then begin
                JobQueueEntry.Status := JobQueueEntry.Status::"On Hold";
                JobQueueEntry.Modify(true);
                JobQueueEntry.SetStatus(JobQueueEntry.Status::Ready);
            end;
            exit;
        end;

        JobQueueEntry.Init();
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := Codeunit::"DOPSWHS Print Queue Cleanup";
        JobQueueEntry.Description := CopyStr('DOPSWHS print queue cleanup (daily)', 1, MaxStrLen(JobQueueEntry.Description));
        JobQueueEntry."Recurring Job" := true;
        JobQueueEntry."Run on Mondays" := true;
        JobQueueEntry."Run on Tuesdays" := true;
        JobQueueEntry."Run on Wednesdays" := true;
        JobQueueEntry."Run on Thursdays" := true;
        JobQueueEntry."Run on Fridays" := true;
        JobQueueEntry."Run on Saturdays" := true;
        JobQueueEntry."Run on Sundays" := true;
        JobQueueEntry."Starting Time" := 020000T;
        JobQueueEntry."Ending Time" := 025959T;
        JobQueueEntry."No. of Minutes between Runs" := 1440;
        // A plain Ready-row insert does not create a scheduled system task.
        // Insert On Hold, then use the table's status transition so the
        // standard Job Queue - Enqueue codeunit creates System Task ID.
        JobQueueEntry.Status := JobQueueEntry.Status::"On Hold";
        JobQueueEntry.Insert(true);
        JobQueueEntry.SetStatus(JobQueueEntry.Status::Ready);
    end;

    local procedure DeleteCompletedBefore(Cutoff: DateTime; FailedJobs: Boolean)
    var
        Queue: Record "DOPSWHS Print Job Queue";
        LogEntry: Record "DOPSWHS Print Job Log";
        Deleted: Integer;
    begin
        if FailedJobs then
            Queue.SetRange(Status, Queue.Status::Failed)
        else
            Queue.SetRange(Status, Queue.Status::Sent);
        Queue.SetFilter(Created, '<%1', Cutoff);
        if Queue.FindSet(true) then
            repeat
                LogEntry.SetRange("Job ID", Queue."Job ID");
                if not LogEntry.IsEmpty() then
                    LogEntry.DeleteAll(true);
                Queue.Delete(true);
                Deleted += 1;
            until (Queue.Next() = 0) or (Deleted >= 5000);
    end;

    local procedure OneDay(): Duration
    begin
        exit(24 * 60 * 60 * 1000);
    end;
}
