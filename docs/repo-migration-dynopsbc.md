# Repo Migration: `celandeniz/BCWMSApp` → `DynOpsBC/WMS`

**Tarih:** 2026-06-23
**Tür:** Kopya migration (transfer DEĞİL). Eski repo arşivlenir, yeni
DynOpsBC org repo canonical olur. CI secrets / branch protection /
webhook'lar elle taşınır.

## Yapıldı ✅

| # | İş | Sonuç |
|---|----|-------|
| 1 | DynOpsBC/WMS hedef repo oluşturuldu | denizcelan, GH UI |
| 2 | `git push dynops main` | `new branch main → main`, SHA `9ce2936` |
| 3 | `git push dynops --tags` | 7 tag (`v1.0-rc1`, `v1.7.7.0`..`v1.8.2.0`) |
| 4 | Local origin swap | `origin → DynOpsBC/WMS`, `celandeniz-archive → celandeniz/BCWMSApp` |
| 5 | Eski branch sil: `chore/isv-object-id-renumbering` | silindi |
| 6 | 22 dependabot branch push | tüm `dependabot/*` DynOpsBC/WMS'e |
| 7 | Doc + code'da URL update | `celandeniz/BCWMSApp` → `DynOpsBC/WMS` (sed) |

**Son durum:** DynOpsBC/WMS'te 24 branch + 14 tag. Local repo origin'i
DynOpsBC/WMS, celandeniz-archive backup remote olarak duruyor.

## Sıradaki manuel adımlar 🚧

GH CLI auth olmadığı için bu kalemler senin tarafında.

### A. Default branch'i değiştir + eski branch'i sil

1. <https://github.com/DynOpsBC/WMS/settings> → **Default branch** →
   `claude/nice-davinci-31rojn` → **`main`** seç → Update
2. <https://github.com/DynOpsBC/WMS/branches> → `claude/nice-davinci-31rojn`
   satırında 🗑 → Confirm

### B. CI secrets (Settings → Secrets and variables → Actions)

Eski `celandeniz/BCWMSApp` reposundan AYNI ADLA recreate:

| Secret adı | Açıklama |
|---|---|
| `AZURE_CREDENTIALS` | Azure SP JSON — push-relay + licensing deploy |
| `AZURE_FUNCTIONAPP_PUBLISH_PROFILE_*` | Function App publish profile/env |
| `LICENSE_ADMIN_TOKEN` | licensing-service admin endpoint koruması |
| `FCM_SERVICE_ACCOUNT_JSON` | Push-relay Firebase admin JSON |
| `GITHUB_TOKEN` | Otomatik gelir |

> Değer kopyalama yapmadan adları doğrula (Settings → Secrets'ta mask
> edilmiş listede). Bilinen secret'in değerini elinde tutmuyorsan Azure
> portalından yeniden çek.

### C. Environments

`production`, `staging` varsa Settings → Environments altında recreate.
Protection rules (required reviewer, wait timer) manuel.

### D. Branch protection

Settings → Branches → `main` rule:

- ✅ Require pull request reviews (1+ reviewer)
- ✅ Required status checks: `android`, `web`, `push-relay`, `licensing`,
  `customer-portal` (workflow `test-full.yml` job adları)
- ✅ Require branches to be up-to-date before merge
- ✅ Include administrators

### E. Webhooks

Eski repoda Azure webhook'u varsa Settings → Webhooks'tan recreate.

### F. Eski repo arşivle (opsiyonel)

`celandeniz/BCWMSApp` → Settings → General → **Archive this repository**.
Read-only mod, yeni issue/PR/push reddedilir. GitHub 301 redirect kurmaz.

## Tüketici taraflarına bilgi

### Local clone'lar (her geliştirici)

```bash
git remote set-url origin https://github.com/DynOpsBC/WMS.git
git fetch origin
git branch --set-upstream-to=origin/main main
```

### Azure Function App tag'leri

`sourceRepoUrl` etiketleri yeni URL'e güncellenmeli (manuel veya
`az functionapp config appsettings set`). Application Insights link'leri
eski adı tarihçeden gösterir, ekstra iş yok.

## Doğrulama

```bash
git ls-remote origin main          # 9ce2936... olmalı
git ls-remote --tags origin | wc -l  # 14
./tools/run-all-tests.sh --quick    # 7/7 PASS
```

## Rollback

Yeni repoda bir şey ters giderse:

- `celandeniz-archive` remote'una push'a devam edilebilir (eski repo
  hâlâ aktif, arşivlenmediyse)
- Yeni repo → Settings → Delete this repository → recreate

> **Önemli:** Branch protection aktif olduktan sonra `git push --force`
> reddedilir. Bu tetiklenmeden önce kritik adımları tamamla (B–E).
