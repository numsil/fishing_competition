import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/confirm_dialog.dart';

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
    final inactive = isDark ? const Color(0xFF555555) : const Color(0xFFAAAAAA);
    final navBg = isDark ? const Color(0xFF111111) : Colors.white;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    const navBarH = 60.0;
    const fabSize = 68.0;
    final totalNavH = navBarH + bottomPad;
    // ★ 이 숫자만 바꾸면 됩니다: 크면 위로, 작으면 아래로
    const fabOffsetFromBottom = 8.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (idx != 0) {
          context.go(AppRoutes.feed);
          return;
        }
        final shouldExit = await showConfirmDialog(
          context,
          title: '앱 종료',
          content: '앱을 종료하시겠습니까?',
          confirmText: '종료',
          confirmColor: AppColors.navy,
        );
        if (shouldExit) SystemNavigator.pop();
      },
      child: Scaffold(
        body: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── 콘텐츠 ──
          Positioned.fill(
            bottom: totalNavH,
            child: child,
          ),

          // ── 바텀 네비 + Nakstar 버튼 ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: totalNavH + fabSize,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // 다크 네비바
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: totalNavH,
                      decoration: BoxDecoration(
                        color: navBg,
                        border: Border(
                          top: BorderSide(
                            color: isDark
                                ? const Color(0xFF252525)
                                : const Color(0xFFE0E0E0),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(bottom: bottomPad),
                        child: SizedBox(
                          height: navBarH,
                          child: Row(
                            children: [
                              // 홈
                              _Tab(
                                icon: Icons.home_outlined,
                                activeIcon: Icons.home_rounded,
                                label: '홈',
                                active: idx == 0,
                                accent: accent,
                                inactive: inactive,
                                onTap: () => context.go(AppRoutes.feed),
                              ),
                              // 리그
                              _Tab(
                                icon: Icons.explore_outlined,
                                activeIcon: Icons.explore_rounded,
                                label: '리그',
                                active: idx == 1,
                                accent: accent,
                                inactive: inactive,
                                onTap: () => context.go(AppRoutes.league),
                              ),
                              // 중앙 FAB 공간
                              const Expanded(child: SizedBox()),
                              // 랭킹
                              _Tab(
                                icon: Icons.leaderboard_outlined,
                                activeIcon: Icons.leaderboard_rounded,
                                label: '랭킹',
                                active: idx == 3,
                                accent: accent,
                                inactive: inactive,
                                onTap: () => context.go(AppRoutes.ranking),
                              ),
                              // 프로필
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
                  ),

                  // ── Nakstar 플로팅 원형 버튼 ──
                  Positioned(
                    bottom: bottomPad + fabOffsetFromBottom,
                    child: GestureDetector(
                      onTap: () => context.go(AppRoutes.myLeague),
                      child: Container(
                        width: fabSize,
                        height: fabSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.neonGreen.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/nak_icon.png',
                            width: fabSize,
                            height: fabSize,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
            Icon(
              active ? activeIcon : icon,
              color: active ? accent : inactive,
              size: 24,
            ),
            const SizedBox(height: 3),
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
