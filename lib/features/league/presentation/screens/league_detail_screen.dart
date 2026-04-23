import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/league_model.dart';
import '../../data/league_repository.dart';
import 'league_catch_screen.dart';

// ── 단건 리그 provider ──────────────────────────────────
final leagueDetailProvider = FutureProvider.family<League, String>((ref, id) {
  return ref.watch(leagueRepositoryProvider).getLeague(id);
});

class LeagueDetailScreen extends ConsumerWidget {
  const LeagueDetailScreen({super.key, required this.leagueId});
  final String leagueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;

    return ref.watch(leagueDetailProvider(leagueId)).when(
      data: (league) => _LeagueDetailBody(
        league: league,
        isDark: isDark,
        accent: accent,
      ),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('불러오기 실패: $e')),
      ),
    );
  }
}

// ── 메인 바디 ───────────────────────────────────────────
class _LeagueDetailBody extends ConsumerStatefulWidget {
  const _LeagueDetailBody({
    required this.league,
    required this.isDark,
    required this.accent,
  });
  final League league;
  final bool isDark;
  final Color accent;

  @override
  ConsumerState<_LeagueDetailBody> createState() => _LeagueDetailBodyState();
}

class _LeagueDetailBodyState extends ConsumerState<_LeagueDetailBody>
    with SingleTickerProviderStateMixin {
  TabController? _tab;
  bool _joining = false;

  bool get _hasTabs =>
      widget.league.status == 'in_progress' ||
      widget.league.status == 'completed';

  @override
  void initState() {
    super.initState();
    if (_hasTabs) {
      _tab = TabController(length: 2, vsync: this);
    }
  }

  @override
  void dispose() {
    _tab?.dispose();
    super.dispose();
  }

  String get _statusText {
    switch (widget.league.status) {
      case 'in_progress': return '🔴 LIVE 진행중';
      case 'recruiting':  return '🟢 모집중';
      case 'completed':   return '⬛ 종료';
      case 'canceled':    return '❌ 취소';
      default:            return widget.league.status;
    }
  }

  Color get _statusColor {
    switch (widget.league.status) {
      case 'in_progress': return AppColors.liveRed;
      case 'recruiting':  return AppColors.success;
      case 'completed':   return Colors.grey;
      case 'canceled':    return AppColors.error;
      default:            return Colors.grey;
    }
  }

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      await ref.read(leagueRepositoryProvider).joinLeague(widget.league.id);
      ref.invalidate(leagueDetailProvider(widget.league.id));
      ref.invalidate(isJoinedProvider(widget.league.id));
      ref.invalidate(leagueRankingProvider(widget.league.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('참가 신청이 완료되었습니다!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('duplicate') ? '이미 참가 신청한 대회입니다.' : '참가 신청 실패: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final league = widget.league;
    final isDark = widget.isDark;
    final accent = widget.accent;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── 헤더 ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    const Text('🎣', style: TextStyle(fontSize: 60)),
                    if (league.status == 'in_progress')
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.liveRed,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('LIVE',
                            style: TextStyle(color: Colors.white, fontSize: 11,
                                fontWeight: FontWeight.w900, letterSpacing: 2)),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
              IconButton(icon: const Icon(Icons.bookmark_border_rounded), onPressed: () {}),
            ],
          ),

          // ── 리그 기본 정보 ──────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상태 배지
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_statusText,
                        style: TextStyle(color: _statusColor, fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 10),
                  Text(league.title,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(LucideIcons.mapPin, size: 14, color: accent),
                    const SizedBox(width: 4),
                    Text(league.location,
                        style: TextStyle(fontSize: 13,
                            color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(LucideIcons.calendar, size: 14, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat('yyyy.MM.dd').format(league.startTime)}  ~  ${DateFormat('yyyy.MM.dd').format(league.endTime)}',
                      style: TextStyle(fontSize: 13,
                          color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub),
                    ),
                  ]),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ── 탭 or 단일 뷰 ───────────────────────────────
          if (_hasTabs) ...[
            SliverToBoxAdapter(
              child: TabBar(
                controller: _tab,
                tabs: [
                  Tab(text: league.status == 'completed' ? '최종 순위' : '실시간 순위'),
                  const Tab(text: '대회 정보'),
                ],
              ),
            ),
            SliverFillRemaining(
              child: TabBarView(
                controller: _tab,
                children: [
                  _RankingTab(
                    league: league,
                    isDark: isDark,
                    accent: accent,
                  ),
                  _InfoTab(league: league, isDark: isDark, accent: accent),
                ],
              ),
            ),
          ] else ...[
            SliverToBoxAdapter(
              child: _InfoTab(league: league, isDark: isDark, accent: accent),
            ),
          ],
        ],
      ),

      // ── 하단 버튼 ────────────────────────────────────
      bottomNavigationBar: _BottomBar(
        league: league,
        isDark: isDark,
        accent: accent,
        joining: _joining,
        onJoin: _join,
      ),
    );
  }
}

