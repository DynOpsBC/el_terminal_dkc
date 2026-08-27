# Sprint 8 Decisions

## Count Sheet Design

Count uses separate header, line, and counter tables. This keeps multi-counter assignment independent from counted inventory lines and lets the system support two-counter visible counts and three-counter blind recount flows without reshaping line data.

## Variance Evaluation

Variance evaluation uses strict equality. In a three-counter sheet, any mismatch between counter slots marks the line as `Recount Required=true`; the posting path blocks until the recount flag is cleared or the counts agree.

## Warehouse Manager Cues

Warehouse Manager KPI tiles use live FlowField counts rather than cached aggregates. This is simpler to operate and acceptable for the expected warehouse scale in v1.0 RC.

## WI Migration

WI is not present in the sandbox, so migration methods return graceful no-op messages: preflight reports WI not detected, dry run reports zero rows, apply reports nothing to migrate, and rollback errors with the explicit unsupported-version message.

## Upgrade Codeunit

Upgrade uses the `ModuleInfo.DataVersion` pattern for version-aware migrations. The current database migration seeds default WI mapping metadata; per-company upgrade ensures setup and cue rows exist.

## Android i18n

The count feature uses Android resource strings and `stringResource()` in Compose screens instead of hardcoded UI labels for the user-facing count workflow.

## LP Browser Tree

The LP Browser tree fetches root LPs on load and lazy-loads children on first expand when a node does not already include child data. Drag-to-nest emits the ControlAddIn `NestLp` event.

## Object ID Pressure

`T72019` is used for `DOPSWHS Warehouse Mgr Cue`. The app range in `al/app.json` is `72000-72499`, so Sprint 8 support pages were placed in `724xx` where earlier sprint page IDs already occupied `7207x-7209x`. The requested `ControlAddIn 72500` remains outside the configured app range and should be reconciled before AppSource packaging if the range is not expanded.
