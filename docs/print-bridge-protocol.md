# Self-Hosted Print Bridge — HTTP Protocol

The bridge has three HTTP endpoints exposed by the `push-relay` Azure
Function. The local agent (`bcwms-print-agent`) is the only client.

## Auth

Every request from the agent carries four headers:

| Header | Value |
|---|---|
| `X-Bcwms-Printer-Id` | printer code registered in BC (`WH-LP1`) |
| `X-Bcwms-Timestamp` | unix epoch seconds (server tolerates ±5 minutes) |
| `X-Bcwms-Nonce` | cryptographically random, single-use hex value |
| `X-Bcwms-Signature` | lowercase hex HMAC described below |

`secret` is the per-printer token issued by BC (Printer Card → Generate
Token). The plain value is shown once and must be stored in Key Vault and the
agent configuration; BC stores only its SHA-256 hash. The relay, not that BC
hash, enforces agent authentication.

Canonical request:

```text
<UPPERCASE_METHOD>
<URL_PATH>
<CANONICAL_QUERY>
<RAW_BODY>
```

The signature input is `<timestamp>.<nonce>.<canonical-request>`. Query keys
are URL-encoded and sorted by Go `url.Values.Encode()`. The relay verifies the
exact raw encoded query instead of re-serializing it. Method, path, query,
nonce and body are therefore all bound to the signature. The relay also
requires `X-Bcwms-Printer-Id` to equal the `printer` query parameter.

Signature must use lowercase hex. The relay rejects with `401 invalid
signature` on mismatch or clock skew >300s.

## Endpoints

### `GET /api/print-jobs?agent=<agent>&printer=<code>&tenant=<id>&top=<n>`

Returns up to `n` (default 10) jobs in `Queued` status for the given
printer.
The relay also records a throttled printer heartbeat in BC.

```json
{
  "ok": true,
  "jobs": [
    {
      "jobId": 1234,
      "sourceDoc": "LP000001",
      "printerId": "WH-LP1",
      "channel": "SelfHosted",
      "format": "ZPL",
      "status": "Queued",
      "copies": 1,
      "payload": "XlhBXkZPNTAsNTBeQTBOLDQwLDQwXkZE...",
      "payloadSize": 138,
      "createdAt": "2026-06-15T13:42:11Z"
    }
  ]
}
```

`payload` is base64. The agent must `base64.decode()` before sending bytes
to the printer.

### `POST /api/print-jobs/{jobId}/claim?printer=<code>&tenant=<id>`

Body: `{ "agentId": "agent-floor-1" }`

Marks the job as claimed by this agent. A current claim returns 409. A claim
older than fifteen minutes is considered expired and may be acquired again.

### `POST /api/print-jobs/{jobId}/status?printer=<code>&tenant=<id>`

Body: `{ "status": "Sent" | "Failed", "message": "free text up to 250 chars", "agentId": "agent-floor-1" }`

On success the BC job moves to `Sent`/`Failed`, a `Print Job Log` entry is
appended (with the message), and on failure `Retry Count` is incremented
and `Last Error` is stored. BC accepts the status only when job printer and
claiming agent both match the signed request.

## Flow

```
agent.tick()
  ├─ GET /print-jobs?printer=…           → list
  ├─ for each job:
  │   ├─ POST /print-jobs/{id}/claim
  │   ├─ base64-decode(payload)
  │   ├─ printer.Print(format, bytes, copies)
  │   ├─ on success → POST /print-jobs/{id}/status { status: "Sent" }
  │   └─ on error   → POST /print-jobs/{id}/status { status: "Failed", message }
  └─ sleep(pollIntervalSec)
```

## BC OData (server-side, called by relay only)

The relay translates between the agent endpoints above and BC OData
actions on `printJobs` (page 72299) / `printerAgents` (page 72371):

| Agent action | BC OData |
|---|---|
| GET list | `GET /api/dynops/warehouse/v2.0/companies({id})/printJobs?$filter=channel eq 'SelfHosted' and status eq 'Queued' and printerId eq '{code}' ...` (active claims excluded until lease expiry) |
| Heartbeat | `POST /printerAgents('{code}')/Microsoft.NAV.heartbeat` |
| Claim | `POST /printJobs({jobId})/Microsoft.NAV.claimForPrinter` body `{ "agentId", "printerId" }` |
| Status Sent | `POST /printJobs({jobId})/Microsoft.NAV.markSuccessForPrinter` body `{ "message", "agentId", "printerId" }` |
| Status Failed | `POST /printJobs({jobId})/Microsoft.NAV.markFailureForPrinter` body `{ "message", "agentId", "printerId" }` |

The relay never exposes BC tokens to the agent.

## Tenant Config

`PRINT_TENANT_CONFIG_JSON` app setting:

```json
{
  "defaultTenant": "default",
  "tenants": {
    "default": {
      "bcBaseUrl": "https://api.businesscentral.dynamics.com/v2.0/<aad>/<env>",
      "bcCompanyId": "<guid>",
      "bcTenantId": "<aad-tenant-guid>",
      "bcClientId": "<app-guid>",
      "bcClientSecret": "<key-vault-secret>",
      "printerSecrets": {
        "WH-LP1": "<plain-secret>",
        "WH-LP2": "<plain-secret>"
      }
    }
  }
}
```

The relay acquires renewable BC access tokens with client credentials or
`DefaultAzureCredential`. A static `bcBearer` is supported only for migration.
The relay never writes these values to disk; use Key Vault references.

## Versioning

The canonical HMAC and ownership-checked status actions form protocol v2.
Upgrade the relay and agent together; a v1 agent will receive 401 from a v2
relay. Agents must tolerate unknown JSON response fields.

Delivery is **at least once**. A claim hides a job for fifteen minutes and each
agent caps a job at ten copies, but a crash after the OS accepted data and
before `markSuccess` can still cause a later duplicate. `Sent` means the OS
queue or raw socket accepted the job; it is not proof that paper exited the
printer unless separate device telemetry is configured.

The nonce replay cache lives in the Function process and retains an entry until
its signed timestamp expires. Claim ownership and idempotent terminal status
checks protect mutating operations across restarts, but installations that
scale the relay beyond one worker should replace this cache with an atomic
distributed nonce store.
