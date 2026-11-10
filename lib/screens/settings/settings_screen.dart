import 'package:flutter/material.dart';

import '../../app.dart';
import '../../audio/audio_service.dart';
import '../../cloud/sync_service.dart';
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
    final missing = AppScope.audioOf(context).missingAssets;
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
                    size: AppSizes.headerButton,
                    palette: ButtonPalette.navy,
                    tooltip: 'Geri',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 14),
                  const Text('Ayarlar', style: AppText.title),
                ],
              ),
              const SizedBox(height: 20),
              const _SectionLabel('SES'),
              GlassPanel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    _ToggleRow(
                      icon: Icons.music_note_rounded,
                      label: 'Arka Plan Müziği',
                      value: p.musicOn,
                      onChanged: p.setMusic,
                    ),
                    _VolumeRow(
                      label: 'Müzik seviyesi',
                      value: p.musicVolume,
                      enabled: p.musicOn,
                      onChanged: p.setMusicVolume,
                    ),
                    const _Divider(),
                    _ToggleRow(
                      icon: Icons.volume_up_rounded,
                      label: 'Efekt Sesleri',
                      value: p.soundOn,
                      onChanged: p.setSound,
                    ),
                    _VolumeRow(
                      label: 'Efekt seviyesi',
                      value: p.sfxVolume,
                      enabled: p.soundOn,
                      onChanged: p.setSfxVolume,
                      // Preview the level on release.
                      onChangeEnd: (_) => AppScope.audioOf(context).play(Sfx.coin),
                    ),
                  ],
                ),
              ),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 10),
                GlassPanel(
                  highlight: AppColors.pink,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Bazı ses dosyaları yüklenemedi:\n${missing.join('\n')}',
                    style: AppText.body.copyWith(fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const _SectionLabel('BULUT KAYIT'),
              const _CloudSaveCard(),
              const SizedBox(height: 16),
              const _SectionLabel('OYUN'),
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
                    _ToggleRow(
                      icon: Icons.motion_photos_off_rounded,
                      label: 'Animasyonları Azalt',
                      value: p.reduceMotion,
                      onChanged: p.setReduceMotion,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
    child: Text(text, style: AppText.label.copyWith(color: AppColors.textMuted, letterSpacing: 1.2)),
  );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _InfoRow(
      icon: icon,
      label: label,
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.onChangeEnd,
  });

  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 36),
        Expanded(
          child: Semantics(
            label: label,
            child: Slider(
              value: value,
              onChanged: enabled ? onChanged : null,
              onChangeEnd: onChangeEnd,
              activeColor: AppColors.turquoise,
              inactiveColor: Colors.white24,
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text('%${(value * 100).round()}', style: AppText.label, textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.trailing});


  final IconData icon;
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Icon(icon, color: AppColors.turquoise),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppText.label.copyWith(fontSize: 15), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

/// Honest cloud-save status: never claims a sync that didn't happen.
class _CloudSaveCard extends StatelessWidget {
  const _CloudSaveCard();

  @override
  Widget build(BuildContext context) {
    final sync = AppScope.syncOf(context);
    if (sync == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final (icon, color, title) = switch (sync.status) {
          SyncStatus.notConfigured => (Icons.cloud_off_rounded, AppColors.textMuted, 'Yapılandırılmadı'),
          SyncStatus.connecting => (Icons.cloud_queue_rounded, AppColors.textMuted, 'Bağlanıyor'),
          SyncStatus.syncing => (Icons.cloud_sync_rounded, AppColors.turquoise, 'Eşitleniyor'),
          SyncStatus.idle => (Icons.cloud_done_rounded, AppColors.turquoise, 'Eşitlendi'),
          SyncStatus.offline => (Icons.cloud_off_rounded, AppColors.gold, 'Çevrimdışı'),
          SyncStatus.error => (Icons.error_outline_rounded, AppColors.pink, 'Eşitleme hatası'),
        };
        final user = sync.user;
        final last = sync.lastSyncedAt;
        return GlassPanel(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: AppText.label.copyWith(fontSize: 15))),
                  if (sync.isConfigured)
                    TextButton(
                      onPressed: sync.status == SyncStatus.syncing ? null : () => sync.syncNow(force: true),
                      child: const Text('Şimdi eşitle'),
                    ),
                ],
              ),
              if (sync.detail != null) ...[
                const SizedBox(height: 6),
                Text(sync.detail!, style: AppText.body.copyWith(fontSize: 13)),
              ],
              if (sync.status == SyncStatus.idle && last != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Son eşitleme: ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}',
                  style: AppText.body.copyWith(fontSize: 13),
                ),
              ],
              if (sync.hasPendingChanges && sync.status != SyncStatus.notConfigured) ...[
                const SizedBox(height: 4),
                Text('Gönderilmeyi bekleyen değişiklikler var', style: AppText.body.copyWith(fontSize: 13)),
              ],
              if (user != null && user.isAnonymous) ...[
                const SizedBox(height: 8),
                Text(
                  'Misafir oyuncu: hesap bağlanmadan cihaz değişiminde veya uygulama silindiğinde kayıt geri yüklenemez.',
                  style: AppText.body.copyWith(fontSize: 13, color: AppColors.gold),
                ),
              ],
              const SizedBox(height: 10),
              const Row(
                children: [
                  Expanded(child: Text('Apple / Google hesabı bağla', style: AppText.label)),
                  SoonBadge(),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
