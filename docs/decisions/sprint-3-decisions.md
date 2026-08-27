# Sprint 3 Decisions

## Receipt API Topology

`DOPSWHS Receipt API` is the parent API page for `receipts`. Receipt lines use a separate child API page, `DOPSWHS Receipt Line API`, exposed through the parent page part so `/receipts({no})/lines` follows the master endpoint catalog.

## LP Linkage

Mobile line confirmation writes the selected receiving LP into the warehouse receipt line package field while the LP is being built. `DOPSWHS Receipt Mgmt` snapshots that line-to-LP mapping before posting and writes it to the `LP No.` extension field on `Posted Whse. Receipt Line` after the standard `Whse.-Post Receipt` codeunit runs.

## Assigned User Storage

Receiving assignment uses the standard `Warehouse Receipt Header"."Assigned User ID"` field. No custom assignment table was introduced for Sprint 3.

## Legacy WI Event ID Strategy

`DOPSWHS Event Publisher Legacy WI` centralizes the compatibility publishers for the legacy WI event IDs: receipt document 50001, purchase order 50005, and transfer order 50013. The new Receipt API path fires the receipt publisher before mutations so legacy subscribers can observe the same document context.

## Receiving Queue Placement

`DOPSWHS Receiving Queue` is implemented as page 72082 with `PageType = ListPart`. Role Center placement is deferred to the Sprint 8 Warehouse Manager Role Center work, matching the master plan.

## ID Deviations

No requested Sprint 3 object ID was changed. The separate child line API page uses page ID 72227 because the master plan only reserves 72090 for the parent receipt API and 72220-72230 for additional API pages.
