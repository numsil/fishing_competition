import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/my_league_repository.dart';
import '../../../league/data/league_model.dart';
import '../../../feed/data/post_model.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../../core/extensions/theme_extensions.dart';

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
    final sub = context.isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);
    final cardBg = context.isDark ? AppColors.darkSurface : Colors.white;
    final divColor = context.isDark ? AppColors.darkSurface2 : AppColors.lightDivider;

    // Scaffold는 myLeaguesProvider 밖에 위치 — AppBar/TabBar는 rebuild되지 않음
    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 리그', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        bottom: TabBar(
          controller: _tab,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
          indicatorColor: context.accentColor,
          labelColor: context.accentColor,
          unselectedLabelColor: sub,
          tabs: const [
            Tab(text: '참여 리그'),
            Tab(text: '개인 기록'),
            Tab(text: '개설한 리그'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // 각 탭이 myLeaguesProvider를 독립적으로 구독
          _ActiveTabConsumer(
            isDark: context.isDark,
            accent: context.accentColor,
            sub: sub,
            cardBg: cardBg,
            divColor: divColor,
          ),
          _PersonalRecordTab(
            isDark: context.isDark,
            accent: context.accentColor,
            sub: sub,
            cardBg: cardBg,
            divColor: divColor,
          ),
          _MyLeaguesConsumer(
            isDark: context.isDark,
            accent: context.accentColor,
            sub: sub,
            cardBg: cardBg,
            divColor: divColor,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  참여 리그 탭 ConsumerWidget — myLeaguesProvider 전용
// ─────────────────────────────────────────────────────────────────

class _ActiveTabConsumer extends ConsumerWidget {
  const _ActiveTabConsumer({
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
  });
  final bool isDark;
  final Color accent, sub, cardBg, divColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(myLeaguesProvider).when(
      skipLoadingOnReload: true,
      data: (myLeaguesMap) {
        final participated = myLeaguesMap['participated'] ?? [];
        final activeLeagues = participated
            .where((l) => l.status != 'completed' && l.status != 'canceled')
            .toList();
        return _ActiveTab(
          leagues: activeLeagues,
          isDark: isDark,
          accent: accent,
          sub: sub,
          cardBg: cardBg,
          divColor: divColor,
          onRefresh: () async => ref.invalidate(myLeaguesProvider),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('오류: $e')),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  개설한 리그 탭 ConsumerWidget — myLeaguesProvider 전용
// ─────────────────────────────────────────────────────────────────

class _MyLeaguesConsumer extends ConsumerWidget {
  const _MyLeaguesConsumer({
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
  });
  final bool isDark;
  final Color accent, sub, cardBg, divColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(myLeaguesProvider).when(
      skipLoadingOnReload: true,
      data: (myLeaguesMap) {
        final hosted = myLeaguesMap['hosted'] ?? [];
        return _MyLeaguesTab(
          leagues: hosted,
          isDark: isDark,
          accent: accent,
          sub: sub,
          cardBg: cardBg,
          divColor: divColor,
          onRefresh: () async => ref.invalidate(myLeaguesProvider),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('오류: $e')),
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
    required this.onRefresh,
  });
  final List<League> leagues;
  final bool isDark;
  final Color accent, sub, cardBg, divColor;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (leagues.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _EmptyState(
                isDark: isDark,
                accent: accent,
                sub: sub,
                message: '참여중인 리그가 없습니다',
                buttonLabel: '리그 찾아보기',
                onTap: () => context.go(AppRoutes.league),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _MySummaryCard(activeCount: leagues.length, isDark: isDark, accent: accent, sub: sub, cardBg: cardBg, divColor: divColor),
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
      ),
    );
  }
}

class _MySummaryCard extends ConsumerWidget {
  const _MySummaryCard({
    required this.activeCount,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
  });
  final int activeCount;
  final bool isDark;
  final Color accent, sub, cardBg, divColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(mySeasonStatsProvider);

    String rankValue = '...';
    String fishValue = '...';
    statsAsync.whenData((stats) {
      rankValue = stats.bestRank != null ? '${stats.bestRank}위' : '-';
      fishValue = stats.maxFishLength != null
          ? '${stats.maxFishLength!.toStringAsFixed(1)}cm'
          : '-';
    });
    if (statsAsync.hasError) {
      rankValue = '-';
      fishValue = '-';
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 16,
      borderColor: context.isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
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
              _SummaryItem(value: '$activeCount', label: '참여중', accent: accent),
              _Divider(divColor: divColor),
              _SummaryItem(value: rankValue, label: '최고 순위', accent: AppColors.gold),
              _Divider(divColor: divColor),
              _SummaryItem(value: fishValue, label: '최대어', accent: accent),
              _Divider(divColor: divColor),
              _SummaryItem(value: '-', label: '누적 점수', accent: accent),
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
    final type = isLive ? 'live' : isUpcoming ? 'upcoming' : 'history';

    final startStr = DateFormat('yyyy.MM.dd').format(league.startTime);
    final endStr = DateFormat('yyyy.MM.dd').format(league.endTime);

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
                  value: '-',
                  color: accent,
                  sub: sub,
                  isDark: isDark,
                  divColor: divColor,
                ),
                const SizedBox(width: 10),
                _RecordChip(
                  label: '내 최대어',
                  value: '-',
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

// ── 개인 기록 탭 ─────────────────────────────────────────
class _PersonalRecordTab extends ConsumerWidget {
  const _PersonalRecordTab({
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
  });
  final bool isDark;
  final Color accent, sub, cardBg, divColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);
    final postsAsync = ref.watch(myPersonalRecordsProvider);

    return Stack(
      children: [
        RefreshIndicator(
          color: accent,
          onRefresh: () async {
            ref.invalidate(myProfileProvider);
            ref.invalidate(myPersonalRecordsProvider);
          },
          child: postsAsync.when(
            skipLoadingOnReload: true,
            data: (posts) {
              final totalCatches = posts.fold<int>(0, (s, p) => s + p.catchCount);
              final lunkerCount = posts.where((p) => p.isLunker).length;
              final speciesCount = posts.map((p) => p.fishType).toSet().length;
              double? maxLen;
              Post? maxPost;
              for (final p in posts) {
                if (p.length != null && (maxLen == null || p.length! > maxLen)) {
                  maxLen = p.length;
                  maxPost = p;
                }
              }

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _CatchDashboard(
                        isDark: isDark,
                        accent: accent,
                        sub: sub,
                        cardBg: cardBg,
                        divColor: divColor,
                        postsCount: posts.length,
                        totalCatches: totalCatches,
                        lunkerCount: lunkerCount,
                        speciesCount: speciesCount,
                        maxLength: maxLen,
                        maxPost: maxPost,
                        mannerTemperature: profileAsync.valueOrNull?.mannerTemperature,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Icon(LucideIcons.image, size: 14, color: sub),
                          const SizedBox(width: 6),
                          Text('내 조과 앨범 ${posts.length}장',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sub)),
                        ],
                      ),
                    ),
                  ),
                  if (posts.isEmpty)
                    SliverToBoxAdapter(
                      child: _EmptyCatchAlbum(isDark: isDark, sub: sub),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(2, 0, 2, 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            final post = posts[i];
                            return GestureDetector(
                              onTap: () => context.push(AppRoutes.personalRecordDetail, extra: post),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: post.imageUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
                                      child: Icon(LucideIcons.image, size: 24, color: sub),
                                    ),
                                  ),
                                  if (post.isLunker)
                                    Positioned(
                                      bottom: 4, right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.gold,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          post.length != null ? '${post.length}cm' : '런커',
                                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.black),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                          childCount: posts.length,
                        ),
                      ),
                    ),
                  // 하단 버튼 영역 확보
                  const SliverToBoxAdapter(child: SizedBox(height: 90)),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('불러오기 실패: $e', style: TextStyle(color: sub))),
          ),
        ),
        // ── 하단 고정 버튼 (카메라 + 앨범) ──
        Positioned(
          left: 16, right: 16, bottom: 16,
          child: Row(
            children: [
              // 앨범 버튼
              SizedBox(
                width: 54, height: 54,
                child: OutlinedButton(
                  onPressed: () async {
                    File? picked;
                    try {
                      final img = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                        maxWidth: 1280,
                      );
                      if (img != null) picked = File(img.path);
                    } catch (e) {
                      if (context.mounted) AppSnackBar.error(context, '갤러리 실행 실패: $e');
                      return;
                    }
                    if (picked == null || !context.mounted) return;
                    await context.push(AppRoutes.personalCatch, extra: picked);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: BorderSide(color: accent.withValues(alpha: 0.6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                  ),
                  child: Icon(Icons.photo_library_rounded, size: 22, color: accent),
                ),
              ),
              const SizedBox(width: 10),
              // 카메라 버튼
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      File? captured;
                      try {
                        final picked = await ImagePicker().pickImage(
                          source: ImageSource.camera,
                          imageQuality: 85,
                          maxWidth: 1280,
                        );
                        if (picked != null) captured = File(picked.path);
                      } catch (e) {
                        if (context.mounted) AppSnackBar.error(context, '카메라 실행 실패: $e');
                        return;
                      }
                      if (captured == null || !context.mounted) return;
                      await context.push(AppRoutes.personalCatch, extra: captured);
                    },
                    icon: const Icon(Icons.camera_alt_rounded, size: 22),
                    label: const Text('사진 촬영하기',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 6,
                      shadowColor: accent.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatchDashboard extends StatelessWidget {
  const _CatchDashboard({
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
    required this.postsCount,
    required this.totalCatches,
    required this.lunkerCount,
    required this.speciesCount,
    required this.maxLength,
    required this.maxPost,
    required this.mannerTemperature,
  });

  final bool isDark;
  final Color accent, sub, cardBg, divColor;
  final int postsCount, totalCatches, lunkerCount, speciesCount;
  final double? maxLength;
  final Post? maxPost;
  final double? mannerTemperature;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 메인 통계
        AppCard(
          padding: const EdgeInsets.all(16),
          radius: 16,
          borderColor: divColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.fish, size: 16, color: accent),
                  const SizedBox(width: 8),
                  Text('조과 대시보드',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sub)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _SummaryItem(value: '$postsCount', label: '기록', accent: accent),
                  _Divider(divColor: divColor),
                  _SummaryItem(value: '$totalCatches', label: '총 마릿수', accent: accent),
                  _Divider(divColor: divColor),
                  _SummaryItem(value: '$lunkerCount', label: '런커', accent: AppColors.gold),
                  _Divider(divColor: divColor),
                  _SummaryItem(value: '$speciesCount', label: '어종', accent: accent),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // 최대어 카드
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: maxLength != null ? AppColors.gold.withValues(alpha: 0.06) : cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: maxLength != null ? AppColors.gold.withValues(alpha: 0.25) : divColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(LucideIcons.award, color: AppColors.gold, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('역대 최대어', style: TextStyle(fontSize: 11, color: sub)),
                    const SizedBox(height: 2),
                    Text(
                      maxLength != null
                          ? '${maxPost?.fishType ?? "물고기"} ${maxLength!.toStringAsFixed(1)}cm'
                          : '아직 기록 없음',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: maxLength != null ? AppColors.gold : sub,
                      ),
                    ),
                    if (maxPost != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('yyyy.MM.dd').format(maxPost!.createdAt)}${maxPost!.location != null ? " · ${maxPost!.location}" : ""}',
                        style: TextStyle(fontSize: 11, color: sub),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (mannerTemperature != null) ...[
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.all(14),
            radius: 14,
            borderColor: divColor,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.thermometer, size: 14, color: sub),
                    const SizedBox(width: 6),
                    Text('앵글러 온도',
                        style: TextStyle(fontSize: 12, color: sub, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${mannerTemperature!.toStringAsFixed(1)}°',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: accent)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (mannerTemperature! / 100).clamp(0.0, 1.0),
                    backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
                    valueColor: AlwaysStoppedAnimation(accent),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyCatchAlbum extends StatelessWidget {
  const _EmptyCatchAlbum({required this.isDark, required this.sub});
  final bool isDark;
  final Color sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Icon(LucideIcons.camera,
              size: 52, color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD)),
          const SizedBox(height: 16),
          Text('아직 조과 기록이 없어요',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: sub)),
          const SizedBox(height: 6),
          Text('아래 "사진 촬영하기"로 첫 조과를 남겨보세요',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: sub)),
        ],
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
          AppButton(label: buttonLabel, onPressed: onTap),
        ],
      ),
    );
  }
}

// ── 개설한 리그 탭 ────────────────────────────────────────
class _MyLeaguesTab extends StatelessWidget {
  const _MyLeaguesTab({
    required this.leagues,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
    required this.onRefresh,
  });
  final List<League> leagues;
  final bool isDark;
  final Color accent, sub, cardBg, divColor;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (leagues.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _EmptyState(
                isDark: isDark,
                accent: accent,
                sub: sub,
                message: '개설한 리그가 없습니다',
                buttonLabel: '리그 개설하기',
                onTap: () => context.go(AppRoutes.league),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // 요약 카드
        AppCard(
          padding: const EdgeInsets.all(16),
          radius: 16,
          borderColor: divColor,
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
      ),
    );
  }
}

class _MyLeagueCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
                    label: '${league.participantsCount}/${league.maxParticipants}명',
                    color: isLive && league.participantsCount >= league.maxParticipants
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
