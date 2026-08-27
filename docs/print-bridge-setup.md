# Self-Hosted Print Bridge — Setup Guide

> **Legacy compatibility path.** New Windows installations should use
> [Azure Direct Print](azure-direct-print-setup.md). This document is retained
> for environments that already run the Go agent and Azure Function relay.

End-to-end setup of the BCWMSApp print bridge: register a printer in Business
Central, generate an agent token, deploy `bcwms-print-agent` to the workstation
that owns the printer, and verify both labels and standard BC reports.

> Architecture: BC Print Job Queue → Azure Function `print-relay` → local
> `bcwms-print-agent` → native OS printer. Direct BC SaaS → printer is not
> possible; the agent pulls jobs via HTTPS and signs every request with a
> per-printer HMAC secret.

The bridge has two producers but one delivery path:

- LP/item/bin labels are generated as ZPL by the terminal APIs.
- Standard BC reports and terminal receipt/shipment/pack documents are rendered
  as PDF. Active WMS printers are registered in BC as `DOPSWHS::<code>` and the
  standard report print event is persisted in the same Print Job Queue.

## 1. Configure BC

1. Open **Advanced WMS Setup**.
2. Set **Print Channel** = `Self-Hosted (Local Agent)`.
3. Optionally record **Print Relay URL** for administrators. The running agent
   uses `relayUrl` from its own config file.
4. Open **Printers** (action on the role center or Setup card) → **+ New**.
   Create separate logical rows when labels and documents use different
   physical devices:
   - `WH-LP1`: Format `ZPL`, Zebra/raw address, **Enable for BC Reports** off
   - `WH-A4`: Format `PDF`, OS driver queue, **Enable for BC Reports** on
   - Paper Width/Height: both `0` for A4, otherwise custom millimetres
   - Active: ✓
   The queue enforces this format declaration: current WMS labels require a
   `ZPL` row and standard/terminal documents require a `PDF` row.
   BC's Printer Handle/Hostname fields are administrative metadata; the local
   agent's own `printerHandle`/`rawAddress` values are the runtime destination.
5. Click **Generate Token** → copy the value shown once. Only the SHA-256
   hash is stored on the BC side. Also update the Key Vault print config and
   agent config whenever the secret is rotated.

## 2. Deploy the Azure Function

```bash
cd push-relay
pnpm install
pnpm build
func azure functionapp publish bcwms-relay
```

Required app settings (KeyVault refs recommended):

| key | value |
|-----|-------|
| `PRINT_TENANT_CONFIG_JSON` | Key Vault-backed JSON described below |

