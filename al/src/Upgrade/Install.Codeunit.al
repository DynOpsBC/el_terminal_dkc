codeunit 72033 "DOPSWHS Install"
{
    Subtype = Install;

    /// <summary>
    /// On a fresh install (or upgrade), we only seed singleton master rows and
    /// the assisted-setup checklist. Demo data, smoke tests, and quality demo
    /// orders are NOT auto-seeded any more — they used to land in production
    /// tenants and pollute customer environments.
    ///
    /// To self-provision a sandbox call `DOPSWHS Demo Bootstrap`.RunFullDemo()
    /// from the Setup card explicitly. Production install is now data-clean.
    /// </summary>
    trigger OnInstallAppPerCompany()
    var
        Setup: Record "DOPSWHS Setup";
        Cue: Record "DOPSWHS Warehouse Mgr Cue";
        SetupWizard: Codeunit "DOPSWHS Setup Wizard";
        AppProfileMgmt: Codeunit "DOPSWHS App Profile Mgmt";
        ConfigChecker: Codeunit "DOPSWHS Config Checker";
        License: Codeunit "DOPSWHS License Mgmt";
        PrintCleanup: Codeunit "DOPSWHS Print Queue Cleanup";
        AzurePrintWorker: Codeunit "DOPSWHS Azure Print Worker";
    begin
        if not Setup.Get('') then begin
            Setup.Init();
            Setup.Insert(true);
        end;
        if not Cue.Get('') then begin
            Cue.Init();
            Cue.Insert(true);
        end;
        SetupWizard.SeedSprint1Defaults();
        SetupWizard.SeedDefaultLPTemplates();
        AppProfileMgmt.SeedDefaults();          // seed DEFAULT app profile + install-user profile
        ConfigChecker.RegisterAssistedSetup();  // seed config checklist + register Assisted Setup
        License.ScheduleVerifyJob();            // seeds the hourly Job Queue Entry for /verify
        PrintCleanup.ScheduleCleanupJob();      // keeps binary PDF/ZPL payloads out of permanent company storage
        AzurePrintWorker.ScheduleWorkerJob();  // one-minute fallback; exits until AzureDirect is activated
    end;
}
