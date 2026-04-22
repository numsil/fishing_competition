import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_svg.dart';

class MyLeagueScreen extends StatefulWidget {
  const MyLeagueScreen({super.key});

  @override
  State<MyLeagueScreen> createState() => _MyLeagueScreenState();
}

class _MyLeagueScreenState extends State<MyLeagueScreen>
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
    final divColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);

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
          _ActiveTab(isDark: isDark, accent: accent, sub: sub, cardBg: cardBg, divColor: divColor),
          _HistoryTab(isDark: isDark, accent: accent, sub: sub, cardBg: cardBg, divColor: divColor),
          _MyLeaguesTab(isDark: isDark, accent: accent, sub: sub, cardBg: cardBg, divColor: divColor),
        ],
      ),
    );
  }
}

// ── 참여중 탭 ─────────────────────────────────────────────
class _ActiveTab extends StatelessWidget {
  const _ActiveTab({
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
  });
  final bool isDark;
  final Color accent, sub, cardBg, divColor;

  static const _active = [
    _LeagueEntry(
      id: 'lg001',
      name: '2026 충주호 배스 오픈',
      location: '충주호',
      dateRange: '2026.04.20 ~ 2026.04.27',
      status: 'live',
      myRank: 1,
      totalParticipants: 48,
      fish: '배스',
      myRecord: '52.3cm',
      daysLeft: 5,
    ),
    _LeagueEntry(
      id: 'lg002',
      name: '소양강 봄 챔피언십',
      location: '소양강',
      dateRange: '2026.05.01 ~ 2026.05.10',
      status: 'upcoming',
      myRank: null,
      totalParticipants: 32,
      fish: '쏘가리',
      myRecord: null,
      daysLeft: 9,
    ),
    _LeagueEntry(
      id: 'lg003',
      name: '가평 계곡 배스 리그',
      location: '가평',
      dateRange: '2026.04.15 ~ 2026.04.30',
      status: 'live',
      myRank: 4,
      totalParticipants: 24,
      fish: '배스',
      myRecord: '44.8cm',
      daysLeft: 8,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (_active.isEmpty) {
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
        // 내 현황 요약 카드
        _MySummaryCard(isDark: isDark, accent: accent, sub: sub, cardBg: cardBg, divColor: divColor),
        const SizedBox(height: 20),
        Text('참여중인 리그 ${_active.length}개',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sub)),
        const SizedBox(height: 10),
        ..._active.map((e) => _ActiveLeagueCard(
              entry: e,
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
        border: Border.all(color: divColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppSvg(AppIcons.trophy, size: 16, color: AppColors.gold),
              const SizedBox(width: 6),
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

class _ActiveLeagueCard extends StatelessWidget {
  const _ActiveLeagueCard({
    required this.entry,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
  });
  final _LeagueEntry entry;
  final bool isDark;
  final Color accent, sub, cardBg, divColor;

  @override
  Widget build(BuildContext context) {
    final isLive = entry.status == 'live';
    final isUpcoming = entry.status == 'upcoming';
    final type = isLive ? 'live' : isUpcoming ? 'upcoming' : 'history';

    return GestureDetector(
      onTap: () => context.push(
        '${AppRoutes.myLeagueDetail}/${entry.id}?type=$type',
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive ? accent.withValues(alpha: 0.4) : divColor,
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
                        Text('D-${entry.daysLeft}',
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
                    entry.name,
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
                Icon(Icons.location_on_outlined, size: 13, color: sub),
                const SizedBox(width: 3),
                Text(entry.location, style: TextStyle(fontSize: 12, color: sub)),
                const SizedBox(width: 12),
                Icon(Icons.calendar_today_outlined, size: 12, color: sub),
                const SizedBox(width: 3),
                Text(entry.dateRange, style: TextStyle(fontSize: 12, color: sub)),
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
                // 내 순위
                _RecordChip(
                  label: '내 순위',
                  value: entry.myRank != null ? '${entry.myRank}위' : '-',
                  color: entry.myRank == 1
                      ? AppColors.gold
                      : entry.myRank == 2
                          ? AppColors.silver
                          : entry.myRank == 3
                              ? AppColors.bronze
                              : accent,
                  sub: sub,
                  isDark: isDark,
                  divColor: divColor,
                ),
                const SizedBox(width: 10),
                // 내 최대어
                _RecordChip(
                  label: '내 최대어',
                  value: entry.myRecord ?? '-',
                  color: accent,
                  sub: sub,
                  isDark: isDark,
                  divColor: divColor,
                ),
                const SizedBox(width: 10),
                // 참가자
                _RecordChip(
                  label: '참가자',
                  value: '${entry.totalParticipants}명',
                  color: accent,
                  sub: sub,
                  isDark: isDark,
                  divColor: divColor,
                ),
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
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
  });
  final bool isDark;
  final Color accent, sub, cardBg, divColor;

  static const _history = [
    _HistoryEntry(
      id: 'h001',
      name: '2026 충주호 배스 오픈 (시즌1)',
      location: '충주호',
      dateRange: '2026.01.10 ~ 2026.01.17',
      fish: '배스',
      myRank: 1,
      totalParticipants: 52,
      myRecord: '48.2cm',
      score: 300,
    ),
    _HistoryEntry(
      id: 'h002',
      name: '소양강 겨울 챔피언십',
      location: '소양강',
      dateRange: '2026.02.05 ~ 2026.02.08',
      fish: '쏘가리',
      myRank: 3,
      totalParticipants: 28,
      myRecord: '35.0cm',
      score: 150,
    ),
    _HistoryEntry(
      id: 'h003',
      name: '팔당 주말 리그',
      location: '팔당호',
      dateRange: '2026.03.01 ~ 2026.03.02',
      fish: '붕어',
      myRank: 7,
      totalParticipants: 40,
      myRecord: '30.5cm',
      score: 80,
    ),
    _HistoryEntry(
      id: 'h004',
      name: '가평 봄맞이 배스 대회',
      location: '가평',
      dateRange: '2026.03.20 ~ 2026.03.22',
      fish: '배스',
      myRank: 2,
      totalParticipants: 35,
      myRecord: '41.3cm',
      score: 200,
    ),
    _HistoryEntry(
      id: 'h005',
      name: '충주호 배스 리그 시즌2',
      location: '충주호',
      dateRange: '2026.04.01 ~ 2026.04.07',
      fish: '배스',
      myRank: 1,
      totalParticipants: 45,
      myRecord: '50.1cm',
      score: 350,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (_history.isEmpty) {
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
    final totalScore = _history.fold(0, (sum, e) => sum + e.score);
    final wins = _history.where((e) => e.myRank == 1).length;

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
                  Icon(Icons.history_rounded, size: 16, color: sub),
                  const SizedBox(width: 6),
                  Text('전체 기록 요약', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sub)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _SummaryItem(value: '${_history.length}회', label: '총 참여', accent: accent),
                  _Divider(divColor: divColor),
                  _SummaryItem(value: '$wins회', label: '우승', accent: AppColors.gold),
                  _Divider(divColor: divColor),
                  _SummaryItem(value: '50.1cm', label: '최대어', accent: accent),
                  _Divider(divColor: divColor),
                  _SummaryItem(value: '$totalScore', label: '총 점수', accent: accent),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('참여 기록 ${_history.length}건',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sub)),
        const SizedBox(height: 10),
        ..._history.reversed.map((e) => _HistoryCard(
              entry: e,
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
    required this.entry,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
  });
  final _HistoryEntry entry;
  final bool isDark;
  final Color accent, sub, cardBg, divColor;

  Color get _rankColor {
    if (entry.myRank == 1) return AppColors.gold;
    if (entry.myRank == 2) return AppColors.silver;
    if (entry.myRank == 3) return AppColors.bronze;
    return sub;
  }

  String get _rankEmoji {
    if (entry.myRank == 1) return '🥇';
    if (entry.myRank == 2) return '🥈';
    if (entry.myRank == 3) return '🥉';
    return '🎣';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('${AppRoutes.myLeagueDetail}/${entry.id}?type=history'),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: entry.myRank <= 3 ? _rankColor.withValues(alpha: 0.3) : divColor,
        ),
      ),
      child: Row(
        children: [
          // 순위 아이콘
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: entry.myRank <= 3
                  ? _rankColor.withValues(alpha: 0.1)
                  : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(_rankEmoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          // 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 11, color: sub),
                    const SizedBox(width: 2),
                    Text(entry.location, style: TextStyle(fontSize: 11, color: sub)),
                    const SizedBox(width: 8),
                    Text(entry.dateRange, style: TextStyle(fontSize: 11, color: sub)),
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
                        '${entry.myRank}위 / ${entry.totalParticipants}명',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _rankColor),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(entry.myRecord,
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
              Text('+${entry.score}',
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
          AppSvg(AppIcons.trophy, size: 64,
              color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD)),
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
class _LeagueEntry {
  const _LeagueEntry({
    required this.id,
    required this.name,
    required this.location,
    required this.dateRange,
    required this.status,
    required this.myRank,
    required this.totalParticipants,
    required this.fish,
    required this.myRecord,
    required this.daysLeft,
  });
  final String id, name, location, dateRange, status, fish;
  final int? myRank;
  final int totalParticipants, daysLeft;
  final String? myRecord;
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.id,
    required this.name,
    required this.location,
    required this.dateRange,
    required this.fish,
    required this.myRank,
    required this.totalParticipants,
    required this.myRecord,
    required this.score,
  });
  final String id, name, location, dateRange, fish, myRecord;
  final int myRank, totalParticipants, score;
}

// ── 개설한 리그 탭 ────────────────────────────────────────
class _MyLeague {
  const _MyLeague({
    required this.id,
    required this.name,
    required this.location,
    required this.dateRange,
    required this.fish,
    required this.status,
    required this.participants,
    required this.maxParticipants,
    this.daysLeft,
  });
  final String id, name, location, dateRange, fish, status;
  final int participants, maxParticipants;
  final int? daysLeft;
}

class _MyLeaguesTab extends StatelessWidget {
  const _MyLeaguesTab({
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
  });
  final bool isDark;
  final Color accent, sub, cardBg, divColor;

  static const _myLeagues = [
    _MyLeague(
      id: 'mg001',
      name: '소양강 봄 챔피언십',
      location: '소양강',
      dateRange: '2026.05.01 ~ 2026.05.10',
      fish: '쏘가리',
      status: 'upcoming',
      participants: 8,
      maxParticipants: 50,
      daysLeft: 9,
    ),
    _MyLeague(
      id: 'mg002',
      name: '충주호 봄 배스 리그',
      location: '충주호',
      dateRange: '2026.04.10 ~ 2026.04.20',
      fish: '배스',
      status: 'live',
      participants: 32,
      maxParticipants: 40,
    ),
    _MyLeague(
      id: 'mg003',
      name: '팔당 겨울 붕어 대회',
      location: '팔당호',
      dateRange: '2026.02.10 ~ 2026.02.12',
      fish: '붕어',
      status: 'ended',
      participants: 25,
      maxParticipants: 30,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (_myLeagues.isEmpty) {
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
                  value: '${_myLeagues.length}개',
                  label: '총 개설',
                  accent: accent,
                ),
              ),
              Container(width: 1, height: 36, color: divColor),
              Expanded(
                child: _SummaryItem(
                  value: '${_myLeagues.where((l) => l.status == 'live').length}개',
                  label: '진행중',
                  accent: AppColors.liveRed,
                ),
              ),
              Container(width: 1, height: 36, color: divColor),
              Expanded(
                child: _SummaryItem(
                  value: '${_myLeagues.fold(0, (s, l) => s + l.participants)}명',
                  label: '총 참가자',
                  accent: accent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('개설한 리그 ${_myLeagues.length}개',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sub)),
        const SizedBox(height: 10),
        ..._myLeagues.map((league) => _MyLeagueCard(
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
  final _MyLeague league;
  final bool isDark;
  final Color accent, sub, cardBg, divColor;

  @override
  Widget build(BuildContext context) {
    final isLive = league.status == 'live';
    final isUpcoming = league.status == 'upcoming';

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
            color: isLive ? AppColors.liveRed.withValues(alpha: 0.4) : divColor,
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
                      league.name,
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
                        Icon(Icons.settings_outlined, size: 12, color: accent),
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
                  Text(league.dateRange, style: TextStyle(fontSize: 12, color: sub)),
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
                    label: '${league.participants}/${league.maxParticipants}명',
                    color: isLive && league.participants >= league.maxParticipants
                        ? AppColors.liveRed
                        : accent,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(icon: Icons.set_meal_outlined, label: league.fish, color: accent),
                  if (isUpcoming && league.daysLeft != null) ...[
                    const SizedBox(width: 8),
                    _InfoChip(
                        icon: Icons.timer_outlined,
                        label: 'D-${league.daysLeft}',
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