Use renewable client credentials (or the Function managed identity) instead
of pasting a short-lived bearer token:

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
        "WH-LP1": "<plain-label-token-from-bc>",
        "WH-A4": "<plain-document-token-from-bc>"
      }
    }
  }
}
```

The Bicep template enables a system-assigned identity, grants it Key Vault
Secrets User, and references both `tenant-config` and `print-tenant-config`.
The BC Entra application/service principal must be registered in BC and
assigned **DOPSWHS-PRINT-AGENT**. This dedicated set can only read/claim/update
print jobs and send printer heartbeats; it cannot generate printer tokens.
`bcBearer` remains a temporary backward-compatible option, not a production
configuration. If a customer-selected report replaces the seeded reports, the
terminal user/service account must also have Execute permission for that report.

## 3. Deploy the Local Agent

Cross-compile on a dev machine:

```bash
cd print-agent
GOOS=darwin  GOARCH=arm64 go build -o build/agent-mac-arm64 .
GOOS=linux   GOARCH=amd64 go build -o build/agent-linux-amd64 .
GOOS=windows GOARCH=amd64 go build -o build/agent.exe .
```

Drop the binary on the workstation that owns the printer and write
`~/.bcwms-print-agent/config.json` (or `/etc/bcwms-print-agent/config.json`
for a service install):

```json
{
  "relayUrl": "https://bcwms-relay.azurewebsites.net",
  "tenantId": "default",
  "printerId": "WH-LP1",
  "secret": "<token from BC>",
  "printerHandle": "ZDesigner-GK420t",
  "rawAddress": "192.168.10.45:9100",
  "pdfCommand": "C:\\Program Files\\SumatraPDF\\SumatraPDF.exe",
  "pdfArgs": ["-print-to", "{printer}", "-silent", "{file}"],
  "format": "ZPL",
  "pollIntervalSec": 5,
  "agentId": "agent-floor-1"
}
```

Restrict the config file to the service account because its `secret` authorizes
job reads, claims and status updates. On Windows use an ACL; on Unix use mode
`0600`. Run one agent process/config per logical printer.
For `WH-A4`, duplicate the config with its own token, set `printerId` to
`WH-A4`, set `printerHandle` to the Windows/CUPS document queue, and keep the
PDF command fields. The `WH-LP1` process uses `rawAddress`; its PDF fields are
ignored because BC only queues ZPL jobs to that logical row.

Printer resolution:

- macOS/Linux: `printerHandle` is the CUPS queue (`lpstat -p`). CUPS renders
  PDF; ZPL/ESC-POS/RAW are submitted with `lp -o raw`.
- Windows PDF: `printerHandle` is the exact Windows driver queue and
  `pdfCommand`/`pdfArgs` configure a non-interactive PDF renderer.
- Windows ZPL/ESC-POS/RAW: `rawAddress` is `host[:port]` (default 9100).
  PDF is deliberately never sent blindly to raw 9100.

Install as a service: see `print-agent/README.md` (NSSM / launchd /
systemd templates).

## 4. Smoke Test

1. For a ZPL printer, click **ZPL Test** on the Printer Card — a self-test job
   is queued. Test a PDF printer with a standard BC report in step 6.
2. Within `pollIntervalSec` the agent logs `job N printed (... bytes)`.
3. The label should physically print. BC → **Print Job Queue** moves to `Sent`.
4. From the web app: open **Yazıcılar**, mark `WH-LP1` as **Etiket** and
   `WH-A4` as **Belge**, then print an LP.
5. Repeat the same **Etiket / Belge** selection on the mobile terminal.
6. In BC **Printer Selections**, choose `DOPSWHS::WH-A4` for a report and
   print it. Confirm the queued job has format `PDF` and a non-zero payload.
7. From the terminal, enable the print checkbox while posting a warehouse
   shipment or receipt. Pack receipt printing uses the printer captured when
   the packing session starts.

The terminal passes the label selection for LP/item/bin output and the document
selection for receipt/shipment/pack PDFs. A Device Printer Mapping remains the
fallback when an older client sends no printer code.

Sent jobs are deleted after 30 days and failed jobs after 90 days by the daily
`DOPSWHS Print Queue Cleanup` job. Queued jobs are never purged automatically.

## 5. Failure Modes

| Symptom | Cause | Fix |
|---|---|---|
| `list jobs status=401` agent log | Agent and Key Vault secrets differ, tenant is wrong, clock skew, or agent/relay protocol versions differ | Update both secret stores, correct tenant/time, deploy matching v2 agent + relay |
| Status stays `Queued` indefinitely | Agent not running, wrong `printerId`, or job in `BCNative` channel | Check Print Channel = Self-Hosted on Setup; confirm agent log shows tick |
| Status `Failed` with `lp failed: ...` | Wrong `printerHandle` or printer offline | `lpstat -p` to verify, re-test |
| Status `Failed` with `dial X:9100` | Network printer unreachable from agent host | Validate firewall + IP |
| Windows PDF says `pdfCommand/pdfArgs` required | PDF renderer is not configured | Install/configure a non-interactive renderer and Windows printer driver |
| HTTP 502 from relay | BC OData authentication/permission failed | Check client credentials/managed identity and the dedicated BC permission set |
| Job is `Failed` after a temporary outage | Delivery attempt failed | For Self-Hosted jobs, open **Print Job Queue** and use **Retry Failed Job** |

## 6. Token Rotation

BC stores a hash for administration, while the relay enforces the active plain
secret from `PRINT_TENANT_CONFIG_JSON`. Rotation is therefore an orchestrated
change, not an atomic BC-only action:

1. Generate the new token in BC and keep the old agent running.
2. Update the Key Vault JSON.
3. Force an App Service Key Vault-reference refresh or restart the Function;
   do not rely on the normal reference cache interval.
4. Update the agent config, restart it, and verify an authenticated poll.

There can be a short maintenance window unless current/next secrets are managed
outside this basic configuration.

## 7. Multi-Printer Layout

Each printer is a distinct registry row with its own token. One agent per
host is the default; one agent can serve multiple printers if you create
one config + agent process per printer (no shared state).

## 8. Cost

- Azure cost depends on the selected hosting plan. The supplied Bicep uses an
  EP1 Elastic Premium plan; it is not consumption-plan pricing.
- KeyVault: ~$0.03 / secret / month.
- No PrintNode subscription.
