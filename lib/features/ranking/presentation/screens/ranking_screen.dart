import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_svg.dart';
import '../../data/ranking_repository.dart';

class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen>
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

    return ref.watch(topRankingsProvider).when(
      data: (rankings) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('랭킹', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            bottom: TabBar(
              controller: _tab,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
              tabs: const [Tab(text: '리그'), Tab(text: '지역'), Tab(text: '이달의')],
            ),
          ),
          body: TabBarView(
            controller: _tab,
            children: [
              _LeagueTab(entries: rankings, isDark: isDark, accent: accent),
              _RegionTab(entries: rankings, isDark: isDark, accent: accent),
              _MonthlyTab(isDark: isDark, accent: accent),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('오류: $e'))),
    );
  }
}

// ── 리그 탭 ─────────────────────────────────────────────
class _LeagueTab extends StatelessWidget {
  const _LeagueTab({required this.entries, required this.isDark, required this.accent});
  final List<RankingEntry> entries;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 리그 선택 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE)),
          ),
          child: Row(
            children: [
              Icon(Icons.emoji_events_rounded, size: 16, color: accent),
              const SizedBox(width: 8),
              Text('2026 충주호 배스 오픈', style: TextStyle(fontWeight: FontWeight.w700, color: accent)),
              const Spacer(),
              Row(children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.liveRed, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                const Text('LIVE', style: TextStyle(color: AppColors.liveRed, fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: sub),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 상위 3
        _Podium(entries: entries.take(3).toList(), isDark: isDark, accent: accent),
        const SizedBox(height: 16),

        // 4위~
        ...entries.skip(3).toList().asMap().entries.map((e) => _RankRow(entry: e.value, rank: e.key + 4, isDark: isDark, accent: accent, sub: sub, cardBg: cardBg, isMe: false)),
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.entries, required this.isDark, required this.accent});
  final List<RankingEntry> entries;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox();
    
    final e = entries;
    final heights = [100.0, 75.0, 55.0];
    // 2위, 1위, 3위 순서인데 항목 수가 부족할 수 있음
    final order = [];
    if (e.length > 1) order.add(1); // 2위
    if (e.isNotEmpty) order.add(0); // 1위
    if (e.length > 2) order.add(2); // 3위

    final medals = [AppColors.silver, AppColors.gold, AppColors.bronze];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: order.map((idx) {
        final rank = idx + 1;
        final entry = e[idx];
        final pos = rank == 1 ? 1 : rank == 2 ? 0 : 2;
        final medal = medals[pos];

        return Expanded(
          child: Column(
            children: [
              if (rank == 1) AppSvg(AppIcons.crown, size: 20, color: AppColors.gold),
              AppSvg(
                rank == 1 ? AppIcons.medalGold : rank == 2 ? AppIcons.medalSilver : AppIcons.medalBronze,
                size: rank == 1 ? 56 : 44,
              ),
              const SizedBox(height: 6),
              Text(entry.username, style: TextStyle(fontWeight: FontWeight.w700, fontSize: rank == 1 ? 13 : 12), overflow: TextOverflow.ellipsis),
              Text('${entry.length}cm', style: TextStyle(fontSize: rank == 1 ? 14 : 12, fontWeight: FontWeight.w800, color: medal)),
              const SizedBox(height: 4),
              Container(
                height: heights[pos],
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: medal.withValues(alpha: isDark ? 0.12 : 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border.all(color: medal.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text('$rank위', style: TextStyle(fontWeight: FontWeight.w900, color: medal, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry, required this.rank, required this.isDark, required this.accent, required this.sub, required this.cardBg, required this.isMe});
  final RankingEntry entry;
  final int rank;
  final bool isDark, isMe;
  final Color accent, sub, cardBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? accent.withValues(alpha: 0.07) : cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? accent.withValues(alpha: 0.3) : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('$rank', style: TextStyle(fontWeight: FontWeight.w700, color: sub), textAlign: TextAlign.center)),
          const SizedBox(width: 10),
          Expanded(
            child: Row(children: [
              Text(entry.username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              if (isMe) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4)),
                  child: Text('나', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: isDark ? Colors.black : Colors.white)),
                ),
              ],
            ]),
          ),
          Text('${entry.length}cm', style: TextStyle(fontWeight: FontWeight.w800, color: accent, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── 지역 탭 ─────────────────────────────────────────────
class _RegionTab extends StatelessWidget {
  const _RegionTab({required this.entries, required this.isDark, required this.accent});
  final List<RankingEntry> entries;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;

    // 간단하게 전체 데이터를 띄우도록 대체 (실제로는 location group by가 필요하지만 데모용)
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final entry = entries[i];
        final name = entry.location ?? '전국';
        final top = entry.username;
        final record = '${entry.length}cm';
        final count = 1;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE)),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: accent))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text('TOP $top · $record', style: TextStyle(fontSize: 12, color: sub)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$count명', style: TextStyle(fontWeight: FontWeight.w700, color: accent)),
              Text('참여', style: TextStyle(fontSize: 11, color: sub)),
            ]),
          ]),
        );
      },
    );
  }
}

// ── 이달의 탭 ────────────────────────────────────────────
class _MonthlyTab extends StatelessWidget {
  const _MonthlyTab({required this.isDark, required this.accent});
  final bool isDark;
  final Color accent;

  static const _badges = [
    ('🏆', '런커 클럽', '50cm+'),
    ('👑', '3연승', '3회'),
    ('🔥', '주간 1위', '7일'),
    ('⭐', '첫 런커', '달성'),
    ('🎯', '면꽝 탈출', '달성'),
    ('💎', '다이아', '등급'),
  ];

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 이달의 앵글러
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE)),
          ),
          child: Column(children: [
            Text('4월의 앵글러', style: TextStyle(fontSize: 12, color: sub, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            CircleAvatar(radius: 40, backgroundColor: accent.withValues(alpha: 0.1),
                child: Text('🎣', style: const TextStyle(fontSize: 38))),
            const SizedBox(height: 12),
            const Text('김민준', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('충주호 낚시 크루', style: TextStyle(fontSize: 13, color: sub)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _MonthStat(label: '참가', value: '5회', sub: sub),
              Container(width: 1, height: 28, color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE)),
              _MonthStat(label: '최대어', value: '52.3cm', sub: sub),
              Container(width: 1, height: 28, color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE)),
              _MonthStat(label: '점수', value: '1,840', sub: sub),
            ]),
          ]),
        ),
        const SizedBox(height: 24),

        Text('배지 보관함', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: _badges.map((b) => Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE)),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(b.$1, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 4),
              Text(b.$2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              Text(b.$3, style: TextStyle(fontSize: 10, color: sub)),
            ]),
          )).toList(),
        ),
      ],
    );
  }
}

class _MonthStat extends StatelessWidget {
  const _MonthStat({required this.label, required this.value, required this.sub});
  final String label, value;
  final Color sub;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 11, color: sub)),
    ]);
  }
}
