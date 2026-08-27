# Sprint 7 Decisions

## LP Auto-Match by Item

When a production consumption scan includes an LP and no component line is explicitly selected, the mobile flow auto-matches by item number only when exactly one released production component has that item. If multiple component lines match the same item, the API rejects the implicit match and requires the caller to select the component line.

This avoids silently splitting one LP across multiple BOM lines. Multi-component split remains a future enhancement because it needs deterministic allocation rules for lot/serial and shortage handling.

## Output to New LP Location and Bin

Output-to-new-LP uses the selected output bin from the mobile request when provided. If the request omits a bin, it falls back to the production order line bin. If the production line has no location, the DOPSWHS setup default location is used as the final fallback.

The LP is created with `DOPSWHS LP Management.Build`, the posted output item is added to the LP, and the LP is stopped into `Built` status.

## Assemble-to-Order Boundary

Sprint 7 supports assemble-to-stock as the primary mobile posting path. Assemble-to-order orders are allowed through the same wrapper only for component consumption tracking and standard Business Central posting semantics; DOPSWHS does not add custom output LP assignment or shipment reservation behavior for ATO in this sprint.

## Item Journal Posting

Production consume and output use direct item journal line creation followed by immediate standard posting. The implementation creates or reuses a DOPSWHS production journal batch and posts the single line directly.

Batch-then-post was deferred because offline queue replay needs idempotency keys and conflict resolution before multiple device-created journal lines can safely accumulate server-side.

## Queue-ability

`Consume` and `ReportOutput` are queue-able ops in `core-sync` because each operation has a narrow payload and can be retried independently against Business Central. The UI should still prefer online execution when available.

`PostAssembly` is online-only because standard assembly posting consumes current component availability and may be affected by reservations, assemble-to-order links, and document status changes after the device captured the action.

## Object IDs

The production and assembly management codeunits use the requested baseline IDs `72048` and `72049`. API pages use `72222`, `72223`, `72224`, and supporting assembly line API `72230`; page extensions use `72308` and `72309`, matching the sprint plan even though those page IDs are outside the original `72000-72099` baseline. A supporting production LP factbox page was added as `72081`.

Permission sets include the new executable pages and codeunits. Page extension objects are not separately listed because AL permission sets grant page/codeunit/table/report/query execution, not pageextension execution.
