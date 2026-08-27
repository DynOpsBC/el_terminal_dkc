# BCWMSApp — Faz Plan Dosyaları İndeksi

Bu klasör, master implementation plan'ın faz-faz parçalanmış halini içerir. Her dosya kendi başına okunabilir ve ilgili sprint çalışılırken referans olarak kullanılır.

## Master Plan

- [/Users/denizcelan/.claude/plans/business-central-i-in-gerekli-mossy-robin.md](/Users/denizcelan/.claude/plans/business-central-i-in-gerekli-mossy-robin.md) — onaylı master plan (kontekst + kararlar + tüm fazlar + referans materyaller)

## Sprint Faz Dosyaları (Yürütme sırasıyla)

| # | Dosya | Sprint Adı | Süre | Demo Çıktısı |
|---|---|---|---|---|
| 0 | [sprint-0-foundations.md](sprint-0-foundations.md) | Foundations | 2 hafta | Sandbox bağlantı + Android login round-trip |
| 1 | [sprint-1-inquiry-config.md](sprint-1-inquiry-config.md) | Inquiry + Config | 2 hafta | Item/Bin barkodundan kart görüntüleme |
| 2 | [sprint-2-license-plate-core.md](sprint-2-license-plate-core.md) | License Plate Core | 2 hafta | LP build → label → use uçtan uca |
| 3 | [sprint-3-receiving.md](sprint-3-receiving.md) | Receiving | 2 hafta | PO receipt + LP build mobilde |
| 4 | [sprint-4-putaway-movements.md](sprint-4-putaway-movements.md) | Put-Away + Movements | 2 hafta | Receipt → directed put-away → bin güncel |
| 5 | [sprint-5-picking.md](sprint-5-picking.md) | Picking | 2 hafta | Pick-to-LP + Stop LP + register |
| 6 | [sprint-6-shipping.md](sprint-6-shipping.md) | Shipping + Sales/Transfer | 2 hafta | Mobilden shipment post + packing slip |
| 7 | [sprint-7-production-assembly.md](sprint-7-production-assembly.md) | Production + Assembly | 2 hafta | Consumption + output → yeni LP |
| 8 | [sprint-8-count-polish-release.md](sprint-8-count-polish-release.md) | Count + Polish + Release | 2 hafta | Cycle count + variance review + post |
| H | [sprint-h-hardening.md](sprint-h-hardening.md) | Hardening + AppSource RC | 2 hafta | v1.0 RC release |

**Toplam:** 18 hafta (~4.5 ay) v1.0 RC'ye

## Referans Materyaller

Çapraz kesen detaylar master plan'da; gerektiğinde aşağıdaki başlıklara doğrudan başvur:

- **AL obje envanteri (~120 obje, ID dağılımı):** master §"Tam AL Obje Envanteri"
- **Android modül haritası (22 modül):** master §"Tam Android Modül Haritası"
- **API endpoint kataloğu (Custom API v2.0):** master §"Tam API Endpoint Kataloğu"
- **Web workstation tam plan:** master §"Web Workstation — Tam Plan"
- **Push Relay Azure Function spec:** master §"Push Relay Azure Function"
- **Test stratejisi:** master §"Test Stratejisi"
- **CI/CD pipeline detayları:** master §"CI/CD Pipeline"
- **Güvenlik + secrets:** master §"Güvenlik + Secrets Yönetimi"
- **Lokalizasyon iş akışı:** master §"Lokalizasyon İş Akışı"
- **Telemetri + performans:** master §"Telemetri + Performans"
- **WI 2.x migrasyon:** master §"WI Migrasyonu"
- **Hardening checklist:** master §"Hardening Checklist"
- **Risk register:** master §"Risk Kayıt Defteri"

## Onaylı Temel Kararlar

| Karar | Değer |
|---|---|
| Repo | `/Users/denizcelan/Documents/ClaudeCode/BCWMSApp` (bağımsız monorepo) |
| AL prefix | `DOPSWHS` |
| AL ID range | `72000-72099` baseline + `72100-72499` genişletme talebi |
| BC platform | 24.0.0.0 / runtime 13.0 / application 24.0.0.0 |
| Test sandbox | tenant `7fa2357e-26f2-4174-8e16-a713981356b8`, env `CustomerSandbox`, company `Demo Business Central` |
| Diller | en-US (kaynak), tr-TR, de-DE |
| Sprint odak | Önce BC AL (Sprint 0-2), sonra Android (Sprint 3+), Web Sprint 5+ |

## Her Sprint İçin Standart Bitiş Kriterleri (DoD)

Her sprint dosyasındaki kendi DoD'una ek olarak:

1. AL test runner ≥ %75 coverage, AppSourceCop warning = 0
2. Android `./gradlew testDebugUnitTest lintDebug` yeşil
3. CI yeşil (al-build, android-build, web-build workflow'ları)
4. Sandbox'a yeni `.app` deploy edildi ve demo akışı manuel çalıştı
5. Telemetri custom event'leri Application Insights'a düşüyor
6. Sprint demo notu `docs/release-notes/sprint-N.md` altına eklendi
