# Ball Sort Party — Bulut kayıt (Aşama 1)

Durum: **istemci altyapısı hazır, Firebase projesi bağlı değil.** Uygulama şu an
tamamen çevrimdışı çalışır; Ayarlar → Bulut Kayıt "Yapılandırılmadı" gösterir.
Hiçbir yerde sahte "eşitlendi" gösterilmez.

## Mimari

```
PlayerProgress (yerel, tek gerçek kaynak, offline-first)
   │  exportCloudProgress / applyCloudProgress (yalnızca ileri)
SyncService ── SyncOutbox (bekleyen değişiklik + yeniden deneme, kalıcı)
   │
   ├─ AuthService        → FirebaseAuthService (anonim + hesap bağlama)
   ├─ CloudRepository    → FirestoreCloudRepository (transaction ile birleştir+yaz)
   └─ EconomyApi         → FunctionsEconomyApi (callable, sunucu otoritesi) — henüz deploy yok
cloud_bootstrap.dart: Firebase init, App Check, emülatörler; hata → "yapılandırılmadı"
```

| Dosya | Görev |
|---|---|
| `lib/cloud/cloud_models.dart` | `CloudProgress`, `CloudLevelRecord` (ekonomi alanı YOK) |
| `lib/cloud/progress_merge.dart` | Cihazlar arası birleştirme kuralları |
| `lib/cloud/sync_outbox.dart` | Çevrimdışı bekleyen değişiklikler, üstel geri çekilme |
| `lib/cloud/sync_service.dart` | Eşitleme durumu ve akışı |
| `lib/cloud/cloud_backend.dart` | Arayüzler (Auth, Repository, EconomyApi) ve hata türleri |
| `lib/cloud/firebase_backend.dart` | Firebase uygulamaları |
| `lib/cloud/cloud_config.dart` | Mod (auto/emulator/off), App Check debug ↔ production |
| `lib/cloud/cloud_bootstrap.dart` | Başlatma; asla oyunu engellemez |
| `lib/firebase_options.dart` | **Yer tutucu** — `flutterfire configure` üzerine yazar |
| `firestore.rules`, `firebase.json`, `test-rules/` | Kurallar, emülatör, kural testleri |

## Firestore şeması

```
users/{uid}                     sunucu oluşturur (istemci: yalnız okur)
users/{uid}/progress/main       istemci yazar (doğrulanır, geriye gidemez)
  schema: 1
  unlockedLevel: int (1..51)
  levels: { "<n>": { stars: 1..3, sig: string, at?: int } }
  runs:   { "<n>": LevelRun JSON (status, layout, history, rev, at, …) }
  updatedAtMs: int, deviceId: string, serverUpdatedAt: serverTimestamp
users/{uid}/economy/state       SUNUCU yazar: coins, lives, nextLifeAt, items…
users/{uid}/purchases/{id}      SUNUCU yazar: mağaza makbuzları/hakları
```

İlerleme tek belgede tutulur: bir eşitleme = bir transaction (oku → birleştir → yaz),
böylece aynı anda eşitleyen iki cihaz birbirinin ilerlemesini silemez.

## Birleştirme kuralları (ilerleme asla geriye gitmez)

- Açık bölüm: en büyüğü. Temizlenmiş bölüm her zaman bir sonrakini açar.
- Yıldız: güncel dizilimde kazanılan kayıt, eski ("legacy") kaydı yener; ikisi de
  aynı türdeyse yüksek yıldız kazanır.
- Kayıtlı deneme: yüksek revizyon kazanır; eşitlikte **FAILED** kazanır (cihaz
  değiştirerek ücretsiz yeniden başlama yok). Başka cihazda bitirilen bölümün eski
  denemesi silinir.
- Değişmeli, birleşmeli, idempotent (300 rastgele senaryoyla test edilir).
- Buluttan gelen veri altın/can/eşya **vermez**; başka cihazda bitirilen bölüm burada
  "temizlendi" sayılır ama ilk tamamlama altını tekrar ödenmez.

## Sunucu otoritesi (ekonomi)

Altın, can, güçlendiriciler ve satın alma hakları istemci tarafından buluta yazılamaz
(`economy/*`, `purchases/*` → `allow write: if false`). Değişiklikler yalnızca Cloud
Functions (Admin SDK) üzerinden, istek + App Check doğrulandıktan sonra yapılabilir.

**Aşama 1'de fonksiyonlar yazılmadı/deploy edilmedi**: oyun ekonomisi bugünkü gibi
yereldir (cihaz değişince taşınmaz). `EconomyApi` sözleşmesi hazır:
`claimLevelReward(level, stars, requestId)`, `purchaseWithCoins(itemId, requestId)`.

## App Check

- Debug derleme + emülatör: Debug sağlayıcı (konsola debug token kaydedilir).
- Release derleme: Android Play Integrity, iOS App Attest (+DeviceCheck yedeği).
- Emülatör modunda App Check etkinleştirilmez (emülatörler zorlamaz).

## Yerel geliştirme (Emulator Suite) — gerçek proje gerekmez

```bash
npm install -g firebase-tools            # bir kez (~200 MB)
firebase emulators:start --project demo-ball-sort-party
flutter run --dart-define=CLOUD=emulator  # Android emülatörü için host 10.0.2.2 otomatik
# Kural testleri:
npm --prefix test-rules install
firebase emulators:exec --only firestore --project demo-ball-sort-party "npm --prefix test-rules test"
```

`demo-` önekli proje kimliği gerçek bir proje değildir; uygulamadaki `demoOptions`
yalnızca yerel emülatöre bağlanır, kimlik bilgisi değildir.

## Bilinen sınırlar

- **Anonim hesap cihaza bağlıdır.** Apple/Google hesabı bağlanmadan cihaz değişiminde
  veya uygulama silindiğinde bulut kaydı geri yüklenemez. Hesap bağlama altyapısı
  (`AuthService.link`) hazır; Apple/Google giriş eklentileri henüz eklenmedi.
- Kurallar haritadaki her yıldız değerini tek tek doğrulayamaz (döngü yok); bozuk
  değerler istemcide reddedilir ve ekonomiyi etkilemez.
- Firestore transaction'ı ağ ister; çevrimdışıyken değişiklikler yerelde bekler ve
  bağlantı gelince gönderilir.
