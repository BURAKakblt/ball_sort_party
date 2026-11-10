# UI review — Visual Polish 1.0

iPhone 17 Pro simulator, same in-memory test progress (11 levels cleared,
level 12 on the board). `before/` = commit 5e95041, `after/` = this change.

| Screen | before | after |
|---|---|---|
| Ana menü | before/home.jpg | after/home.jpg |
| Oyun | before/game.jpg | after/game.jpg |
| Bölüm seçimi | before/levels.jpg | after/levels.jpg |
| Mağaza | before/shop.jpg | after/shop.jpg |
| Koleksiyon | before/collection.jpg | after/collection.jpg |
| Hediye kutuları | before/gifts.jpg | after/gifts.jpg |
| Başarı | before/win.jpg | after/win.jpg |
| Başarısızlık | before/fail.jpg | after/fail.jpg |
| Ayarlar | before/settings.jpg | after/settings.jpg |

## Findings from the audit → fix

1. Win / rescue overlays relied on an outer `Material`; placed elsewhere, all
   text fell back to the debug style (yellow double underline, visible in
   `before/win.jpg`, `before/fail.jpg`). → Overlays now carry their own Material.
2. Bottles looked like they floated. → Contact shadow, inner edge shading,
   thick-glass base highlight, lip glint, soft rim light.
3. A disabled button still showed a bright pink count badge (read as an
   alert). → Badge turns grey when the button is disabled.
4. Low-contrast dim text (~4.0:1) and 10–11 px labels. → Dim text ~5.6:1,
   smallest UI text 11–12 px.
5. Header buttons were 44 / 46 / 48 px on different screens. → One size (46).
6. Press feedback differed per control. → Shared press + spring-back
   (`PressScale`) on buttons, round buttons, level tiles and the tab bar.
7. The win jingle started ~1.5 s after the board celebration. → Plays when
   the celebration starts.
8. Bottle-complete burst used 26 particles. → 14 particles + one cheap
   expanding ring; win sparkles reduced, bottles pulse gold in sequence.
   Reduce motion: glow/cap only.
