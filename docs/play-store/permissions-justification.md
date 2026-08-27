# Android Permissions Justification

- `CAMERA`: required for barcode scanning in receiving, put-away, pick, ship, movement, count, production, and assembly workflows.
- `INTERNET`: required to authenticate with Microsoft Entra ID, call Business Central APIs, sync offline work, and send telemetry.
- `FOREGROUND_SERVICE_DATA_SYNC`: required for reliable background sync of warehouse transactions while the worker continues scanning.
- `POST_NOTIFICATIONS`: required for task assignment, sync failure, and push relay notifications on Android 13+.
- `USE_BIOMETRIC`: optional device unlock protection for signed-in warehouse sessions where configured by the tenant.

⚠️ Pre-submission action: verify permission declarations against the final release manifest and Play Console policy wording.
