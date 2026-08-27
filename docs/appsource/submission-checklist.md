# AppSource Submission Checklist

## AL Package

- ✓ Permission set audit script present.
- ✓ Admin permission set present.
- ✓ User permission set present.
- ✓ View permission set present.
- ✓ Object prefix audit script present.
- ✓ Translation coverage audit script present.
- ✓ Obsolete metadata audit script present.
- ✓ `features` includes `TranslationFile`.
- ✓ `features` includes `NoImplicitWith`.
- ✓ `resourceExposurePolicy.allowDownloadingSource` is false.
- ✓ `resourceExposurePolicy.allowDebugging` is false.
- ✓ Base Application dependency pinned to 24.0.0.0.
- ✓ Runtime set to 13.0.
- ✓ Supported locales include en-US, tr-TR, de-DE.
- ⚠️ Run AppSourceCop in final build runner.
- ⚠️ Run PerTenantExtensionCop in final build runner.
- ⚠️ Run CodeCop in final build runner.
- ⚠️ Upload compiled `.app` to Partner Center.
- ⚠️ Validate fresh Cronus install under 30 minutes.
- ⚠️ Reconcile any object range issues before final package.

## Listing

- ✓ English description drafted.
- ✓ Five key benefits drafted.
- ✓ Support info drafted.
- ✓ Screenshot requirements documented.
- ⚠️ Final 240 x 240 logo required.
- ⚠️ Five production screenshots required.
- ⚠️ Documentation URL must be live.
- ⚠️ Privacy URL must be final.
- ⚠️ License URL must be final.
- ⚠️ Support mailbox routing must be confirmed.

## Telemetry and Operations

- ✓ App Insights KQL dashboards added.
- ✓ Operations runbook added.
- ✓ Troubleshooting guide added.
- ✓ Security audit added.
- ⚠️ Production Application Insights connection must be configured.
- ⚠️ Alert rules must be deployed.
- ⚠️ Crashlytics RC crash-free evidence required.
- ⚠️ Battery test evidence required.
- ⚠️ UI automation nightly evidence required.
- ⚠️ Contract tests must pass against sandbox nightly.

## Android and Play Store

- ✓ Target API 35.
- ✓ Minimum API 26.
- ✓ R8 full mode enabled.
- ✓ Resource shrinking enabled for release.
- ✓ ProGuard rules added.
- ✓ Macrobenchmark module added.
- ✓ Data safety draft added.
- ✓ Permissions justification added.
- ⚠️ Release signing configuration must be supplied by CI secrets.
- ⚠️ Mapping file upload must be configured.
- ⚠️ Play Store privacy policy URL required.
- ⚠️ Closed testing track must include five testers.
- ⚠️ Zebra TC22 eight-hour test evidence required.
- ⚠️ Play screenshots and feature graphic required.

## CI/CD

- ✓ Contract workflow added.
- ✓ Release workflow added.
- ✓ Security scan workflow added.
- ✓ AL workflow invokes audit scripts.
- ⚠️ AL compiler runner must replace placeholder package step.
- ⚠️ Android signed APK build runner must replace placeholder asset.
- ⚠️ Web bundle build runner must produce real zip.
- ⚠️ Push relay package runner must produce real zip.
- ⚠️ Optional OIDC deployment secrets must be configured for deploy.
- ⚠️ Branch protection must be enforced in GitHub settings.

## Security

- ✓ STRIDE threat model documented.
- ✓ Token storage control documented.
- ✓ SQLCipher control documented.
- ✓ HMAC replay window documented.
- ✓ Permission separation documented.
- ✓ Audit trail documented.
- ✓ Device fingerprint binding documented.
- ✓ Per-tenant isolation documented.
- ⚠️ Pen test or security review signoff required.
- ⚠️ Production secret rotation runbook required.

## External Actions

- ⚠️ Final AppSource logo.
- ⚠️ Final AppSource screenshots.
- ⚠️ Public documentation portal.
- ⚠️ Privacy policy legal approval.
- ⚠️ License/EULA legal approval.
- ⚠️ Support SLA approval.
- ⚠️ AppSource Partner Center submission.
- ⚠️ Play Store closed testing launch.
- ❌ AppSource validation report not yet attached.
- ❌ Play Store tester completion evidence not yet attached.