// ── 순위표 탭 ───────────────────────────────────────────
class _RankingTab extends ConsumerWidget {
  const _RankingTab({
    required this.league,
    required this.isDark,
    required this.accent,
  });
  final League league;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInProgress = league.status == 'in_progress';

    return ref.watch(leagueRankingProvider(league.id)).when(
      data: (entries) {
        return Stack(
          children: [
            entries.isEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(LucideIcons.fish, size: 48,
                          color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub),
                      const SizedBox(height: 12),
                      Text('아직 조과 기록이 없습니다',
                          style: TextStyle(fontSize: 14,
                              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub)),
                      if (isInProgress) ...[
                        const SizedBox(height: 8),
                        Text('첫 조과를 등록해보세요!',
                            style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.w600)),
                      ],
                    ]),
                  )
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(leagueRankingProvider(league.id)),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: entries.length,
                      itemBuilder: (_, i) => _RankCard(
                        rank: i + 1,
                        entry: entries[i],
                        rule: league.rule,
                        isDark: isDark,
                        accent: accent,
                      ),
                    ),
                  ),

            // ── 조과 등록 FAB (진행중 + 참가중) ──────────
            if (isInProgress)
              ref.watch(isJoinedProvider(league.id)).when(
                data: (joined) => joined
                    ? Positioned(
                        bottom: 20, right: 20,
                        child: FloatingActionButton.extended(
                          heroTag: 'catch_fab',
                          onPressed: () async {
                            final result = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                fullscreenDialog: true,
                                builder: (_) => LeagueCatchScreen(league: league),
                              ),
                            );
                            if (result == true) {
                              ref.invalidate(leagueRankingProvider(league.id));
                            }
                          },
                          backgroundColor: accent,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          icon: const Icon(LucideIcons.fish, size: 20),
                          label: const Text('조과 등록',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('순위를 불러오지 못했습니다: $e')),
    );
  }
}

// ── 순위 카드 ───────────────────────────────────────────
class _RankCard extends StatelessWidget {
  const _RankCard({
    required this.rank,
    required this.entry,
    required this.rule,
    required this.isDark,
    required this.accent,
  });
  final int rank;
  final LeagueRankEntry entry;
  final String rule;
  final bool isDark;
  final Color accent;

  Color get _rankColor {
    if (rank == 1) return AppColors.gold;
    if (rank == 2) return AppColors.silver;
    if (rank == 3) return AppColors.bronze;
    return isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
  }

  // 룰에 따른 메인 점수 표시
  String get _mainValue {
    switch (rule) {
      case '합산 길이':
        return entry.totalLength > 0 ? '${entry.totalLength.toStringAsFixed(1)}cm' : '-';
      case '마릿수':
        return '${entry.totalCount}마리';
      default: // 최대어, 최대어 + 마릿수
        return entry.bestLength != null ? '${entry.bestLength}cm' : '-';
    }
  }

  String get _mainLabel {
    switch (rule) {
      case '합산 길이': return '합산';
      case '마릿수': return '마릿수';
      default: return '최대어';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return Container(
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
        // 순위 뱃지
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: _rankColor.withValues(alpha: rank <= 3 ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: rank <= 3
              ? Center(child: Icon(LucideIcons.medal, size: 20, color: _rankColor))
              : Center(child: Text('$rank',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: sub))),
        ),
        const SizedBox(width: 12),
        // 유저 정보
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
            // 서브 지표들
            Wrap(spacing: 8, children: [
              _SubStat(icon: LucideIcons.fish, value: '${entry.totalCount}마리', sub: sub),
              if (entry.bestLength != null && rule != '최대어' && rule != '최대어 + 마릿수')
                _SubStat(icon: LucideIcons.ruler, value: '최대 ${entry.bestLength}cm', sub: sub),
              if (rule == '최대어 + 마릿수' && entry.totalCount > 0)
                _SubStat(icon: LucideIcons.list, value: '${entry.totalCount}마리', sub: sub),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        // 메인 점수
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
    );
  }
}

class _SubStat extends StatelessWidget {
  const _SubStat({required this.icon, required this.value, required this.sub});
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

// ── 대회 정보 탭 ─────────────────────────────────────────
class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.league, required this.isDark, required this.accent});
  final League league;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final feeStr = league.entryFee > 0
        ? '${NumberFormat('#,###').format(league.entryFee)}원'
        : '무료';
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final divColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── 핵심 스탯 4칸 ─────────────────────────────────
        Row(children: [
          _StatBox(
            label: '참가자',
            value: '${league.participantsCount}/${league.maxParticipants}명',
            accent: accent,
          ),
          const SizedBox(width: 10),
          _StatBox(label: '참가비', value: feeStr, accent: accent),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _StatBox(label: '순위 방식', value: league.rule, accent: accent),
          const SizedBox(width: 10),
          _StatBox(
            label: '공개',
            value: league.isPublic ? '공개 리그' : '비공개',
            accent: accent,
          ),
        ]),
        const SizedBox(height: 20),

