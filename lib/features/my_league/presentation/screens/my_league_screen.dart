import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/my_league_repository.dart';
import '../../../league/data/league_model.dart';
import '../../../league/data/league_repository.dart';
import '../../../auth/data/auth_repository.dart';

class MyLeagueScreen extends ConsumerStatefulWidget {
  const MyLeagueScreen({super.key});

  @override
  ConsumerState<MyLeagueScreen> createState() => _MyLeagueScreenState();
}

class _MyLeagueScreenState extends ConsumerState<MyLeagueScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    final sub = isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final divColor = isDark ? AppColors.darkSurface2 : AppColors.lightDivider;

    return ref.watch(myLeaguesProvider).when(
      data: (myLeaguesMap) {
        final hosted = myLeaguesMap['hosted'] ?? [];
        final participated = myLeaguesMap['participated'] ?? [];
        
        final activeLeagues = participated.where((l) => l.status != 'completed' && l.status != 'canceled').toList();
        final historyLeagues = participated.where((l) => l.status == 'completed' || l.status == 'canceled').toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('나의 리그', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            bottom: TabBar(
              controller: _tab,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
              indicatorColor: accent,
              labelColor: accent,
              unselectedLabelColor: sub,
              tabs: const [
                Tab(text: '참여중'),
                Tab(text: '참여 기록'),
                Tab(text: '개설한 리그'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tab,
            children: [
              _ActiveTab(leagues: activeLeagues, isDark: isDark, accent: accent, sub: sub, cardBg: cardBg, divColor: divColor),
              _HistoryTab(leagues: historyLeagues, isDark: isDark, accent: accent, sub: sub, cardBg: cardBg, divColor: divColor),
              _MyLeaguesTab(leagues: hosted, isDark: isDark, accent: accent, sub: sub, cardBg: cardBg, divColor: divColor),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('오류: $e'))),
    );
  }
}

// ── 참여중 탭 ─────────────────────────────────────────────
class _ActiveTab extends StatelessWidget {
  const _ActiveTab({
    required this.leagues,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
  });
  final List<League> leagues;
  final bool isDark;
  final Color accent, sub, cardBg, divColor;

  @override
  Widget build(BuildContext context) {
    if (leagues.isEmpty) {
      return _EmptyState(
        isDark: isDark,
        accent: accent,
        sub: sub,
        message: '참여중인 리그가 없습니다',
        buttonLabel: '리그 찾아보기',
        onTap: () => context.go(AppRoutes.league),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MySummaryCard(isDark: isDark, accent: accent, sub: sub, cardBg: cardBg, divColor: divColor),
        const SizedBox(height: 20),
        Text('참여중인 리그 ${leagues.length}개',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sub)),
        const SizedBox(height: 10),
        ...leagues.map((e) => _ActiveLeagueCard(
              league: e,
              isDark: isDark,
              accent: accent,
              sub: sub,
              cardBg: cardBg,
              divColor: divColor,
            )),
      ],
    );
  }
}

class _MySummaryCard extends StatelessWidget {
  const _MySummaryCard({
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
  });
  final bool isDark;
  final Color accent, sub, cardBg, divColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.trophy, size: 16, color: AppColors.gold),
              const SizedBox(width: 8),
              Text('내 시즌 현황', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sub)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SummaryItem(value: '3', label: '참여중', accent: accent),
              _Divider(divColor: divColor),
              _SummaryItem(value: '1위', label: '최고 순위', accent: AppColors.gold),
              _Divider(divColor: divColor),
              _SummaryItem(value: '52.3cm', label: '최대어', accent: accent),
              _Divider(divColor: divColor),
              _SummaryItem(value: '650', label: '누적 점수', accent: accent),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.value, required this.label, required this.accent});
  final String value, label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: accent)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.divColor});
  final Color divColor;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: divColor);
  }
}

class _ActiveLeagueCard extends ConsumerWidget {
  const _ActiveLeagueCard({
    required this.league,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
  });
  final League league;
  final bool isDark;
  final Color accent, sub, cardBg, divColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLive = league.status == 'in_progress';
    final isUpcoming = league.status == 'recruiting';
    final type = isLive ? 'live' : isUpcoming ? 'upcoming' : 'history';

    final startStr = DateFormat('yyyy.MM.dd').format(league.startTime);
    final endStr = DateFormat('yyyy.MM.dd').format(league.endTime);

    // 순위 데이터 가져오기
    final rankingAsync = ref.watch(leagueRankingProvider(league.id));
    final currentUserId = ref.watch(currentUserProvider)?.id;

    String myRank = '-';
    String myBest = '-';

