# Sprint 0 Decisions

## ADR-0001: AL Setup Page ID

Use page `72061` for `DOPSWHS Setup` to preserve low IDs for Sprint 1+ API and operational pages.

## ADR-0002: Print Channel Enum

The setup table requires a `Print Channel` enum field. AL does not support inline enum definitions, so Sprint 0 adds `al/src/Setup/PrintChannel.Enum.al` with conservative values `BC Native`, `PrintNode`, and `None`.

## ADR-0003: Android Module Layout

Use flattened Gradle module names (`:core-network`, `:feature-picking`, etc.) matching the user-approved deliverables. This differs from the master plan's illustrative nested `core/` and `feature/` directories.

## ADR-0004: Web Build Output

Configure Vite `outDir` to `../al/src/ControlAddIn/Resources/` so future control add-ins can reference bundled resources without copying artifacts.

## ADR-0005: AL Test App ID Range

Use the requested test app range `72090-72099`, even though it overlaps the baseline main app range. Future range expansion should resolve object pressure before AppSource validation.

## ADR-0006: Full Technical Spec Placeholder

The full external technical specification was not available as a repository file. A placeholder points to the master plan and Sprint plans until the spec can be added.

## Sprint 0 Plan-Alignment Corrections (Post-Scaffolding)

Renames performed for plan parity with the canonical Android module map:

- `core-data` to `core-db`: matches Sprint 0 `:core-db` database and offline persistence scope.
- `core-barcode` to `core-scanner`: aligns scanner abstraction with WI handheld parity, including camera, DataWedge, Honeywell, Datalogic, and keyboard wedge paths.
- `core-printing` to `core-printer`: matches the Sprint 2 print module naming used for PrintNode and ZPL flows.
- `core-ui` to `core-design`: matches the master plan design-system terminology.
- `feature-receiving` to `feature-receive`: matches the WI receive workflow naming.
- `feature-picking` to `feature-pick`: matches the WI pick workflow naming.
- `feature-shipping` to `feature-ship`: matches the WI ship workflow naming.
- `feature-stockcount` to `feature-count`: matches the WI count workflow naming.
- `feature-transfers` to `feature-move`: transfer/bin movement belongs to the move workflow in the v1 map.

Deleted modules because `§Tam Android Modül Haritası` excludes them as standalone v1 modules:

- `feature-crossdock`: cross-dock is not a separate v1 Android feature module.
- `feature-quality`: quality is not a separate v1 Android feature module.
- `feature-replenishment`: replenishment is not a separate v1 Android feature module.
- `feature-returns`: returns is not a separate v1 Android feature module.
- `feature-dashboard`: dashboard functionality is covered by home/workstation surfaces, not a standalone handheld module.
- `feature-settings`: settings is represented by `feature-config`.
- `feature-inquiry`: inquiry is split into `feature-itemInquiry` and `feature-binInquiry`.

Added modules for WI 2.3 parity:

- `core-sync`: offline-first sync queue and replay foundation.
- `feature-home`: WI handheld menu/home parity.
- `feature-config`: device configuration and connection profile parity.
- `feature-itemInquiry`: WI item inquiry parity.
- `feature-binInquiry`: WI bin inquiry parity.
- `feature-lp`: license plate build, stop, transfer, nesting, and label parity.
- `feature-consume`: production consumption parity.
- `feature-output`: production output parity.
- `feature-assembly`: assembly order parity.

Plan errata: the master plan mentions `22 modules`, but `§Tam Android Modül Haritası` enumerates 15 feature modules plus 8 core modules plus 1 app module, for 24 modules total. The canonical Android module count is therefore 24.

`core-sync` remains separate from `core-network` because offline-first behavior is not just transport. The sync queue, replay engine, conflict handling, WorkManager scheduling, and Room-backed persistence are persistence/reliability concerns. Keeping them separate preserves cleaner ownership for Sprint 2+ offline implementation.
