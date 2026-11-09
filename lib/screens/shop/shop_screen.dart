import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_dialog.dart';
import '../../data/player_progress.dart';
import '../home/top_bar.dart';

/// Coin shop (working) + real-money / ad offers (placeholders, not integrated).
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context);

    void buy(bool Function() purchase, String done) {
      if (purchase()) {
        showToast(context, done);
      } else {
        showToast(context, 'Yeterli altının yok');
      }
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const TopResourceBar(),
          const ScreenTitle('Mağaza', icon: Icons.storefront_rounded),
          const _Section('GÜÇLENDİRİCİLER'),
          _ShopItem(
            icon: Icons.shuffle_rounded,
            color: AppColors.violet,
            title: '3x Karıştır',
            subtitle: 'Sahip olunan: ${p.shuffles}',
            price: Prices.shuffle3,
            onBuy: () => buy(p.buyShuffles, '3 karıştırma eklendi'),
          ),
          _ShopItem(
            icon: Icons.add_box_rounded,
            color: AppColors.gold,
            title: '3x Ekstra Şişe',
            subtitle: 'Sahip olunan: ${p.extraBottles}',
            price: Prices.extraBottle3,
            onBuy: () => buy(p.buyExtraBottles, '3 ekstra şişe eklendi'),
          ),
          _ShopItem(
            icon: Icons.favorite_rounded,
            color: AppColors.pink,
            title: 'Canları Doldur',
            subtitle: '${p.lives}/${PlayerProgress.maxLives} can',
            price: Prices.refillLives,
            onBuy: p.lives < PlayerProgress.maxLives
                ? () => buy(p.buyLifeRefill, 'Canların doldu!')
                : null,
          ),
          const _Section('ALTIN PAKETLERİ'),
          const _ShopItem(
            icon: Icons.savings_rounded,
            color: AppColors.gold,
            title: '1.000 Altın',
            subtitle: 'Gerçek ödeme henüz aktif değil',
            soon: true,
          ),
          const _ShopItem(
            icon: Icons.diamond_rounded,
            color: AppColors.turquoise,
            title: 'Mega Paket',
            subtitle: '5.000 altın + 10 güçlendirici',
            soon: true,
          ),
          const _Section('DİĞER'),
          const _ShopItem(
            icon: Icons.ondemand_video_rounded,
            color: AppColors.violet,
            title: 'Reklam İzle +50 Altın',
            subtitle: 'Ödüllü reklamlar henüz aktif değil',
            soon: true,
          ),
          const _ShopItem(
            icon: Icons.block_rounded,
            color: AppColors.pink,
            title: 'Reklamsız Sürüm',
            subtitle: 'Tek seferlik satın alma',
            soon: true,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
    child: Text(text, style: AppText.label.copyWith(color: AppColors.textMuted, letterSpacing: 1.2)),
  );
}

class _ShopItem extends StatelessWidget {
  const _ShopItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.price,
    this.onBuy,
    this.soon = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int? price;
  final VoidCallback? onBuy;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: GlassPanel(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, Color.lerp(color, Colors.black, 0.35)!],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.label.copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.body.copyWith(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (soon)
              const SoonBadge()
            else
              SizedBox(
                width: 96,
                child: GameButton(
                  label: '$price',
                  icon: Icons.monetization_on_rounded,
                  height: 44,
                  fontSize: 16,
                  palette: ButtonPalette.gold,
                  onPressed: onBuy,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
