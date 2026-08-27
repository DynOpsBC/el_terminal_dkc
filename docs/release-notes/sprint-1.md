# Sprint 1 Release Notes

Sprint 1 adds inquiry and device configuration foundations across Business Central AL and Android.

## Added

- AL device configuration, menu, column, and registration tables/pages.
- AL barcode symbology and rule tables/pages, barcode parser, GS1 AI helper, and device registration handshake codeunit.
- Custom API pages for item inquiry, bin inquiry, device config/registration, and barcode parse.
- Item and Bin card extensions with LP factbox stubs that do not depend on Sprint 2 LP tables.
- Setup wizard seeding for the default device configuration and five default barcode rules.
- AL tests for barcode parser parity and device registration behavior.
- Android `:core-scanner` scanner abstractions, hardware scanner placeholders, offline barcode resolver, and beep provider.
- Android item inquiry, bin inquiry, device config, and home/menu feature surfaces.
- QR profile import parsing for `{tenant, env, company, deviceConfig}` connection profile payloads.
- Core domain entities and use cases for item, bin, barcode parsing, and device registration.

## Notes

- Bin and LP template barcode rules allow hyphenated values to support warehouse codes such as `B-A01-01` and `TPL-CARTON-S`.
- Honeywell and Datalogic SDKs are optional in Sprint 1; missing SDKs fall back to fake scanner behavior.
