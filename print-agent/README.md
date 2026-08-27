# bcwms-print-agent

Cross-platform print agent for BCWMSApp (Business Central → local network printers).

The agent polls the `print-relay` Azure Function on a fixed interval, claims
queued jobs for its configured printer, sends ZPL/ESC-POS/RAW directly or PDF
through the operating-system print path, and reports `Sent` / `Failed` status
back to Business Central via the same relay.

## Build

Requires Go 1.22+.

```bash
cd print-agent
go build -o bcwms-print-agent .
```

Cross-compile:

```bash
GOOS=windows GOARCH=amd64 go build -o build/bcwms-print-agent.exe .
GOOS=darwin  GOARCH=arm64 go build -o build/bcwms-print-agent-darwin-arm64 .
GOOS=linux   GOARCH=amd64 go build -o build/bcwms-print-agent-linux-amd64 .
```

## Config

`~/.bcwms-print-agent/config.json`:

```json
{
  "relayUrl": "https://bcwms-relay.azurewebsites.net",
  "tenantId": "default",
  "printerId": "WH-LP1",
  "secret": "abc123...64-char-hex-from-bc",
  "printerHandle": "ZDesigner-GK420t",
  "rawAddress": "192.168.10.45:9100",
  "pdfCommand": "C:\\Program Files\\SumatraPDF\\SumatraPDF.exe",
  "pdfArgs": ["-print-to", "{printer}", "-silent", "{file}"],
  "format": "ZPL",
  "pollIntervalSec": 5,
  "agentId": "agent-floor-1"
}
```

Run a separate config/process for each logical printer. A label-printer config
normally needs `rawAddress`; a Windows document-printer config normally needs
`printerHandle`, `pdfCommand`, and `pdfArgs`. The job's BC queue format is
authoritative; the legacy config `format` value is retained only for backward
compatibility.

`printerHandle`:
- **macOS/Linux**: the CUPS printer name (`lpstat -p` to list).
- **Windows PDF**: the exact Windows printer/driver name. Configure a
  non-interactive PDF renderer in `pdfCommand`/`pdfArgs`; `{printer}` and
  `{file}` are replaced without invoking a shell. The example uses SumatraPDF.
- **Windows ZPL/ESC-POS/RAW**: set `rawAddress` to `host[:port]` for direct
  socket printing (default port 9100). `printerHandle` remains the fallback for
  older agent configurations that only print raw labels.

PDF is never sent blindly to raw TCP 9100 on Windows. If `pdfCommand` is not
configured, the job is marked failed with an actionable error. On macOS/Linux,
PDF continues through the normal CUPS driver while ZPL/ESC-POS/RAW use `lp -o raw`.

`secret`: generated from BC → **Printer List → Generate Token**. Plain value
is shown once; only the SHA-256 hash is stored on the BC side. The relay keeps
the active plain value in Key Vault. The relay is the component that enforces
the HMAC secret. During rotation, update Key Vault, force the Function's Key
Vault reference to refresh/restart, then update and restart the agent. A BC-only
token change does not revoke the old relay secret.

Protect the config as a credential: Windows ACLs should grant only the service
account and Administrators; on macOS/Linux use `chmod 600 config.json`.

## Run

```bash
./bcwms-print-agent --config ~/.bcwms-print-agent/config.json
```

## Service installation

### Windows (NSSM)

```powershell
nssm install BcwmsPrintAgent "C:\Program Files\BcwmsPrintAgent\bcwms-print-agent.exe" --config "C:\ProgramData\BcwmsPrintAgent\config.json"
nssm start BcwmsPrintAgent
```

### macOS (launchd)

`/Library/LaunchDaemons/com.dynops.bcwms.print-agent.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.dynops.bcwms.print-agent</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/bcwms-print-agent</string>
    <string>--config</string>
    <string>/Library/Application Support/BcwmsPrintAgent/config.json</string>
  </array>
  <key>KeepAlive</key><true/>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
```

```bash
sudo launchctl bootstrap system /Library/LaunchDaemons/com.dynops.bcwms.print-agent.plist
```

### Linux (systemd)

`/etc/systemd/system/bcwms-print-agent.service`:

```ini
[Unit]
Description=BCWMSApp Print Agent
After=network.target

[Service]
ExecStart=/usr/local/bin/bcwms-print-agent --config /etc/bcwms-print-agent/config.json
Restart=always
User=bcwms

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now bcwms-print-agent
```

## Protocol

See `docs/print-bridge-protocol.md` (relay HTTP API, HMAC signing scheme).
