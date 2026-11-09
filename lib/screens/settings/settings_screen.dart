import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _reset(BuildContext context) async {
    final ok = await showGameDialog<bool>(
      context,
      title: 'İLERLEMEYİ SIFIRLA',
      message: 'Tüm bölümler, yıldızlar, altın ve güçlendiriciler silinecek. Bu işlem geri alınamaz.',
      actions: const [
        DialogAction('SIFIRLA', true, palette: ButtonPalette.pink),
        DialogAction('VAZGEÇ', false, palette: ButtonPalette.navy),
      ],
    );
    if (ok == true && context.mounted) {
      await AppScope.read(context).resetAll();
      if (context.mounted) showToast(context, 'İlerleme sıfırlandı');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context);
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    size: 46,
                    palette: ButtonPalette.navy,
                    tooltip: 'Geri',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 14),
                  const Text('Ayarlar', style: AppText.title),
                ],
              ),
              const SizedBox(height: 20),
              GlassPanel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    _ToggleRow(
                      icon: Icons.vibration_rounded,
                      label: 'Titreşim',
                      value: p.hapticsOn,
                      onChanged: p.setHaptics,
                    ),
                    const _Divider(),
                    // Placeholder: there are no audio assets yet; the
                    // preference is saved for when sound is added.
                    _ToggleRow(
                      icon: Icons.volume_up_rounded,
                      label: 'Ses Efektleri',
                      value: p.soundOn,
                      onChanged: p.setSound,
                      soon: true,
                    ),
                    const _Divider(),
                    _ToggleRow(
                      icon: Icons.music_note_rounded,
                      label: 'Müzik',
                      value: p.musicOn,
                      onChanged: p.setMusic,
                      soon: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const GlassPanel(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    _InfoRow(icon: Icons.language_rounded, label: 'Dil', trailing: Text('Türkçe', style: AppText.body)),
                    _Divider(),
                    _InfoRow(icon: Icons.privacy_tip_rounded, label: 'Gizlilik Politikası', trailing: SoonBadge()),
                    _Divider(),
                    _InfoRow(icon: Icons.restore_rounded, label: 'Satın Alımları Geri Yükle', trailing: SoonBadge()),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GameButton(
                label: 'İLERLEMEYİ SIFIRLA',
                icon: Icons.delete_forever_rounded,
                height: 52,
                palette: ButtonPalette.pink,
                onPressed: () => _reset(context),
              ),
              const SizedBox(height: 20),
              const Center(child: Text('Ball Sort Party • v1.0.0', style: AppText.body)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: Colors.white.withValues(alpha: 0.12));
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.soon = false,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    return _InfoRow(
      icon: icon,
      label: label,
      badge: soon,
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.trailing, this.badge = false});

  final IconData icon;
  final String label;
  final Widget trailing;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Icon(icon, color: AppColors.turquoise),
          const SizedBox(width: 12),
          Flexible(child: Text(label, style: AppText.label.copyWith(fontSize: 15), overflow: TextOverflow.ellipsis)),
          if (badge) ...[const SizedBox(width: 8), const SoonBadge()],
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}
