# Sprint 4 Release Notes

## Added

- Put-away mobile API: page `72091` with child put-away line API page `72228`.
- Movement mobile API: page `72220`.
- Put-away strategy interface `72206` and default directed strategy codeunit `72044`.
- Movement management codeunit `72045` for ad-hoc item reclass moves and directed activity registration.
- Warehouse activity line LP fields via tableextension `72403`: `LP No.` and `Target LP No.`.
- Warehouse activity page mobile actions via pageextension `72306`.
- Android put-away and movement domain entities, use cases, sync ops, repositories, viewmodels, and Compose screens.

## Key Behaviors

- Suggested bin uses zone rank, bin rank, capacity, item-category mixing, then bin code alpha order.
- Ad-hoc movement creates isolated `DOPS-<user>` item reclass journal batches instead of a shared scanner batch.
- Directed put-away and movement registration wrap standard `Whse.-Activity-Register`.
- LP scan on put-away activity lines can fill matching sibling lines for the same activity document.

## Known Limitations

- Strategy selection is implemented through the interface pattern; setup-driven strategy selection is deferred because Sprint 4 did not authorize setup table/page edits.
- Android repositories follow the existing Sprint 3 lightweight sample-backed implementation style until the network layer grows typed request helpers.
