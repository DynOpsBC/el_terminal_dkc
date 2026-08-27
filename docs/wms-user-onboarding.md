# WMS User Onboarding

Yeni bir kullanıcıyı Business Central + DOPSWHS WMS uygulamasına nasıl
ekleyeceğin runbook'u. İki seviye var:

1. **BC tenant access** (Azure AD invite + BC license assign) — bir kez.
2. **WMS role assignment** (`DOPSWHS App User Role` kaydı) — her ortam
   için, kullanıcının erişeceği company bazında.

## 1. Tenant + BC user

BC sandbox tenant: `7fa2357e-26f2-4174-8e16-a713981356b8`
Environment: `CustomerSandbox` (veya `SandboxUS`).

1. M365 admin center → `Users → Add a user` ile kullanıcıyı tenant'a
   davet et (veya halihazırda davetliyse atla).
2. M365 admin center → `Licenses` → kullanıcıya `Dynamics 365 Business
   Central Premium` (veya Essential) lisansı ata.
3. BC `Users` page → `Get users from Microsoft 365` ile kullanıcı BC'ye
   sync edilir. User Name kolonunda `kaanodabas@dynamicsops.com` görünür.
4. (Opsiyonel) BC `Users` → kullanıcıya `D365 BUS PREMIUM` (veya
   `D365 BUS ESSENTIALS`) Permission Set'i ata.

## 2. WMS Role Assignment

`DOPSWHS App User Role` tablosu kullanıcıya WMS rolü atar (OPERATOR,
PICKER, RECEIVER, SHIPPER, COUNTER, QUALITY, INV_ADMIN). Üç yol:

### 2a. UI ile (en hızlı)

1. BC search → `App User Roles` veya `WMS App User` aç.
2. `New` ile yeni satır → User ID, Role Code, Priority.
3. Save.

### 2b. OData API ile (script / CI)

`page 72279 "DOPSWHS App User Role API"` (yeni — bu commit) `appUserRoles`
entity set'i sunar:

```http
POST https://api.businesscentral.dynamics.com/v2.0/{tenantId}/{env}/api/dynops/warehouse/v2.0/companies({companyId})/appUserRoles
Authorization: Bearer <token>
Content-Type: application/json

{
  "userId": "kaanodabas@dynamicsops.com",
  "roleCode": "INV_ADMIN",
  "priority": 100
}
```

### 2c. AL Install/Upgrade codeunit'inden (deployment'la birlikte)

Yeni müşteri sandbox'larında otomatik seed için
`al/src/Role/AppRoleSeed.Codeunit.al`'a `EnsureUserRole(...)` çağrısı
eklenebilir. Şu an INV_ADMIN role'ü `Is System = false` — yani sadece
admin manuel atar.

## Audit log — eklenen kullanıcılar

| Date       | User                          | Role       | Env             | Yetkilendiren   |
|------------|-------------------------------|------------|-----------------|-----------------|
| 2026-06-23 | kaanodabas@dynamicsops.com    | INV_ADMIN  | CustomerSandbox | denizcelan      |

> **Not:** Bu tablo deployment audit'ı içindir, gerçek ACL kaynağı değil
> (kaynak: BC içindeki `DOPSWHS App User Role` tablosu). Audit'a yeni
> satır eklerken aşağıdaki sıralamayı izle:
> 1. M365 invite kabul edildi mi?
> 2. BC `Users` listesinde user görünüyor mu?
> 3. WMS role atandı mı (UI / API)?
> 4. Audit tablosuna satır ekle.

## Verification

Yeni user'ı kontrol et:

```bash
# 1. BC tenant'ta görünüyor mu (admin token gerekir)
curl -H "Authorization: Bearer $TOK" \
  "https://api.businesscentral.dynamics.com/v2.0/<tenant>/<env>/api/v2.0/users?\$filter=userName eq 'kaanodabas@dynamicsops.com'"

# 2. WMS role atanmış mı
curl -H "Authorization: Bearer $TOK" \
  "https://api.businesscentral.dynamics.com/v2.0/<tenant>/<env>/api/dynops/warehouse/v2.0/companies(<cid>)/appUserRoles?\$filter=userId eq 'kaanodabas@dynamicsops.com'"
```

Mobil/web app'te kullanıcı kendi giriş yapıp `🩺 Sistem Sağlığı` panelini
çalıştırırsa "BC token saklı + warehouse/v2.0 ulaşılabilir" check'leri
PASS dönmelidir.
