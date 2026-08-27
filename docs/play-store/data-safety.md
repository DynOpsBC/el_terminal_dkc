# Google Play Data Safety

Data collected:

- Account identifiers: Microsoft Entra user ID and tenant ID for sign-in and audit.
- Device identifiers: registered device ID and device fingerprint for warehouse device binding.
- App activity: scan events, task confirmations, sync status, crash logs, and performance diagnostics.
- Photos or camera frames: camera access is used only for barcode scanning; images are not stored by default.

Data sharing:

- Business Central tenant APIs receive warehouse transaction data.
- Firebase and Application Insights receive diagnostics and telemetry when enabled.

Security:

- Tokens are stored with Android Keystore and EncryptedSharedPreferences.
- Local operational cache is encrypted with SQLCipher.
- Data is transmitted over HTTPS.

⚠️ Pre-submission action: align this draft with the final Google Play Console data-safety questionnaire.
