# macOS'tan AL Build + Publish — ALTool runbook

CLAUDE.md'de yıllarca "macOS'ta AL compile/publish yok, sadece Windows AL
tooling" yazıldı. Microsoft Apr 2026'da **AL MCP Server + cross-platform
ALTool** çıkardı; .NET 8 üzerinde macOS arm64 dahil tüm OS'larda çalışıyor.

Bu runbook BCWMSApp paketinin macOS'tan SandboxUS sandbox'a publish
edilmesini adım adım kapsar.

## 1. ALTool kurulumu (bir kez)

### 1a. .NET 8 runtime

ALTool .NET 8 hedefli. macOS'ta zaten .NET 10 SDK varsa user-local 8
runtime'ı yan-yana kurabilirsin:

```bash
curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
chmod +x /tmp/dotnet-install.sh
/tmp/dotnet-install.sh --channel 8.0 --runtime dotnet     --install-dir $HOME/.dotnet
/tmp/dotnet-install.sh --channel 8.0 --runtime aspnetcore --install-dir $HOME/.dotnet
```

### 1b. ALTool NuGet paketi

```bash
dotnet tool install -g Microsoft.Dynamics.BusinessCentral.Development.Tools
# Kurulum sonrası `al` komutu PATH'e gelir (~/.dotnet/tools/al)
```

### 1c. PATH + DOTNET_ROOT

Her shell'de:

```bash
export DOTNET_ROOT=$HOME/.dotnet
export PATH=$DOTNET_ROOT:$HOME/.dotnet/tools:$PATH
al --version  # 17.0.34+ olmalı
```

`~/.zshrc` veya `~/.bashrc`'a ekle.

## 2. Symbol cache

`al/.alpackages/` cache klasöründe BC dependency symbol paketleri olmalı.
BCWMSApp için:

```
.alpackages/
  Microsoft_Application_24.0.0.0.app
  Microsoft_Base Application_24.0.0.0.app
  Microsoft_Business Foundation_28.0.0.0.app
  Microsoft_Quality_Management_28.1.49838.50065.app
  Microsoft_System Application_24.0.0.0.app
  Microsoft_System_24.0.0.0.app
```

Yoksa: VS Code AL extension → `AL: Download Symbols` ile bir kez çek.

## 3. Compile

```bash
cd /Users/denizcelan/Documents/ClaudeCode/BCWMSApp/al

# Tests klasörü ayrı bir AL extension'ı (id range farklı). Compile
# sırasında dışla, sonra geri al.
mv tests /tmp/bcwms-tests-backup

mkdir -p ../releases/al
al compile -- \
    /project:. \
    /packagecachepath:.alpackages \
    /out:../releases/al/DynOps_BCWMSApp_1.10.0.0.app \
    /errorsonlyinconsole

mv /tmp/bcwms-tests-backup tests
```

Başarılı: `releases/al/DynOps_BCWMSApp_1.10.0.0.app` (~380 KB).

## 4. Auth (interactive browser)

```bash
al auth login \
    --tenant 7fa2357e-26f2-4174-8e16-a713981356b8 \
    --environmentName SandboxUS \
    --environmentType Sandbox \
    --applicationFamily BusinessCentral \
    --usernameHint Deniz@dynamicsops.com
```

macOS default browser açar → MS oturum → MFA → "Continue" → MSAL token
cache (`~/.IdentityService/msal.cache`) yazılır → publish bu cache'i
reuse eder.

> **`MSAL Could not get access to the shared lock file` hatası alırsan:**
> kalın MSAL process'ler vardır. `pkill -f altool` + `--noCache` ile
> yeniden auth dene.

## 5. Publish

```bash
al publishapp \
    /Users/denizcelan/Documents/ClaudeCode/BCWMSApp/releases/al/DynOps_BCWMSApp_1.10.0.0.app \
    --tenant 7fa2357e-26f2-4174-8e16-a713981356b8 \
    --environmentName SandboxUS \
    --environmentType Sandbox \
    --applicationFamily BusinessCentral \
    --schemaUpdateMode ForceSync
```

Beklenen son satır:

```
Success: The package 'DynOps_BCWMSApp_1.10.0.0.app' has been published
to the server.
```

> `--schemaUpdateMode ForceSync` mevcut paketi override eder. İlk
> publish'te `Synchronize` da yeterli.

## 6. Doğrulama

Mobil app açıkken (veya curl ile) Sistem Sağlığı endpoint'lerini test
et:

```bash
TOKEN=$(az account get-access-token --resource https://api.businesscentral.dynamics.com --query accessToken -o tsv)
BASE=https://api.businesscentral.dynamics.com/v2.0/<tenant>/SandboxUS/api/dynops/warehouse/v2.0
CID=<companyId>

curl -s -H "Authorization: Bearer $TOKEN" "$BASE/companies($CID)/binContents?\$top=1" | head
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/companies($CID)/licensePlateTemplates?\$top=1" | head
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/companies($CID)/appUserRoles?\$top=1" | head
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/companies($CID)/items?\$select=no,inventory&\$top=1" | head
```

Her biri **HTTP 200** + JSON dönerse publish başarılı, app içinde 🩺
Sistem Sağlığı **9 ✅ + 1 ⏭** olur.

## 7. Sık karşılaşılan hatalar

| Hata | Sebep | Çözüm |
|---|---|---|
| `'key' is a keyword` | AL 17.0.34+ `key`'i reserved yaptı | Parametre adını `KeyName`/`ParamKey` yap |
| `object identifier '72101' is not valid` | Test codeunit ID range dışı | `tests/` klasörünü compile öncesi geçici taşı |
| `cannot exceed 30 characters` | Object adı >30 char | İsmi kısalt (örn "Self-Hosted Print Client" → "Self-Host Print Client") |
| `'Bin Content' does not contain a definition for 'Description'` | T7302'de field yok | Field referansını kaldır + Item'dan ayrı lookup yap |
| `DataClassification can only be used if FieldClass = 'Normal'` | FlowField'da DataClass attr | `DataClassification` satırını sil |
| `'Database' does not contain 'AadTenantId'` | BC 28+ API kaldırıldı | `codeunit "Azure AD Tenant".GetAadTenantId()` |
| `Could not get access to the shared lock file` | MSAL cache lock | `pkill -f altool` + `--noCache` ile re-auth |

## Notlar

- ALTool stdin buffer'lı çalışır — background mode'da device code prompt
  görünmeyebilir. Foreground veya `script -q ...` ile pseudo-tty kullan
- AL 17.0.34 (Mar 2026 release) **MCP server** olarak da çalışır:
  `al launchmcpserver` → STDIO MCP server. Bu modu Claude Code'a tanıtmak
  için `~/.claude/mcp.json` veya benzer config'e ekle
- Paket boyutu ~380 KB; 1-2 dakikada publish edilir
- Per-tenant extension disclaimer'ı `al publishapp` console output'una
  basar; ilk publish'ten önce oku
