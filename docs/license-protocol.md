# BCWMSApp License Protocol

`licensing-service` Azure Function tarafından üretilen RS256 JWT'nin format,
endpoint sözleşmesi, BC + web + mobil entegrasyon adımları ve operasyonel
rotasyon planı.

## JWT claims

```jsonc
{
  "iss": "dynops.bcwms.licensing",
  "sub": "ce0a1e62-2bce-4b45-b88e-2f64f5a9b0d8", // license id (uuid)
  "tid": "7fa2357e-26f2-4174-8e16-a713981356b8", // BC AAD tenant
  "product": "BCWMSApp",
  "tier": "Essentials" | "Advanced" | "Enterprise",
  "seats": 50,
  "email": "admin@acme.com",
  "iat": 1781234567,
  "exp": 1812770567,
  "kid": "v3"
}
```

- **alg**: `RS256` (2048-bit RSA, SHA-256). Sembolik anahtar `kid` ile
  versiyon etiketlenir; key rotation `kid` artırarak yapılır.
- **iat / exp**: Unix saniye. BC verify path'i `exp <= now` veya
  `iat > now + 60s` → reddeder.
- **tid**: Verify çağrısında istemci kendi tenant'ını gönderir; uyumsuzluk
  → `tenant_mismatch` reason.
- **sub**: Table Storage'daki record id'si. `revoked` / `superseded` durumu
  imza geçerli olsa bile verify'i fail eder.

## Endpoint contracts

### `POST /api/license/issue`

| Header | Açıklama |
|---|---|
| `X-Bcwms-Admin-Token` | DynOps personel/portal admin secret'ı (zorunlu) |
| `Content-Type` | `application/json` |

Body:
```json
{
  "tenantId": "<aad guid>",
  "product": "BCWMSApp",   // default
  "tier": "Advanced",
  "seats": 12,
  "validUntil": "2027-06-15",
  "customerEmail": "ops@acme.com",
  "replaceActive": true
}
```

Response (200):
```json
{
  "ok": true,
  "id": "ce0a1e62-…",
  "tier": "Advanced",
  "seats": 12,
  "validUntil": "2027-06-15T00:00:00Z",
  "kid": "v3",
  "key": "eyJhbGciOiJSUzI1NiIs…"
}
```

Hata kodları: 400 (validation), 401 (admin token yok), 500 (internal).

### `POST /api/license/verify`

Anonim. Body:
```json
{ "tenantId": "<aad guid>", "key": "<jwt>" }
```

Response (200):
```json
{
  "ok": true,
  "valid": true,
  "tier": "Advanced",
  "seats": 12,
  "product": "BCWMSApp",
  "email": "ops@acme.com",
  "tenantId": "<aad guid>",
  "issuedAt": "2026-06-15T00:00:00Z",
  "expiresAt": "2027-06-15T00:00:00Z",
  "kid": "v3"
}
```

`valid:false` ile dönen `reason` değerleri:

| reason | Anlam |
|---|---|
| `format` | JWT 3-parçalı değil veya base64 decode başarısız |
| `signature` | İmza doğrulanamadı (key rotation gerekli olabilir) |
| `expired` | `exp <= now` |
| `not_yet_valid` | `iat > now + 60s` (clock skew) |
| `tenant_mismatch` | `tid` parametre tenant ile eşleşmiyor |
| `revoked` / `superseded` | Storage status active değil |
| `key` | Public key yüklenemedi |

### `GET /api/license/me?tenant=<id>`

İki kabul edilebilir auth:
1. `X-Bcwms-Admin-Token` (DynOps personel — full email + history)
2. `X-Bcwms-License-Key` veya `Authorization: Bearer <jwt>` (kendi
   tenant'ının JWT'si — email maskelenir)

Anonim çağrı → 401.

Response (200):
```json
{
  "ok": true,
  "tenantId": "<aad guid>",
  "active": {
    "id": "ce0a…",
    "tier": "Advanced",
    "seats": 12,
    "product": "BCWMSApp",
    "email": "op***@acme.com",
    "issuedAt": "...",
    "validUntil": "...",
    "status": "active"
  }
}
```

`active:null` → tenant için aktif lisans yok.

## BC entegrasyonu

- `Setup."License Service URL"` örn: `https://bcwms-licensing-func.azurewebsites.net`
- `Setup."License Key"` — JWT cargo (Text[2048])
- `DOPSWHS License Mgmt` codeunit:
  - Boot'ta + günde 1 kez `/verify` çağrısı
  - Başarılı → `License Status = Active`, claims persistance, status banner
    favorable
  - Network fail → 7 gün offline grace, `Status = Offline` (ambigous banner)
  - `valid:false` → `Status = Expired/Invalid/Revoked` per reason, unfavorable
    banner + read-only mode, kritik aksiyonlar bloklanır

Guard noktaları (örnekler):
- `DOPSWHS Device Registration.OnInsert` → `GuardSeats(1)`
- `DOPSWHS Print Dispatcher` SelfHosted branch → `GuardFeature(PrintBridge)`
- `DOPSWHS Prod Mgmt.Consume/ReportOutput` → `GuardFeature(Production)`
- `DOPSWHS Quality Mgmt Bridge.FindBlockingInspection` → `GuardFeature(QualityMgmt)`
- `DOPSWHS Webhook Mgmt.SubscribeWebhooks` → `GuardFeature(WebhookPublish)`

## Web + mobil entegrasyon

- Web SaaS bundle (`web/`): Login akışında `/me` çağrılır; tier'a göre tile
  enable/disable. JWT kullanıcıdan istenmiyor — BC entegrasyonu BC'den
  geliyor, web sadece görüntülemek için JWT'yi `localStorage` üzerinden
  okuyabilir.
- Mobil (`android/`): SharedPreferences'a tenantId + JWT cache, boot'ta
  `/me` poll. Offline 7 gün grace; aşılırsa core LP/Pick devam eder, sadece
  tier-gated feature'lar block.

## Key rotation

1. KeyVault → `license-signing-key` secret'a yeni version yükle
   (`az keyvault secret set …`).
2. `LICENSE_PRIVATE_KEY_SECRET` aynı kalır, secret versionunun ilk 8 karakteri
   `kid` olarak işlenir.
3. JWT üretimi anında yeni `kid` ile imzalar.
4. Eski `kid` ile imzalanmış JWT'lerin verify edilmesi için public key
   cache'inde eski versiyonu da tutarız (LICENSE_PUBLIC_KEY_PEM rotasyon
   sırasında her iki versiyonu içermeli — gelecek sprintte).
5. Tüm müşterilere portal üzerinden "Yeni anahtar üret" CTA gönderilir.
6. ≤ 6 ay sonra eski `kid`'i verify cache'inden düşür.

KeyVault soft-delete + 90 gün purge protection AÇIK (`infra/main.bicep`).
Anahtar kaybı senaryosunda owner break-glass admin rolü ile recovery.

## Test edilebilirlik

`licensing-service/test/jwtRoundtrip.test.ts`:
- Round-trip valid
- Tenant mismatch
- Expired
- `validUntil <= iat` reddedilir
- Bad signature
- Malformed

`pnpm test` → 6/6 PASS.
