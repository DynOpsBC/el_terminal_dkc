# BCWMSApp Security Audit

## STRIDE Threat Model

Spoofing: attacker impersonates a warehouse worker or device. Controls: Microsoft Entra authentication, device fingerprint binding, tenant-scoped device registration, and permission set separation.

Tampering: attacker alters offline transactions, webhook messages, or LP data. Controls: SQLCipher local database encryption, HMAC webhook verification with a five-minute replay window, HTTPS-only APIs, and Business Central posting validation.

Repudiation: user denies posting warehouse work. Controls: LP Movement Ledger, Business Central Change Log, Application Insights correlation IDs, user/device IDs on scan events, and immutable posted warehouse records.

Information Disclosure: attacker accesses tokens, cached inventory, or tenant data. Controls: Android Keystore, EncryptedSharedPreferences, SQLCipher, least-privilege AL permission sets, and per-tenant blast radius isolation.

Denial of Service: malformed scans or push floods degrade operations. Controls: API throttling awareness, barcode validation, push relay retry limits, and operational KQL alerts.

Elevation of Privilege: view-only users post transactions or devices access another tenant. Controls: DOPSWHS ADMIN/USER/VIEW separation, Entra tenant checks, company scoping, and server-side permission enforcement.

## Key Controls

Tokens are stored with Android Keystore-backed EncryptedSharedPreferences. Local operational cache is encrypted with SQLCipher. Webhooks require HMAC signatures and reject timestamps older than five minutes to limit replay. Permission sets split administration, execution, and read-only access. Audit trail spans LP Movement Ledger, Business Central Change Log, and Application Insights telemetry. Device fingerprint binding links registered scanners to tenant/company setup. Tenant IDs, environments, secrets, and telemetry dimensions are isolated to limit cross-tenant blast radius.

## Residual Risks

Certificate pinning is off in v1.0 because Business Central SaaS certificate rotation can break customers without warning. v1.1 should evaluate configurable pinning or public key pinning for customer-managed endpoints.