    rankingAsync.whenData((entries) {
      if (currentUserId != null) {
        final idx = entries.indexWhere((e) => e.userId == currentUserId);
        if (idx >= 0) {
          myRank = '${idx + 1}위';
          final best = entries[idx].bestLength;
          if (best != null) myBest = '${best.toStringAsFixed(1)}cm';
        }
      }
    });

    return GestureDetector(
      onTap: () => context.push(
        '${AppRoutes.myLeagueDetail}/${league.id}?type=$type',
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive ? accent.withValues(alpha: 0.4) : (isDark ? AppColors.darkSurface2 : AppColors.lightDivider),
          width: isLive ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                // 상태 뱃지
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isLive
                        ? AppColors.liveRed.withValues(alpha: 0.12)
                        : isUpcoming
                            ? accent.withValues(alpha: 0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLive) ...[
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.liveRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('진행중',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.liveRed)),
                      ] else ...[
                        Text('모집중',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: accent)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    league.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // 정보 행
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(
              children: [
                Icon(LucideIcons.mapPin, size: 13, color: sub),
                const SizedBox(width: 4),
                Text(league.location, style: TextStyle(fontSize: 12, color: sub)),
                const SizedBox(width: 12),
                Icon(LucideIcons.calendar, size: 12, color: sub),
                const SizedBox(width: 4),
                Text('$startStr ~ $endStr', style: TextStyle(fontSize: 12, color: sub)),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: divColor),

          // 내 기록
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(
              children: [
                _RecordChip(
                  label: '내 순위',
                  value: myRank,
                  color: accent,
                  sub: sub,
                  isDark: isDark,
                  divColor: divColor,
                ),
                const SizedBox(width: 10),
                _RecordChip(
                  label: '내 최대어',
                  value: myBest,
                  color: accent,
                  sub: sub,
                  isDark: isDark,
                  divColor: divColor,
                ),
                const SizedBox(width: 10),
                _RecordChip(
                  label: '참가자',
                  value: '${league.participantsCount}명',
                  color: accent,
                  sub: sub,
                  isDark: isDark,
                  divColor: divColor,
                ),
                const Spacer(),
                Icon(LucideIcons.chevronRight, size: 14, color: sub),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _RecordChip extends StatelessWidget {
  const _RecordChip({
    required this.label,
    required this.value,
    required this.color,
    required this.sub,
    required this.isDark,
    required this.divColor,
  });
  final String label, value;
  final Color color, sub, divColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: divColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: sub)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

// ── 참여 기록 탭 ─────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.leagues,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
  });
  final List<League> leagues;
  final bool isDark;
  final Color accent, sub, cardBg, divColor;

  @override
  Widget build(BuildContext context) {
    if (leagues.isEmpty) {
      return _EmptyState(
        isDark: isDark,
        accent: accent,
        sub: sub,
        message: '참여한 리그 기록이 없습니다',
        buttonLabel: '리그 참여하기',
        onTap: () => context.go(AppRoutes.league),
      );
    }

    // 총 통계
    final totalScore = 0;
    final wins = 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 통계 요약 카드
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: divColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.history, size: 16, color: sub),
                  const SizedBox(width: 8),
                  Text('전체 기록 요약', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sub)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _SummaryItem(value: '${leagues.length}회', label: '총 참여', accent: accent),
                  _Divider(divColor: divColor),
                  _SummaryItem(value: '$wins회', label: '우승', accent: AppColors.gold),
                  _Divider(divColor: divColor),
                  _SummaryItem(value: '-', label: '최대어', accent: accent),
                  _Divider(divColor: divColor),
                  _SummaryItem(value: '$totalScore', label: '총 점수', accent: accent),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('참여 기록 ${leagues.length}건',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sub)),
        const SizedBox(height: 10),
        ...leagues.reversed.map((e) => _HistoryCard(
              league: e,
              isDark: isDark,
              accent: accent,
              sub: sub,
              cardBg: cardBg,
              divColor: divColor,
            )),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.league,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
  });
  final League league;
  final bool isDark;
  final Color accent, sub, cardBg, divColor;

  Color get _rankColor {
    return sub;
  }

  String get _rankEmoji {
    return '🎣';
  }

  @override
  Widget build(BuildContext context) {
    final startStr = DateFormat('yyyy.MM.dd').format(league.startTime);
    final endStr = DateFormat('yyyy.MM.dd').format(league.endTime);

    return GestureDetector(
      onTap: () => context.push('${AppRoutes.myLeagueDetail}/${league.id}?type=history'),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider),
      ),
      child: Row(
        children: [
          // 순위 아이콘
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(LucideIcons.award, size: 22, color: sub),
            ),
          ),
          const SizedBox(width: 12),
          // 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  league.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(LucideIcons.mapPin, size: 11, color: sub),
                    const SizedBox(width: 3),
                    Text(league.location, style: TextStyle(fontSize: 11, color: sub)),
                    const SizedBox(width: 8),
                    Text('$startStr ~ $endStr', style: TextStyle(fontSize: 11, color: sub)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _rankColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '-위 / ${league.participantsCount}명',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _rankColor),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('-',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accent)),
                  ],
                ),
              ],
            ),
          ),
          // 점수
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+0',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: accent)),
              Text('점수', style: TextStyle(fontSize: 10, color: sub)),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

