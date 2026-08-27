# bcwms-customer-portal

DynOps müşterilerinin BCWMSApp lisansını yönetip BC SaaS ortamlarına sürüm
push edebileceği SaaS portalı. Vite + React 19 + MSAL.js. Azure Static Web
App'e deploy.

## Yapı

```
customer-portal/
├── index.html              ← Vite entry
├── src/
│   ├── main.tsx            ← MsalProvider shell + route switcher
│   ├── styles.css          ← Same HSL token system as web/
│   ├── lib/
│   │   ├── msalConfig.ts   ← Multi-tenant common authority
│   │   └── portalApi.ts    ← licensing-service + api/ wrappers
│   └── modules/
│       ├── Dashboard.tsx
│       ├── Releases.tsx
│       ├── License.tsx
│       └── Downloads.tsx
└── api/                    ← Azure Static Web App attached Functions
    ├── releases/           ← Proxy GitHub Releases (5min cache)
    ├── trigger-update/     ← Calls BC Admin Center upgrade endpoint
    └── host.json
```

## Env değişkenleri

| Key | Yer | Açıklama |
|---|---|---|
| `VITE_PORTAL_CLIENT_ID` | build | AAD app registration client id (multi-tenant) |
| `VITE_PORTAL_AUTHORITY` | build | Default `https://login.microsoftonline.com/common` |
| `VITE_PORTAL_API_BASE` | build | Default `/api` (Static Web App attached Functions) |
| `PORTAL_GH_REPO` | api runtime | Default `DynOpsBC/WMS` |
| `PORTAL_GH_TOKEN` | api runtime | (opsiyonel) GitHub API rate limit için PAT |

## Local dev

```bash
pnpm install
pnpm dev
# Ayrı terminalde api:
cd api
pnpm install
pnpm start
```

## Deploy

Azure Static Web App seçilen GitHub repo'ya bağlandığında `release.yml`
otomatik deploy eder. Manuel:

```bash
swa deploy ./dist --api-location api --env production
```

Custom domain: `portal.bcwms.dynops.com` (CNAME → swa default URL).

## Tasarım

Token sistemi `web/src/styles.css` ile birebir aynı (HSL custom properties,
light/dark, Iris brand, Fraunces serif display). Tek tek dosyaları
güncellemek yerine `web/src/styles.css` üzerinde değişiklik yapılıp buraya
copy edilir.

## Güvenlik

- MSAL.js multi-tenant common authority — her müşteri kendi AAD
  tenant'ında oturum açar
- `trigger-update` endpoint'i BC Admin API'sini managed identity ile çağırır
- CSP `staticwebapp.config.json` içinde sıkı (sadece bilinen kaynaklar)
- Lisans JWT'si tarayıcıda saklanmaz — sadece "Lisans üret" sonrası bir kez
  textarea'da gösterilir, copy-paste sonrası unutulması gerekir
