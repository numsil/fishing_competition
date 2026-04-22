import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key, required this.child});
  final Widget child;

  int _tabIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith(AppRoutes.feed)) return 0;
    if (path.startsWith(AppRoutes.league)) return 1;
    if (path.startsWith(AppRoutes.myLeague)) return 2;
    if (path.startsWith(AppRoutes.ranking)) return 3;
    if (path.startsWith(AppRoutes.profile)) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idx = _tabIndex(context);
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final inactive = isDark ? const Color(0xFF555555) : const Color(0xFFAAAAAA);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF222222) : const Color(0xFFF0F0F0),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                _Tab(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: '홈',
                  active: idx == 0,
                  accent: accent,
                  inactive: inactive,
                  onTap: () => context.go(AppRoutes.feed),
                ),
                _Tab(
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore_rounded,
                  label: '리그',
                  active: idx == 1,
                  accent: accent,
                  inactive: inactive,
                  onTap: () => context.go(AppRoutes.league),
                ),
                // 나의 리그 (중앙 강조)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.go(AppRoutes.myLeague),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 32,
                          decoration: BoxDecoration(
                            color: idx == 2
                                ? accent
                                : accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.workspace_premium_rounded,
                                size: 16,
                                color: idx == 2
                                    ? (isDark ? Colors.black : Colors.white)
                                    : accent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '나의리그',
                          style: TextStyle(
                            fontSize: 10,
                            color: accent,
                            fontWeight: idx == 2 ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _Tab(
                  icon: Icons.leaderboard_outlined,
                  activeIcon: Icons.leaderboard_rounded,
                  label: '랭킹',
                  active: idx == 3,
                  accent: accent,
                  inactive: inactive,
                  onTap: () => context.go(AppRoutes.ranking),
                ),
                _Tab(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: '프로필',
                  active: idx == 4,
                  accent: accent,
                  inactive: inactive,
                  onTap: () => context.go(AppRoutes.profile),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.accent,
    required this.inactive,
    required this.onTap,
  });
  final IconData icon, activeIcon;
  final String label;
  final bool active;
  final Color accent, inactive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon,
                color: active ? accent : inactive, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: active ? accent : inactive,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
