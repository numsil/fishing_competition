import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/tier_avatar.dart';
import '../../data/ranking_repository.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../verification/data/verification_repository.dart';
import '../../../verification/presentation/screens/verification_tab.dart';

class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  int _selectedYear = DateTime.now().year;

  static final _selectableYears = List.generate(
    DateTime.now().year - 2024,
    (i) => DateTime.now().year - i,
  );

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('랭킹', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Consumer(
            builder: (context, ref, _) {
              final pendingCount = ref
                  .watch(myPendingVerificationsProvider)
                  .whenOrNull(data: (list) => list.length) ?? 0;
              return TabBar(
                controller: _tab,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w400, fontSize: 13),
                tabs: [
                  const Tab(text: '리그'),
                  const Tab(text: '개인'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('인증'),
                        if (pendingCount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _LeagueScoreTab(
            isDark: context.isDark,
            accent: context.accentColor,
            selectedYear: _selectedYear,
            selectableYears: _selectableYears,
            onYearChanged: (y) => setState(() => _selectedYear = y),
          ),
          _PersonalScoreTab(
            isDark: context.isDark,
            accent: context.accentColor,
            selectedYear: _selectedYear,
            selectableYears: _selectableYears,
            onYearChanged: (y) => setState(() => _selectedYear = y),
          ),
          const VerificationTab(),
        ],
      ),
    );
  }
}

// ── 리그 점수 탭 ─────────────────────────────────────────
class _LeagueScoreTab extends ConsumerWidget {
  const _LeagueScoreTab({
    required this.isDark,
    required this.accent,
    required this.selectedYear,
    required this.selectableYears,
    required this.onYearChanged,
  });
  final bool isDark;
  final Color accent;
  final int selectedYear;
  final List<int> selectableYears;
  final ValueChanged<int> onYearChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);
    final myId = ref.watch(currentUserProvider)?.id;

    return ref.watch(leagueScoreRankingProvider(selectedYear)).when(
      data: (entries) {
        if (entries.isEmpty) {
          return Column(
            children: [
              const SizedBox(height: 16),
              _SeasonDropdown(
                selectedYear: selectedYear,
                selectableYears: selectableYears,
                accent: accent,
                isDark: isDark,
                onChanged: onYearChanged,
              ),
              Expanded(
                child: Center(
                  child: Text('$selectedYear 시즌 리그 점수 기록이 없습니다', style: TextStyle(color: sub)),
                ),
              ),
            ],
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(leagueScoreRankingProvider(selectedYear)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _SeasonDropdown(
                selectedYear: selectedYear,
                selectableYears: selectableYears,
                accent: accent,
                isDark: isDark,
                onChanged: onYearChanged,
              ),
              const SizedBox(height: 20),
              _ScorePodium(entries: entries.take(3).toList(), isDark: isDark),
              const SizedBox(height: 16),
              ...entries.skip(3).toList().asMap().entries.map((e) => _ScoreRankRow(
                    entry: e.value,
                    rank: e.key + 4,
                    isDark: isDark,
                    accent: accent,
                    sub: sub,
                    isMe: e.value.userId == myId,
                  )),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e', style: TextStyle(color: sub))),
    );
  }
}

// ── 개인 점수 탭 ─────────────────────────────────────────
class _PersonalScoreTab extends ConsumerWidget {
  const _PersonalScoreTab({
    required this.isDark,
    required this.accent,
    required this.selectedYear,
    required this.selectableYears,
    required this.onYearChanged,
  });
  final bool isDark;
  final Color accent;
  final int selectedYear;
  final List<int> selectableYears;
  final ValueChanged<int> onYearChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);
    final myId = ref.watch(currentUserProvider)?.id;

    return ref.watch(personalScoreRankingProvider(selectedYear)).when(
      data: (entries) {
        if (entries.isEmpty) {
          return Column(
            children: [
              const SizedBox(height: 16),
              _SeasonDropdown(
                selectedYear: selectedYear,
                selectableYears: selectableYears,
                accent: accent,
                isDark: isDark,
                onChanged: onYearChanged,
              ),
              Expanded(
                child: Center(
                  child: Text('$selectedYear 시즌 개인 기록 점수가 없습니다', style: TextStyle(color: sub)),
                ),
              ),
            ],
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(personalScoreRankingProvider(selectedYear)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _SeasonDropdown(
                selectedYear: selectedYear,
                selectableYears: selectableYears,
                accent: accent,
                isDark: isDark,
                onChanged: onYearChanged,
              ),
              const SizedBox(height: 20),
              _ScorePodium(entries: entries.take(3).toList(), isDark: isDark),
              const SizedBox(height: 16),
              ...entries.skip(3).toList().asMap().entries.map((e) => _ScoreRankRow(
                    entry: e.value,
                    rank: e.key + 4,
                    isDark: isDark,
                    accent: accent,
                    sub: sub,
                    isMe: e.value.userId == myId,
                  )),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e', style: TextStyle(color: sub))),
    );
  }
}

// ── 시즌 드롭박스 ─────────────────────────────────────────
class _SeasonDropdown extends StatelessWidget {
  const _SeasonDropdown({
    required this.selectedYear,
    required this.selectableYears,
    required this.accent,
    required this.isDark,
    required this.onChanged,
  });
  final int selectedYear;
  final List<int> selectableYears;
  final Color accent;
  final bool isDark;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: selectedYear,
            isDense: true,
            icon: Icon(LucideIcons.chevronDown, size: 14, color: accent),
            dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent),
            items: selectableYears.map((y) => DropdownMenuItem(
              value: y,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.calendar, size: 13, color: accent),
                const SizedBox(width: 6),
                Text('$y 시즌'),
              ]),
            )).toList(),
            onChanged: (y) { if (y != null) onChanged(y); },
          ),
        ),
      ),
    );
  }
}

