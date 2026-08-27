# AL Coding Standards

- Prefix all extension-owned objects and externally visible names with `DOPSWHS`.
- Use baseline object IDs `72000-72099` until the expanded range is approved.
- Keep `TranslationFile` and `NoImplicitWith` enabled.
- Prefer AppSource-compatible APIs and avoid source exposure in package metadata.
- Route telemetry through `DOPSWHS Telemetry`; event categories must start with `AdvWMS-`.
- Use integration events with stable names before and after business operations.
- Keep install and upgrade codeunits idempotent.
- Do not use hardcoded sandbox credentials or secrets.