// ── 빈 상태 ───────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.message,
    required this.buttonLabel,
    required this.onTap,
  });
  final bool isDark;
  final Color accent, sub;
  final String message, buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.search, size: 56, color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD)),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 15, color: sub)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: onTap, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}

// ── 데이터 모델 ───────────────────────────────────────────
// _LeagueEntry is removed

// ── 개설한 리그 탭 ────────────────────────────────────────
class _MyLeaguesTab extends StatelessWidget {
  const _MyLeaguesTab({
    required this.leagues,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
  });
  final List<League> leagues;
  final bool isDark;
  final Color accent, sub, cardBg, divColor;

  @override
  Widget build(BuildContext context) {
    if (leagues.isEmpty) {
      return _EmptyState(
        isDark: isDark,
        accent: accent,
        sub: sub,
        message: '개설한 리그가 없습니다',
        buttonLabel: '리그 개설하기',
        onTap: () => context.go(AppRoutes.league),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 요약 카드
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: divColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  value: '${leagues.length}개',
                  label: '총 개설',
                  accent: accent,
                ),
              ),
              Container(width: 1, height: 36, color: divColor),
              Expanded(
                child: _SummaryItem(
                  value: '${leagues.where((l) => l.status == 'in_progress').length}개',
                  label: '진행중',
                  accent: AppColors.liveRed,
                ),
              ),
              Container(width: 1, height: 36, color: divColor),
              Expanded(
                child: _SummaryItem(
                  value: '${leagues.fold<int>(0, (s, l) => s + l.participantsCount)}명',
                  label: '총 참가자',
                  accent: accent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('개설한 리그 ${leagues.length}개',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sub)),
        const SizedBox(height: 10),
        ...leagues.map((league) => _MyLeagueCard(
              league: league,
              isDark: isDark,
              accent: accent,
              sub: sub,
              cardBg: cardBg,
              divColor: divColor,
            )),
      ],
    );
  }
}

class _MyLeagueCard extends StatelessWidget {
  const _MyLeagueCard({
    required this.league,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
  });
  final League league;
  final bool isDark;
  final Color accent, sub, cardBg, divColor;

  @override
  Widget build(BuildContext context) {
    final isLive = league.status == 'in_progress';
    final isUpcoming = league.status == 'recruiting';
    
    final startStr = DateFormat('yyyy.MM.dd').format(league.startTime);
    final endStr = DateFormat('yyyy.MM.dd').format(league.endTime);

    final statusLabel = isLive ? '진행중' : isUpcoming ? '진행 예정' : '종료';
    final statusColor = isLive ? AppColors.liveRed : isUpcoming ? accent : sub;

    return GestureDetector(
      onTap: () => context.push('${AppRoutes.leagueManage}/${league.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLive ? AppColors.liveRed.withValues(alpha: 0.4) : (isDark ? AppColors.darkSurface2 : AppColors.lightDivider),
            width: isLive ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  // 상태 뱃지
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLive) ...[
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.liveRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(statusLabel,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: statusColor)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      league.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 관리 버튼
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.settings, size: 12, color: accent),
                        const SizedBox(width: 4),
                        Text('관리', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 13, color: sub),
                  const SizedBox(width: 3),
                  Text(league.location, style: TextStyle(fontSize: 12, color: sub)),
                  const SizedBox(width: 10),
                  Icon(Icons.calendar_today_outlined, size: 12, color: sub),
                  const SizedBox(width: 3),
                  Text('$startStr ~ $endStr', style: TextStyle(fontSize: 12, color: sub)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: divColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                children: [
                  _InfoChip(
                    icon: Icons.group_outlined,
                    label: '${league.participantsCount}/${league.maxParticipants ?? "무제한"}명',
                    color: isLive && league.maxParticipants != null && league.participantsCount >= league.maxParticipants!
                        ? AppColors.liveRed
                        : accent,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(icon: Icons.set_meal_outlined, label: '모든 어종', color: accent),
                  if (isUpcoming) ...[
                    const SizedBox(width: 8),
                    _InfoChip(
                        icon: Icons.timer_outlined,
                        label: '모집중',
                        color: accent),
                  ],
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: sub),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
