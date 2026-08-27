# Play Publisher Setup

`gradle-play-publisher` Closed Track upload yardımcısı için gerekli credentials.

## Secrets (CI'da bu klasör boş kalır — secrets repo'ya commit edilmez)

| Dosya | Kullanım |
|---|---|
| `play-service-account.json` | Play Console "Setup → API access" sayfasından oluşturulan service account JSON anahtarı |
| `keystore/upload-keystore.jks` | Play App Signing için upload keystore |
| `keystore/keystore.properties` | `storeFile=play/keystore/upload-keystore.jks` / `storePassword=...` / `keyAlias=upload` / `keyPassword=...` |

## CI'da
GitHub Actions release workflow'u şu secret'ları çözer:
- `PLAY_SERVICE_ACCOUNT_JSON` → `play/play-service-account.json`
- `ANDROID_KEYSTORE_BASE64` → base64 decode → `play/keystore/upload-keystore.jks`
- `KEYSTORE_PASSWORD`, `KEY_PASSWORD` → `play/keystore/keystore.properties`

Sonra:
```
./gradlew :app:publishReleaseBundle -PwithPlayPublisher
```

Build sırasında `withPlayPublisher` property'si verilmezse plugin
yüklenmez ve Play credentials gerekmez (yerel dev için ideal).

## Closed Track listesi
İlk müşteri admin gmail'leri Play Console → Internal/Closed testing →
Tester list olarak eklenir. Tester listesi propagation ~6 saat.
