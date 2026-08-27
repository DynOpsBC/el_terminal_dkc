codeunit 72082 "DOPSWHS License Mgmt"
{
    Access = Public;

    var
        VerifyEveryMs: Duration; // 1 hour
        GraceDays: Integer;    // 7

    /// <summary>
    /// Entry called by the Job Queue Entry seeded in Install / Upgrade.
    /// Every guard path also calls `EnsureRecentVerify()` so the codeunit
    /// works even before the job queue picks it up.
    /// </summary>
    trigger OnRun()
    begin
        InitConstants();
        TryVerify(false);
    end;

    local procedure InitConstants()
    begin
        VerifyEveryMs := 60 * 60 * 1000; // 1 hour
        GraceDays := 7;
    end;

    /// <summary>
    /// Called by Install/Upgrade triggers (codeunit 72033/72034). Inserts a
    /// hourly Job Queue Entry for codeunit 72082 if one doesn't already
    /// exist. The first verify still happens inline via `EnsureRecentVerify`
    /// during the first guarded action.
    /// </summary>
    procedure ScheduleVerifyJob()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"DOPSWHS License Mgmt");
        if JobQueueEntry.FindFirst() then exit;

        JobQueueEntry.Init();
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := Codeunit::"DOPSWHS License Mgmt";
        JobQueueEntry.Description := CopyStr('DOPSWHS license verify (hourly)', 1, MaxStrLen(JobQueueEntry.Description));
        JobQueueEntry."Recurring Job" := true;
        JobQueueEntry."Run on Mondays" := true;
        JobQueueEntry."Run on Tuesdays" := true;
        JobQueueEntry."Run on Wednesdays" := true;
        JobQueueEntry."Run on Thursdays" := true;
        JobQueueEntry."Run on Fridays" := true;
        JobQueueEntry."Run on Saturdays" := true;
        JobQueueEntry."Run on Sundays" := true;
        JobQueueEntry."Starting Time" := 060000T;
        JobQueueEntry."Ending Time" := 235959T;
        JobQueueEntry."No. of Minutes between Runs" := 60;
        if JobQueueEntry.Insert(true) then;
    end;

    /// <summary>
    /// Called from any guarded operation (GuardFeature / GuardSeats). If the
    /// last verify is older than `VerifyEveryMs` or never happened, kicks
    /// off a sync verify. Keeps the system honest even when the job queue
    /// is offline.
    /// </summary>
    procedure EnsureRecentVerify()
    var
        Setup: Record "DOPSWHS Setup";
    begin
        InitConstants();
        if not Setup.Get('') then exit;
        if Setup."License Last Verified At" = 0DT then begin
            TryVerify(true);
            exit;
        end;
        if CurrentDateTime() - Setup."License Last Verified At" > VerifyEveryMs then
            TryVerify(false);
    end;

    procedure VerifyNow(): Boolean
    var
        Setup: Record "DOPSWHS Setup";
    begin
        if not Setup.Get('') then exit(false);
        exit(TryVerify(true));
    end;

    procedure CurrentTier(): Enum "DOPSWHS License Tier"
    var
        Setup: Record "DOPSWHS Setup";
    begin
        if not Setup.Get('') then exit(Enum::"DOPSWHS License Tier"::Essentials);
        case Setup."License Tier" of
            Setup."License Tier"::Essentials: exit(Enum::"DOPSWHS License Tier"::Essentials);
            Setup."License Tier"::Advanced: exit(Enum::"DOPSWHS License Tier"::Advanced);
            Setup."License Tier"::Enterprise: exit(Enum::"DOPSWHS License Tier"::Enterprise);
        end;
        exit(Enum::"DOPSWHS License Tier"::Essentials);
    end;

    procedure IsActive(): Boolean
    var
        Setup: Record "DOPSWHS Setup";
    begin
        if not Setup.Get('') then exit(false);
        exit((Setup."License Status" = Setup."License Status"::Active) or
             (Setup."License Status" = Setup."License Status"::Offline));
    end;

    procedure GuardFeature(Feature: Enum "DOPSWHS License Feature")
    var
        Setup: Record "DOPSWHS Setup";
        Tier: Enum "DOPSWHS License Tier";
        Required: Enum "DOPSWHS License Tier";
        ErrFeatureBlockedLbl: Label 'Feature %1 requires the %2 tier. Current license: %3.', Comment = '%1=feature, %2=required tier, %3=current tier';
        ErrLicenseInactiveLbl: Label 'License is not active (%1). %2', Comment = '%1=status, %2=message';
    begin
        EnsureRecentVerify();
        if not Setup.Get('') then exit;
        // Demo / pre-licensing mode: when no License Service URL is configured the
        // tenant runs unlicensed (permissive). Feature tier gates are NOT enforced
        // so demos can exercise every flow. As soon as a License Service URL is set
        // (i.e. licensing goes live in development/production), enforcement resumes.
        if Setup."License Service URL" = '' then exit;
        if not IsActive() then
            Error(ErrLicenseInactiveLbl, Format(Setup."License Status"), Setup."License Status Message");

        Tier := CurrentTier();
        Required := RequiredTierFor(Feature);
        if TierValue(Tier) < TierValue(Required) then
            Error(ErrFeatureBlockedLbl, Format(Feature), Format(Required), Format(Tier));
    end;

    procedure GuardSeats(SeatsToAdd: Integer)
    var
        Setup: Record "DOPSWHS Setup";
        DeviceReg: Record "DOPSWHS Device Registration";
        UsedSeats: Integer;
        Limit: Integer;
        ErrSeatsLbl: Label 'License seat limit reached (%1 of %2). Upgrade the license or remove inactive devices.', Comment = '%1=used, %2=limit';
    begin
        EnsureRecentVerify();
        if not Setup.Get('') then exit;
        if not IsActive() then exit;
        Limit := Setup."License Seats";
        if Limit <= 0 then exit;
        if DeviceReg.IsEmpty() then
            UsedSeats := 0
        else
            UsedSeats := DeviceReg.Count();
        if UsedSeats + SeatsToAdd > Limit then
            Error(ErrSeatsLbl, UsedSeats, Limit);
    end;

    procedure StatusBannerText(): Text
    var
        Setup: Record "DOPSWHS Setup";
        ActiveLbl: Label 'License active — %1 (%2 seat, expires %3)', Comment = '%1=tier, %2=seats, %3=date';
        InactiveLbl: Label 'License %1 — %2', Comment = '%1=status, %2=message';
    begin
        if not Setup.Get('') then exit('');
        if Setup."License Status" = Setup."License Status"::Active then
            exit(StrSubstNo(ActiveLbl, Format(Setup."License Tier"), Setup."License Seats", Format(Setup."License Expires At", 0, '<Day,2>/<Month,2>/<Year4>')));
        exit(StrSubstNo(InactiveLbl, Format(Setup."License Status"), Setup."License Status Message"));
    end;

    local procedure RequiredTierFor(Feature: Enum "DOPSWHS License Feature"): Enum "DOPSWHS License Tier"
    begin
        case Feature of
            Feature::PrintBridge: exit(Enum::"DOPSWHS License Tier"::Advanced);
            Feature::QualityMgmt: exit(Enum::"DOPSWHS License Tier"::Advanced);
            Feature::Production: exit(Enum::"DOPSWHS License Tier"::Enterprise);
            Feature::WebhookPublish: exit(Enum::"DOPSWHS License Tier"::Advanced);
            else
                exit(Enum::"DOPSWHS License Tier"::Essentials);
        end;
    end;

    local procedure TierValue(Tier: Enum "DOPSWHS License Tier"): Integer
    begin
        case Tier of
            Tier::Essentials: exit(0);
            Tier::Advanced: exit(1);
            Tier::Enterprise: exit(2);
        end;
        exit(0);
    end;

    local procedure TryVerify(Force: Boolean): Boolean
    var
        Setup: Record "DOPSWHS Setup";
        Client: HttpClient;
        Content: HttpContent;
        Response: HttpResponseMessage;
        ContentHeaders: HttpHeaders;
        ResponseText: Text;
        ResponseJson: JsonObject;
        ValidValue: JsonToken;
        TierTxt: Text;
        SeatsTxt: Text;
        ExpiresTxt: Text;
        EmailTxt: Text;
        ReasonTxt: Text;
        Url: Text;
        BodyTxt: Text;
        TenantId: Text;
    begin
        if not Setup.Get('') then exit(false);
        if Setup."License Service URL" = '' then begin
            // Permissive Essentials mode: when no licensing-service URL is
            // configured the tenant runs on the most restrictive tier without
            // ever calling out. This is intentional so customers can install
            // the .app and operate the LP core flow before paid features /
            // licensing backend are wired up. They cannot promote to Advanced
            // or Enterprise without entering a key, so the gate is still safe.
            Setup."License Status" := Setup."License Status"::Active;
            Setup."License Tier" := Setup."License Tier"::Essentials;
            Setup."License Seats" := 0; // 0 = unlimited (seat guard exits when limit <= 0)
            Setup."License Status Message" := 'Running in permissive Essentials mode (no License Service URL).';
            Setup."License Last Verified At" := CurrentDateTime();
            Setup.Modify(true);
            exit(true);
        end;
        if Setup."License Key" = '' then begin
            UpdateStatus(Setup."License Status"::Invalid, 'No License Key configured.', 0DT, 0, '');
            exit(false);
        end;

        if (not Force) and (Setup."License Last Verified At" <> 0DT) then
            if (CurrentDateTime() - Setup."License Last Verified At" < VerifyEveryMs) then
                exit(IsActive());

        TenantId := GetAadTenantId();
        Url := RTrim(Setup."License Service URL", '/') + '/api/license/verify';
        BodyTxt := StrSubstNo('{"tenantId":"%1","key":"%2"}', TenantId, Setup."License Key");
        Content.WriteFrom(BodyTxt);
        Content.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');

        if not Client.Post(Url, Content, Response) then begin
            ApplyOfflineGrace(Setup);
            exit(IsActive());
        end;
        Response.Content().ReadAs(ResponseText);
        if not Response.IsSuccessStatusCode() then begin
            ApplyOfflineGrace(Setup);
            exit(IsActive());
        end;
        if not ResponseJson.ReadFrom(ResponseText) then begin
            UpdateStatus(Setup."License Status"::Invalid, 'Could not parse license response.', 0DT, 0, '');
            exit(false);
        end;
        if not ResponseJson.Get('valid', ValidValue) then begin
            UpdateStatus(Setup."License Status"::Invalid, 'License response missing valid flag.', 0DT, 0, '');
            exit(false);
        end;

        if not ValidValue.AsValue().AsBoolean() then begin
            ReasonTxt := ReadString(ResponseJson, 'reason');
            UpdateStatus(MapReason(ReasonTxt), StrSubstNo('Verification failed (%1)', ReasonTxt), 0DT, 0, '');
            exit(false);
        end;

        TierTxt := ReadString(ResponseJson, 'tier');
        SeatsTxt := ReadString(ResponseJson, 'seats');
        ExpiresTxt := ReadString(ResponseJson, 'expiresAt');
        EmailTxt := ReadString(ResponseJson, 'email');

        Setup.Get('');
        Setup."License Tier" := DecodeTier(TierTxt);
        Setup."License Seats" := DecodeInt(SeatsTxt);
        Setup."License Expires At" := DecodeDateTime(ExpiresTxt);
        Setup."License Email" := CopyStr(EmailTxt, 1, MaxStrLen(Setup."License Email"));
        Setup."License Status" := Setup."License Status"::Active;
        Setup."License Status Message" := '';
        Setup."License Last Verified At" := CurrentDateTime();
        Setup.Modify(true);
        OnFirstActivation(Setup);
        exit(true);
    end;

    /// <summary>
    /// Runs idempotent post-activation seeds that must NOT run during install
    /// (because they hit licensed feature guards). Called by TryVerify after
    /// the first successful verify; safe to invoke on every subsequent verify
    /// because each seed checks "already done" state.
    /// </summary>
    local procedure OnFirstActivation(var Setup: Record "DOPSWHS Setup")
    var
        Audit: Record "DOPSWHS Webhook Audit";
        Wizard: Codeunit "DOPSWHS Setup Wizard";
    begin
        // Only attempt webhook subscribe once per environment — avoids
        // re-registering on every hourly verify.
        Audit.SetRange("Event Type", 'subscribe');
        if not Audit.IsEmpty then exit;
        if Setup."Webhook Endpoint" = '' then exit;
        Wizard.SubscribeDefaultWebhooksAfterLicense();
    end;

    local procedure UpdateStatus(NewStatus: Enum "DOPSWHS License Status"; Message: Text; ExpiresAt: DateTime; Seats: Integer; Email: Text)
    var
        Setup: Record "DOPSWHS Setup";
    begin
        if not Setup.Get('') then exit;
        Setup."License Status" := NewStatus;
        Setup."License Status Message" := CopyStr(Message, 1, MaxStrLen(Setup."License Status Message"));
        if ExpiresAt <> 0DT then
            Setup."License Expires At" := ExpiresAt;
        if Seats > 0 then
            Setup."License Seats" := Seats;
        if Email <> '' then
            Setup."License Email" := CopyStr(Email, 1, MaxStrLen(Setup."License Email"));
        Setup."License Last Verified At" := CurrentDateTime();
        Setup.Modify(true);
    end;

    local procedure ApplyOfflineGrace(var Setup: Record "DOPSWHS Setup")
    var
        GraceUntil: DateTime;
    begin
        if Setup."License Last Verified At" = 0DT then begin
            UpdateStatus(Setup."License Status"::Invalid, 'License service unreachable; no prior verification.', 0DT, 0, '');
            exit;
        end;
        GraceUntil := Setup."License Last Verified At" + (GraceDays * 24 * 60 * 60 * 1000);
        if CurrentDateTime() <= GraceUntil then
            UpdateStatus(Setup."License Status"::Offline,
                StrSubstNo('Service unreachable; using cached verification until %1.', Format(GraceUntil, 0, '<Day,2>/<Month,2>/<Year4>')),
                0DT, 0, '')
        else
            UpdateStatus(Setup."License Status"::Expired,
                'Offline grace period exceeded. Reconnect to refresh license.', 0DT, 0, '');
    end;

    local procedure MapReason(Reason: Text): Enum "DOPSWHS License Status"
    begin
        case LowerCase(Reason) of
            'expired': exit(Enum::"DOPSWHS License Status"::Expired);
            'revoked': exit(Enum::"DOPSWHS License Status"::Revoked);
            'superseded': exit(Enum::"DOPSWHS License Status"::Revoked);
            else
                exit(Enum::"DOPSWHS License Status"::Invalid);
        end;
    end;

    local procedure ReadString(JObj: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if JObj.Get(KeyName, Token) then
            if not Token.AsValue().IsNull then
                exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure DecodeTier(Source: Text): Option Essentials,Advanced,Enterprise
    begin
        case LowerCase(Source) of
            'enterprise': exit(2);
            'advanced': exit(1);
            else
                exit(0);
        end;
    end;

    local procedure DecodeInt(Source: Text): Integer
    var
        Result: Integer;
    begin
        if Evaluate(Result, Source) then exit(Result);
        exit(0);
    end;

    local procedure DecodeDateTime(Source: Text): DateTime
    var
        Result: DateTime;
    begin
        if Source = '' then exit(0DT);
        if Evaluate(Result, Source, 9) then exit(Result);
        exit(0DT);
    end;

    local procedure GetAadTenantId(): Text
    var
        AzureAdTenant: Codeunit "Azure AD Tenant";
    begin
        // BC 28+ kaldırdı: Database.AadTenantId(). Yeni karşılığı codeunit
        // 417 "Azure AD Tenant".GetAadTenantId().
        exit(LowerCase(AzureAdTenant.GetAadTenantId()));
    end;

    local procedure RTrim(Source: Text; Char: Char): Text
    var
        L: Integer;
    begin
        L := StrLen(Source);
        while (L > 0) and (Source[L] = Char) do
            L -= 1;
        exit(CopyStr(Source, 1, L));
    end;
}
