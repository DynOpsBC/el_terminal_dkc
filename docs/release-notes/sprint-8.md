# Sprint 8 Release Notes

Sprint 8 completes the v1.0 RC count and polish scope.

## Delivered

- Count workflow with count mode enum, header/line/counter tables, API pages, web client pages, variance review, variance report, and physical inventory journal integration.
- Warehouse Manager Role Center with live cue tiles for receipts, picks, shipments, late picks, unbuilt LPs, count discrepancies, and online devices.
- WI migration codeunit, migration map table, and migration wizard with graceful no-op behavior when WI is absent.
- Upgrade and entitlement codeunits for version-aware setup/cue seeding and device-limit telemetry.
- Android count domain entities, use cases, feature screens, MVI ViewModel, repository, sync op support, and localized strings for English, Turkish, and German.
- LP Browser SPA plus ControlAddIn bridge for tree rendering, drag-to-nest, print label, bin move, properties menu, and BC data loading.
- AL translations for Turkish and German count, role center, variance, and migration captions.
- AL tests for count creation, variance evaluation, posting, WI migration absence behavior, and an end-to-end receive-to-count management smoke path.

## Hardening Unblock

Sprint 9 hardening can start from the produced file set. Remaining validation should run in the Business Central and Android/Web toolchains on a supported build host, since this Mac environment intentionally did not run compile, Gradle, Vite, or Playwright commands.
