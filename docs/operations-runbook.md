# BCWMSApp Operations Runbook

## Scope

This runbook covers v1.0 RC operations for Business Central AL APIs, Android mobile clients, embedded SPAs, and the Azure Function push relay.

## Environments

Sandbox is used for AppSource validation, nightly Newman tests, UI automation, and safe data replay. Production uses customer tenants, production Application Insights, production Entra app registrations, and customer-specific support escalation.

Never replay production scans into sandbox without anonymizing tenant ID, user ID, item number, and license plate identifiers.

## First Response

1. Confirm tenant, company, user, device ID, app version, and workflow.
2. Check Application Insights failures for the tenant in the last 30 minutes.
3. Check Business Central extension version and feature flags.
4. Confirm whether the issue is isolated to one device, one user, one location, or all tenants.
5. Preserve telemetry correlation IDs before asking the user to retry.

## Scenario 1: Mobile Login Fails

Symptoms: Entra login succeeds but app returns to sign-in or shows API 401.

Diagnosis:

```kql
requests
| where timestamp > ago(1h)
| where resultCode in ("401", "403")
| summarize count() by cloud_RoleName, name, resultCode, bin(timestamp, 5m)
```

Actions: verify Entra app registration redirect URI, tenant ID, client ID, BC API permissions, user license, and BCWMS permission set assignment.

Rollback: disable new auth feature flag if recently changed; restore previous Entra app registration secret only through Key Vault rotation.

## Scenario 2: API Latency Above Target

Symptoms: p95 API latency above 1200 ms or scanner waits after confirm.

Diagnosis:

```kql
requests
| where timestamp > ago(2h)
| summarize p95=percentile(duration, 95), failures=countif(success == false) by name
| order by p95 desc
```

Actions: inspect endpoint, location code, record count, and BC throttling. Check heavy list pages for filters and verify FlowField usage.

Rollback: disable noncritical telemetry enrichment and route users to narrower location filters.

## Scenario 3: Push Notifications Stop

Symptoms: assignments do not reach devices until manual refresh.

Diagnosis:

```kql
traces
| where timestamp > ago(1h)
| where message has_any ("push", "webhook", "firebase")
| project timestamp, severityLevel, message, customDimensions
```

Actions: check Function App health, Firebase credential validity, webhook HMAC secret, and tenant push relay configuration.

Rollback: disable push relay for affected tenant and instruct users to use manual refresh until credentials are rotated.

## Scenario 4: Sync Conflict Spike

Symptoms: offline transactions remain pending or duplicate confirms are rejected.

Diagnosis:

```kql
customEvents
| where timestamp > ago(24h)
| where name == "AdvWMS.SyncConflict"
| summarize count() by tostring(customDimensions["TenantId"]), tostring(customDimensions["Reason"])
```

Actions: inspect device clock drift, duplicate barcode scans, stale task assignment, and whether the transaction was posted directly in Business Central.

Rollback: use Sync Conflict List to reject duplicates or requeue valid transactions.

## Scenario 5: License Plate Posting Fails

Symptoms: LP build, movement, or shipment posting fails with duplicate SSCC, item tracking, or bin errors.

Diagnosis:

```kql
customEvents
| where timestamp > ago(24h)
| where name startswith "AdvWMS.LP"
| where tostring(customDimensions["Result"]) == "Failure"
| project timestamp, name, customDimensions
```

Actions: check No. Series, barcode rules, item tracking policy, bin existence, location setup, and warehouse document release status.

Rollback: reverse the warehouse journal or movement document where BC has posted inventory impact; otherwise delete the unposted LP document.

## Customer Escalation

Collect tenant ID, environment, company, user, device ID, app version, exact barcode, UTC timestamp, screenshot, and correlation ID.

Escalate Severity 1 to <support@dynops.com> with subject `SEV1 BCWMSApp <tenant> <workflow>`. Include the customer contact, warehouse site, and production impact.

## Release Rollback

AL: unpublish only after customer approval; prefer disabling feature flags and reverting setup records.

Android: move affected Play track back to previous signed build.

Web SPA: redeploy previous static bundle and clear Business Central control add-in cache if needed.

Push relay: redeploy previous Function package and rotate webhook secrets if integrity is in question.
