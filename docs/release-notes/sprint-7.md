# Sprint 7 Release Notes

## Added

- Production consumption API for released production order components with mobile-bound consume action.
- Production output API for routing line selection, output quantity, scrap quantity, runtime, and optional output-to-new-LP.
- `DOPSWHS Prod Mgmt` for direct consumption/output item journal posting, LP auto-match by item, output LP creation, telemetry, and integration events.
- Assembly API, assembly line API, and `DOPSWHS Assembly Mgmt` wrapper around standard `Assembly-Post`.
- Released Production Order and Assembly Order mobile action groups.
- Production LP factbox for in-progress/output LP visibility on released production orders.
- Android `feature-consume`, `feature-output`, and `feature-assembly` Compose screens, repositories, MVI state, and module providers.
- Android production and assembly domain entities/use cases.
- Sync operation types for queued consume and report output, with assembly posting kept online-only.
- Sprint 7 AL tests covering production consumption, output, output-to-LP, LP auto-match, assembly-to-stock, and end-to-end production flow.

## Changed

- Admin, User, and View permission sets now include Sprint 7 production/assembly APIs, factbox, and management codeunits.
- Feature consume/output/assembly Gradle files now depend on `core-sync` and coroutines alongside `core-domain` and Compose.

## Notes

- Output-to-new-LP uses the requested bin first, then production line bin, then setup default location as fallback context.
- LP consumption auto-match is intentionally single-match only; duplicate component item matches require explicit line selection.
