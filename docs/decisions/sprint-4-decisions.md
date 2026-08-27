# Sprint 4 Decisions

## Put-Away Strategy Interface

`DOPSWHS PutAway Strategy` is an AL interface with a single `SuggestBin` method. The default implementation is `DOPSWHS Directed PutAway`, but the call shape is intentionally VAR-friendly: partner extensions can add alternate codeunits that implement the interface without changing the mobile API contract.

The strategy returns a Boolean and fills `BinCode` plus `Reason` by `var` parameters. This keeps API callers deterministic: success returns the selected bin, while no-bin-found is a graceful business result with an explanatory reason instead of an unhandled exception.

## Suggested Bin Algorithm

The default algorithm evaluates eligible bins by warehouse ranking:

1. Zone rank using the standard zone/bin ranking fields.
2. Bin rank within the selected zone.
3. Capacity check using item unit volume and existing bin contents.
4. Item mixing rule: do not mix different item categories in the same bin.

When ranks are otherwise equal, bin code alpha order is the deterministic tie-breaker. If no bin qualifies, the strategy logs telemetry and returns `false` with a no-bin-found reason.

## Journal Batch Isolation

Ad-hoc movement uses a per-user item reclass journal batch named `DOPS-` plus the first five sanitized characters of the user id, capped to the Business Central `Code[10]` batch name length.

No hardcoded shared batch is used. This protects concurrent scanner sessions from deleting, posting, or modifying another user device's journal lines. The Sprint 4 isolation test asserts distinct batch names and verifies clearing one user's lines does not affect the other user's batch.

## Ad-Hoc Move Posting

Ad-hoc moves post through Item Reclass Journal lines and codeunit `Item Jnl.-Post`. This is the correct fit for quick operator-initiated bin-to-bin moves that do not need a directed warehouse movement document lifecycle.

Directed movement remains separate: existing warehouse activity movement documents are registered through `Whse.-Activity-Register`, preserving the standard BC workflow for planned movement work.

## LP Fields on Activity Lines

`LP No.` and `Target LP No.` were added to `Warehouse Activity Line` so put-away and movement flows can carry source and destination license plate context without creating a custom activity line table. The `LP No.` validate path auto-fills sibling activity lines whose items are present on the scanned LP.

## Sprint 4 Deviations

The existing repository permission set files are named `AdminPermissionSet.al`, `UserPermissionSet.al`, and `ViewPermissionSet.al`, so Sprint 4 permissions were added there instead of creating duplicate `DOPSWHSAdmin.PermissionSet.al` style files.

AL permission sets grant executable access to the new API pages and codeunits. Table extensions, page extensions, and interfaces do not have standalone permission entries in AL permission syntax.