        // ── 참가 현황 바 ──────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('참가 현황',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text(
              '${league.participantsCount} / ${league.maxParticipants}명',
              style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: league.maxParticipants > 0
                ? league.participantsCount / league.maxParticipants
                : 0,
            backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
            valueColor: AlwaysStoppedAnimation(accent),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 24),

        // ── 대상 어종 ─────────────────────────────────────
        _InfoSection(
          title: '대상 어종',
          icon: LucideIcons.fish,
          accent: accent,
          isDark: isDark,
          child: Wrap(
            spacing: 8, runSpacing: 8,
            children: league.fishTypes.split(',').map((f) => f.trim()).where((f) => f.isNotEmpty).map((fish) =>
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Text(fish,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: accent)),
              ),
            ).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // ── 순위 결정 방식 ───────────────────────────────
        _InfoSection(
          title: '순위 결정 방식',
          icon: LucideIcons.trophy,
          accent: accent,
          isDark: isDark,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: divColor),
            ),
            child: Row(children: [
              Icon(LucideIcons.barChart2, size: 16, color: accent),
              const SizedBox(width: 8),
              Text(league.rule,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // ── 시상 ─────────────────────────────────────────
        if (league.prizeInfo != null && league.prizeInfo!.isNotEmpty) ...[
          _InfoSection(
            title: '시상',
            icon: LucideIcons.gift,
            accent: accent,
            isDark: isDark,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: league.prizeInfo!.split('\n').map((line) =>
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Icon(LucideIcons.medal, size: 14, color: AppColors.gold),
                      const SizedBox(width: 8),
                      Text(line,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── 대회 소개 ─────────────────────────────────────
        if (league.description != null && league.description!.isNotEmpty) ...[
          _InfoSection(
            title: '대회 소개',
            icon: LucideIcons.fileText,
            accent: accent,
            isDark: isDark,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: divColor),
              ),
              child: Text(
                league.description!,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── 섹션 헤더 래퍼 ───────────────────────────────────────
class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.isDark,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Color accent;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 15, color: accent),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 10),
      child,
    ]);
  }
}

// ── 하단 버튼 ────────────────────────────────────────────
class _BottomBar extends ConsumerWidget {
  const _BottomBar({
    required this.league,
    required this.isDark,
    required this.accent,
    required this.joining,
    required this.onJoin,
  });
  final League league;
  final bool isDark;
  final Color accent;
  final bool joining;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 종료된 리그는 하단 버튼 없음
    if (league.status == 'completed' || league.status == 'canceled') {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.share, color: accent),
              label: Text('초대 링크', style: TextStyle(color: accent)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 50),
                side: BorderSide(color: accent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ref.watch(isJoinedProvider(league.id)).when(
              data: (joined) {
                if (joined) {
                  return ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('참가 완료'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
                final canJoin = league.status == 'recruiting';
                return ElevatedButton.icon(
                  onPressed: canJoin && !joining ? onJoin : null,
                  icon: joining
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.how_to_reg_rounded),
                  label: Text(
                    joining ? '신청 중...'
                    : canJoin ? '참가 신청하기'
                    : league.status == 'in_progress' ? '진행중'
                    : '마감',
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              loading: () => ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              ),
              error: (_, __) => ElevatedButton(
                onPressed: onJoin,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('참가 신청하기'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── 통계 박스 ────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value, required this.accent});
  final String label, value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: accent)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11,
                  color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub)),
        ]),
      ),
    );
  }
}