// ── 포디움 ───────────────────────────────────────────────
class _ScorePodium extends StatelessWidget {
  const _ScorePodium({required this.entries, required this.isDark});
  final List<ScoreRankingEntry> entries;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox();

    // 화면 순서: 2위(좌) → 1위(중) → 3위(우)
    final displayOrder = <int>[];
    if (entries.length > 1) displayOrder.add(1); // 2위
    if (entries.isNotEmpty) displayOrder.add(0); // 1위
    if (entries.length > 2) displayOrder.add(2); // 3위

    final medals = [AppColors.gold, AppColors.silver, AppColors.bronze];
    // 포디움 바 높이: rank 기준 (1위=100, 2위=72, 3위=50)
    final barHeights = [100.0, 72.0, 50.0];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: displayOrder.map((idx) {
        final rank = idx + 1;
        final entry = entries[idx];
        final medal = medals[idx];
        final barH = barHeights[idx];
        final isFirst = rank == 1;

        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 왕관 (1위만)
              if (isFirst)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Icon(LucideIcons.crown, size: 20, color: AppColors.gold),
                ),
              // 아바타 (티어 스킨)
              GestureDetector(
                onTap: () => context.push('${AppRoutes.userProfile}/${entry.userId}'),
                child: TierAvatar(
                  username: entry.username,
                  avatarUrl: entry.avatarUrl,
                  score: entry.score,
                  radius: isFirst ? 29 : 23,
                  isDark: isDark,
                  borderWidth: isFirst ? 3.0 : 2.5,
                ),
              ),
              const SizedBox(height: 8),
              // 이름
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  entry.username,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: isFirst ? 13 : 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 2),
              // 점수
              Text(
                '${entry.score}pt',
                style: TextStyle(
                  fontSize: isFirst ? 14 : 12,
                  fontWeight: FontWeight.w900,
                  color: medal,
                ),
              ),
              const SizedBox(height: 6),
              // 포디움 바
              Container(
                height: barH,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: medal.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  border: Border(
                    top: BorderSide(color: medal, width: 3),
                    left: BorderSide(color: medal.withValues(alpha: 0.3), width: 1),
                    right: BorderSide(color: medal.withValues(alpha: 0.3), width: 1),
                  ),
                ),
                child: Center(
                  child: Text(
                    '$rank위',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: isFirst ? 18 : 15,
                      color: medal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── 4위~ 행 ──────────────────────────────────────────────
class _ScoreRankRow extends StatelessWidget {
  const _ScoreRankRow({
    required this.entry,
    required this.rank,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.isMe,
  });
  final ScoreRankingEntry entry;
  final int rank;
  final bool isDark, isMe;
  final Color accent, sub;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? accent.withValues(alpha: 0.07) : cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? accent.withValues(alpha: 0.3)
              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE)),
        ),
      ),
      child: Row(children: [
        SizedBox(
          width: 28,
          child: Text('$rank',
              style: TextStyle(fontWeight: FontWeight.w800, color: sub, fontSize: 15),
              textAlign: TextAlign.center),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => context.push('${AppRoutes.userProfile}/${entry.userId}'),
          child: TierAvatar(
            username: entry.username,
            avatarUrl: entry.avatarUrl,
            score: entry.score,
            radius: 19,
            isDark: isDark,
            borderWidth: 2.5,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(children: [
            Text(entry.username,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            if (isMe) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('나',
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800, color: accent)),
              ),
            ],
          ]),
        ),
        Text('${entry.score}pt',
            style: TextStyle(fontWeight: FontWeight.w800, color: accent, fontSize: 15)),
      ]),
    );
  }
}
