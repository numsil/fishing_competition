import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/league_model.dart';
import '../../data/league_repository.dart';

class LeagueRankingTab extends ConsumerWidget {
  const LeagueRankingTab({
    super.key,
    required this.league,
    required this.isDark,
    required this.accent,
    this.showRegisterHint = false,
  });

  final League league;
  final bool isDark;
  final Color accent;
  /// 참가자 화면에서만 "아래 버튼으로 첫 조과를 등록해보세요!" 힌트 표시
  final bool showRegisterHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(leagueRankingProvider(league.id)).when(
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(LucideIcons.fish, size: 48,
                  color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub),
              const SizedBox(height: 12),
              Text('아직 조과 기록이 없습니다',
                  style: TextStyle(fontSize: 14,
                      color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub)),
              if (showRegisterHint && league.status == 'in_progress') ...[
                const SizedBox(height: 8),
                Text('아래 버튼으로 첫 조과를 등록해보세요!',
                    style: TextStyle(fontSize: 13, color: accent,
                        fontWeight: FontWeight.w600)),
              ],
            ]),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(leagueRankingProvider(league.id));
            ref.invalidate(leagueDetailProvider(league.id));
            ref.invalidate(isJoinedProvider(league.id));
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: entries.length,
            itemBuilder: (_, i) => LeagueRankCard(
              rank: i + 1,
              entry: entries[i],
              leagueId: league.id,
              rule: league.rule,
              catchLimit: league.catchLimit,
              isDark: isDark,
              accent: accent,
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('순위를 불러오지 못했습니다: $e')),
    );
  }
}

class LeagueRankCard extends StatelessWidget {
  const LeagueRankCard({
    super.key,
    required this.rank,
    required this.entry,
    required this.leagueId,
    required this.rule,
    required this.catchLimit,
    required this.isDark,
    required this.accent,
  });

  final int rank;
  final LeagueRankEntry entry;
  final String leagueId;
  final String rule;
  final int catchLimit;
  final bool isDark;
  final Color accent;

  Color get _rankColor {
    if (rank == 1) return AppColors.gold;
    if (rank == 2) return AppColors.silver;
    if (rank == 3) return AppColors.bronze;
    return isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
  }

  String get _mainValue {
    if (rule == '마릿수') return '${entry.totalCount}마리';
    if (rule == '무게') {
      return entry.totalLength > 0
          ? '${entry.totalLength.toStringAsFixed(0)}g'
          : '-';
    }
    if (catchLimit == 1) {
      return entry.bestLength != null
          ? '${entry.bestLength!.toStringAsFixed(1)}cm'
          : '-';
    }
    return entry.totalLength > 0
        ? '${entry.totalLength.toStringAsFixed(1)}cm'
        : '-';
  }

  String get _mainLabel {
    if (rule == '마릿수') return '마릿수';
    if (rule == '무게') return catchLimit == 1 ? '최대무게' : '무게합산';
    if (catchLimit == 1) return '최대어';
    if (catchLimit == 0) return '전체합산';
    return '합산(${catchLimit}마리)';
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return GestureDetector(
      onTap: () => context.push(
        '/league/participant/$leagueId/${entry.userId}',
        extra: LeagueParticipantArgs(entry: entry, rule: rule, catchLimit: catchLimit, rank: rank),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: rank == 1 ? AppColors.gold.withValues(alpha: 0.06) : cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: rank == 1
                ? AppColors.gold.withValues(alpha: 0.3)
                : isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: () => context.push('${AppRoutes.userProfile}/${entry.userId}'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(
                  username: entry.username,
                  avatarUrl: entry.avatarUrl,
                  radius: 21,
                  isDark: isDark,
                ),
                if (rank <= 3)
                  Positioned(
                    bottom: -3, right: -3,
                    child: Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        color: _rankColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.darkBg : Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(entry.username,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                if (entry.isLunker) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: AppColors.gold, borderRadius: BorderRadius.circular(4)),
                    child: const Text('런커', style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black)),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              Wrap(spacing: 8, children: [
                LeagueSubStat(icon: LucideIcons.fish, value: '${entry.totalCount}마리', sub: sub),
                if (catchLimit > 1 && entry.bestLength != null)
                  LeagueSubStat(
                    icon: rule == '무게' ? LucideIcons.scale : LucideIcons.ruler,
                    value: rule == '무게'
                        ? '최대 ${entry.bestLength!.toStringAsFixed(0)}g'
                        : '최대 ${entry.bestLength!.toStringAsFixed(1)}cm',
                    sub: sub,
                  ),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              _mainValue,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: rank == 1 ? AppColors.gold : accent,
              ),
            ),
            Text(_mainLabel, style: TextStyle(fontSize: 10, color: sub)),
          ]),
        ]),
      ),
    );
  }
}

class LeagueSubStat extends StatelessWidget {
  const LeagueSubStat({super.key, required this.icon, required this.value, required this.sub});
  final IconData icon;
  final String value;
  final Color sub;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: sub),
      const SizedBox(width: 3),
      Text(value, style: TextStyle(fontSize: 11, color: sub)),
    ]);
  }
}
