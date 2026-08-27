# Sprint 5 Decisions

## Webhook Subscription Mechanism

`DOPSWHS Webhook Mgmt` records the intended `picks`, `licensePlates`, and `shipments` subscriptions in `DOPSWHS Webhook Subscription Audit`. The first implementation keeps subscription creation deterministic and auditable from the Setup Wizard; tenant-specific endpoint activation is handled by the push relay deployment.

## Polling vs SignalR

The Pick Board ships with 5-second polling against `/picks?$filter=status eq 'Open' or status eq 'InProgress'` and emits `RequestRefresh` to the AL host when the browser cannot reach the API directly. SignalR/Web PubSub negotiation is scaffolded in push-relay for the realtime path, but polling remains the default Sprint 5 runtime.

## Sync Conflict Resolution UX

Mobile 412/ETag failures are buffered in `DOPSWHS Sync Conflict Buffer` with client payload and server snapshot BLOBs. `DOPSWHS Sync Conflict List` is read-only for supervisor review in this sprint; resolve/discard actions are deferred until conflict merge policy is finalized.

## Short Pick Backorder Allocation

`NO_STOCK` is the default reason and allows backorder. `RegisterShortPick` adjusts `Qty. to Handle` and leaves standard Business Central warehouse registration/backorder logic in control instead of creating a custom allocation ledger.

## ControlAddIn Bridge Protocol

AL calls browser globals `SetData`, `SetLocale`, and `ApplyFilter`; the SPA also accepts equivalent `postMessage` messages. Browser-to-AL events are `Reassign(pickNo, userId)` and `RequestRefresh()`.

## HMAC Verification Window

Push relay verifies `aeg-sas-token` HMAC signatures with a 5-minute replay window. Expired signatures outside the window are rejected before dispatch to SignalR/Web PubSub or FCM.

## Object ID Deviations

The child Pick Line API uses page `72229`, matching the existing expanded API child-page pattern. `DOPSWHS Sync Conflict Status` uses enum `72208`. AL permission syntax does not support page extension or control add-in permission entries, so permission sets grant the backing Sprint 5 tables, pages, and codeunits.
