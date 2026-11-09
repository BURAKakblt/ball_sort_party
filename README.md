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
  data/            PlayerProgress: altın, can, yıldız, günlük ödül, ayarlar (shared_preferences)
  core/            Tema, renkler, butonlar, diyaloglar, konfeti
  screens/         Ana menü, oyun, seviyeler, mağaza, koleksiyon, ayarlar, can bitti
tool/level_tool.dart   Seviye üretici + BFS ile optimum hamle (par) hesaplayıcı
```

## Henüz aktif olmayanlar ("YAKINDA" etiketli)

Reklam izle (+1 can / +50 altın), gerçek parayla altın paketleri, reklamsız sürüm,
satın alımları geri yükle, gizlilik politikası, ses efektleri ve müzik (tercih kaydediliyor ama ses dosyası yok),
özel top desenleri, 11+ bölümler.
