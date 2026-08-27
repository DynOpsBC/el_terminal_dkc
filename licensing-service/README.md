# bcwms-licensing-service

DynOps BCWMSApp lisans omurgası. RS256 imzalı JWT üretir + doğrular. BC
extension, web SPA ve Android client'ı buradan tier/seat/expiry bilgisi alır.

## Endpoint'ler

| Method | Route | Auth | Görev |
|---|---|---|---|
| `POST` | `/api/license/issue` | `X-Bcwms-Admin-Token` header | DynOps personeli / customer portal yeni lisans üretir |
| `POST` | `/api/license/verify` | açık | İstemci JWT'yi tenant id ile birlikte doğrulatır |
| `GET`  | `/api/license/me?tenant={id}` | açık | Tenant'ın aktif lisansını çeker (cache friendly, 5dk private cache) |

## JWT claims

```json
{
  "iss": "dynops.bcwms.licensing",
  "sub": "license-uuid",
  "tid": "<aad tenant id>",
  "product": "BCWMSApp",
  "tier": "Essentials" | "Advanced" | "Enterprise",
  "seats": 50,
  "email": "admin@customer.com",
  "iat": 1781234567,
  "exp": 1812770567,
  "kid": "kv-version-prefix"
}
```

İmza algoritması RS256. Public key BC extension içine gömülmek yerine
`/license/verify` üzerinden online doğrulanır (key rotation kolay).

## Env değişkenleri

| Key | Açıklama |
|---|---|
| `LICENSE_KEYVAULT_URL` | KeyVault URI (prod) |
| `LICENSE_PRIVATE_KEY_SECRET` | KV secret adı (default `license-signing-key`) |
| `LICENSE_PRIVATE_KEY_PEM` | (dev/test) inline PEM, prod'da set edilmez |
| `LICENSE_PUBLIC_KEY_PEM` | (dev/test) inline PEM |
| `LICENSE_SIGNING_KID` | İmza versiyonu etiketi (default `kv`) |
| `LICENSE_STORAGE_ACCOUNT` | Storage account adı (managed identity ile auth) |
| `LICENSE_STORAGE_CONNECTION` | (dev) connection string, prod'da managed identity |
| `LICENSE_ADMIN_TOKEN` | `/issue` için secret bearer token |

## Local dev

```bash
cd licensing-service
pnpm install
# Test key pair üret (ya da kendin PEM yapıştır)
node -e "const c=require('node:crypto');const k=c.generateKeyPairSync('rsa',{modulusLength:2048});require('node:fs').writeFileSync('/tmp/priv.pem',k.privateKey.export({type:'pkcs8',format:'pem'}));require('node:fs').writeFileSync('/tmp/pub.pem',k.publicKey.export({type:'spki',format:'pem'}))"
export LICENSE_PRIVATE_KEY_PEM=$(cat /tmp/priv.pem)
export LICENSE_PUBLIC_KEY_PEM=$(cat /tmp/pub.pem)
export LICENSE_ADMIN_TOKEN="dev-admin"
export LICENSE_STORAGE_CONNECTION="UseDevelopmentStorage=true"
pnpm build
pnpm start
```

Issue & verify:

```bash
curl -s -X POST localhost:7071/api/license/issue \
  -H "Content-Type: application/json" \
  -H "X-Bcwms-Admin-Token: dev-admin" \
  -d '{"tenantId":"7fa2357e-26f2-4174-8e16-a713981356b8","tier":"Advanced","seats":12,"validUntil":"2027-06-15","customerEmail":"ops@acme.com"}' | jq

curl -s -X POST localhost:7071/api/license/verify \
  -H "Content-Type: application/json" \
  -d '{"tenantId":"7fa2357e-26f2-4174-8e16-a713981356b8","key":"<jwt-from-issue>"}' | jq
```

## Tests

```bash
pnpm test
```

JWT round-trip + tenant mismatch + expired + bad signature + malformed.

## Deploy

```bash
az group create -n bcwms-licensing-rg -l westeurope
az deployment group create -g bcwms-licensing-rg -f infra/main.bicep \
  -p name=bcwms-licensing ownerObjectId=$(az ad signed-in-user show --query id -o tsv)
```

Sonra:

```bash
func azure functionapp publish bcwms-licensing-func
```

KeyVault'a private key yükle (one-time):

```bash
openssl genrsa -out /tmp/license-priv.pem 2048
az keyvault secret set --vault-name bcwms-licensing-kv \
  --name license-signing-key --file /tmp/license-priv.pem
rm /tmp/license-priv.pem
```
