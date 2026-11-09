# Ball Sort Party

Flutter + Flame ile yazılmış, offline çalışan bir spor topu sıralama bulmacası (iOS & Android, dikey ekran).

## Çalıştırma

```bash
flutter pub get
open -a Simulator            # iPhone simülatörünü açar
flutter run                  # veya: flutter run -d "iPhone 17 Pro"
```

## Test & analiz

```bash
flutter analyze
flutter test
```

## Yapı

```
lib/
  game/engine/     Saf Dart kurallar motoru (GameState, GameEngine, Solver) – animasyondan bağımsız
  game/levels/     10 seviye (level_data.dart) + Level modeli
  game/render/     Prosedürel 2.5D top çizimi (görsel dosya yok)
  game/flame/      Flame tahtası: şişeler, toplar, animasyonlar, parçacıklar
  data/            PlayerProgress (kayıt), EconomyConfig (tüm fiyat/ödüller), GiftConfig (hediye olasılıkları)
  audio/           AudioService (müzik + efekt kanalları, kısma, arka plan) + audioplayers backend
  services/        RewardedAdService arayüzü (henüz gerçek reklam yok)
  core/            Tema, renkler, butonlar, diyaloglar, konfeti
  screens/         Ana menü, oyun, seviyeler, mağaza, koleksiyon, ayarlar, can bitti
tool/level_tool.dart   Seviye üretici + BFS ile optimum hamle (par) hesaplayıcı
tool/gen_audio.dart    Tüm müzik ve efektleri sıfırdan sentezler (assets/audio/CREDITS.md)
```

## Oyun kuralları (özet)

- Geçersiz hamle: hiçbir şey kaybettirmez; sallanma + hafif ses/titreşim.
- Hamle kalmadı (kesin çıkmaz) veya çözücü "çözüm yok" kanıtladıysa kurtarma ekranı açılır.
  Çözücü bütçesini aşarsa (bilinmiyor) ekran açılmaz. Ekranı açmak can düşürmez.
- Can yalnızca başarısızlık sonrası "Tekrar Dene" ile 1 azalır. Manuel yeniden başlatma ve
  menüye dönüş ücretsizdir. Can: en fazla 5, 20 dakikada 1 yenilenir.
- Ekstra şişe bölüm başına 1 kez (güçlendirici, 200 altınla kurtarma veya reklam ödülü — hangisi önce).
- Sürpriz hediye: 48 saatte bir 1 kutu; olasılıklar ekranda (ⓘ) gösterilir.

## Güvenlik notu

Ekonomi tamamen cihazda tutulur. Cihaz saatini değiştirmek can/hediye sayaçlarını
etkileyebilir, uygulama verisini silmek ilerlemeyi sıfırlar. Hile koruması için sunucu tarafı gerekir.

## Henüz aktif olmayanlar ("YAKINDA" etiketli)

Reklam izleyerek kurtarma / +1 can / +50 altın (RewardedAdService hazır, SDK yok), gerçek parayla
altın paketleri, reklamsız sürüm, satın alımları geri yükleme, gizlilik politikası, özel top desenleri, 11+ bölümler.
