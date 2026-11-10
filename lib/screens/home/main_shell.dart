import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/pressable.dart';
import '../collection/collection_screen.dart';
import '../levels/levels_screen.dart';
import '../shop/shop_screen.dart';
import 'home_tab.dart';

enum ShellTab { shop, levels, home, collection }

/// Root screen: tab content + bottom navigation.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  ShellTab _tab = ShellTab.home;

  void _select(ShellTab tab) {
    if (tab == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppScope.of(context).reduceMotion;
    final pages = {
      ShellTab.shop: const ShopScreen(),
      ShellTab.levels: const LevelsScreen(),
      ShellTab.home: HomeTab(onOpenShop: () => _select(ShellTab.shop)),
      ShellTab.collection: const CollectionScreen(),
    };
    return Scaffold(
      body: GradientBackground(
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: reduced ? 120 : 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => reduced
                    ? FadeTransition(opacity: animation, child: child)
                    : FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, 0.025), end: Offset.zero).animate(animation),
                          child: child,
                        ),
                      ),
                child: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]!),
              ),
            ),
            _BottomNav(current: _tab, onSelect: _select),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, required this.onSelect});

  final ShellTab current;
  final ValueChanged<ShellTab> onSelect;

  static const _items = [
    (ShellTab.shop, Icons.storefront_rounded, 'Mağaza'),
    (ShellTab.levels, Icons.grid_view_rounded, 'Seviyeler'),
    (ShellTab.home, Icons.home_rounded, 'Ana Sayfa'),
    (ShellTab.collection, Icons.sports_basketball_rounded, 'Koleksiyon'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottom),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2E2280), Color(0xFF17124A)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1.5,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          for (final (tab, icon, label) in _items)
            Expanded(
              child: _NavItem(
                icon: icon,
                label: label,
                active: tab == current,
                onTap: () => onSelect(tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: PressScale(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: active
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF5CF5E2), Color(0xFF14B8C9)],
                    )
                  : null,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.turquoise.withValues(alpha: 0.45),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: active ? 1.15 : 1,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(
                    icon,
                    size: 26,
                    color: active ? Colors.white : AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: AppSizes.minText,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
