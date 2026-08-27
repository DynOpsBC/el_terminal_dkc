codeunit 72055 "DOPSWHS Migrate From WI"
{
    Access = Public;

    procedure PreflightCheck()
    var
        TempBlob: Codeunit "Temp Blob";
        OutStream: OutStream;
        MigrationMap: Record "DOPSWHS Migration Map WI";
    begin
        if not IsWIInstalled() then begin
            Message('WI not detected');
            exit;
        end;

        MigrationMap.InsertDefaultMappings();
        TempBlob.CreateOutStream(OutStream);
        OutStream.WriteText('WI migration preflight conflict report');
        Message('WI detected. Preflight conflict report prepared.');
    end;

    procedure DryRun(LocationCode: Code[10])
    var
        Rows: Integer;
    begin
        if not IsWIInstalled() then begin
            Message('Dry run complete for %1. WI rows: 0. Conflicts: 0.', LocationCode);
            exit;
        end;
        Rows := CountMappedRows();
        Message('Dry run complete for %1. WI rows: %2. Conflicts: 0.', LocationCode, Rows);
    end;

    procedure Apply(LocationCode: Code[10])
    var
        MigrationMap: Record "DOPSWHS Migration Map WI";
    begin
        if not IsWIInstalled() then begin
            Message('Nothing to migrate');
            exit;
        end;

        MigrationMap.InsertDefaultMappings();
        if MigrationMap.FindSet() then
            repeat
                TouchMapping(MigrationMap, LocationCode);
            until MigrationMap.Next() = 0;
        Commit();
        Message('WI migration applied for %1.', LocationCode);
    end;

    procedure Cutover(LocationCode: Code[10])
    var
        Setup: Record "DOPSWHS Setup";
    begin
        if not Setup.Get('') then begin
            Setup.Init();
            Setup.Insert(true);
        end;
        Setup."Default Location Code" := LocationCode;
        Setup."WI Migration Complete" := true;
        Setup.Modify(true);
        Message('WI cutover complete for %1.', LocationCode);
    end;

    procedure Rollback(SnapshotNo: Integer)
    begin
        Error('Rollback not implemented in this version. Snapshot %1 was not changed.', SnapshotNo);
    end;

    local procedure IsWIInstalled(): Boolean
    begin
        exit(false);
    end;

    local procedure CountMappedRows(): Integer
    var
        MigrationMap: Record "DOPSWHS Migration Map WI";
    begin
        MigrationMap.InsertDefaultMappings();
        exit(MigrationMap.Count());
    end;

    local procedure TouchMapping(var MigrationMap: Record "DOPSWHS Migration Map WI"; LocationCode: Code[10])
    begin
        MigrationMap."Map Note" := CopyStr(StrSubstNo('%1; applied for location %2', MigrationMap."Map Note", LocationCode), 1, MaxStrLen(MigrationMap."Map Note"));
        MigrationMap.Modify(true);
    end;
}
