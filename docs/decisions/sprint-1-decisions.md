# Sprint 1 Decisions

## LP factbox stubs

Item and Bin LP factboxes use the Business Central `Integer` source table with a single-row `SourceTableView` stub. Sprint 1 does not create LP header or LP line tables, so this keeps the Item Card and Bin Card page extensions compile-time independent from Sprint 2 LP schema while reserving the final page IDs and UI placement.

## Barcode regex edge cases

The default Bin and LP Template barcode rules support hyphenated warehouse codes. The Sprint 1 demo barcode `B-A01-01` requires the captured segment to allow hyphens, so the seeded AL rules and Android resolver both use `[\w-]+` for those captures. This keeps server/mobile parity and matches Business Central bin-code conventions better than bare `\w+`.

GS1-128 parsing is implemented as AI-aware extraction for AI `01`, `10`, `17`, `21`, and `00` instead of relying solely on generic capture-group regex behavior. This avoids AL regex portability issues around named groups while keeping the seeded regex text available for administration and documentation.

## Hardware SDK handling

Honeywell and Datalogic integrations are capability-aware placeholders for Sprint 1. Honeywell checks for the AIDC SDK with `Class.forName` and falls back to `FakeScanner` when the SDK is absent. Datalogic exposes the soft-trigger intent path and also falls back to `FakeScanner` until the vendor SDK is added. This lets generic devices, previews, and unit tests run without vendor SDK jars.
