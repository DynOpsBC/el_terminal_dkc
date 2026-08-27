# Android Coding Standards

- Use Kotlin `2.0.21`, AGP `8.6.1`, Compose, Hilt, and a single-activity architecture.
- Feature screens follow MVI: immutable state, explicit user intents, one-way data flow.
- Keep domain logic in `core-domain`; integrations belong in `core-network`, `core-auth`, `core-barcode`, and `core-printing`.
- Business Central posting actions are online-only unless a later sprint explicitly defines queue semantics.
- Scanner integrations expose a common abstraction and keep vendor-specific behavior isolated.
- Use stable route names and keep feature modules independent.
