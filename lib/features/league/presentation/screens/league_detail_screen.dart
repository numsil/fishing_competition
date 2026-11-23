import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/league_model.dart';
import '../../data/league_repository.dart';
import '../../data/league_invite_repository.dart';
import 'league_catch_screen.dart';
import '../../data/league_detail_tabs.dart';
import '../widgets/catch_review_tab.dart';
import '../widgets/league_ranking_tab.dart';
import '../widgets/league_team_ranking_tab.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/slide_to_confirm.dart';
import '../../../../core/extensions/theme_extensions.dart';

class LeagueDetailScreen extends ConsumerWidget {
  const LeagueDetailScreen({super.key, required this.leagueId});
  final String leagueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    return ref.watch(leagueDetailProvider(leagueId)).when(
      data: (league) => _LeagueDetailBody(
        league: league,
        isDark: context.isDark,
        accent: context.accentColor,
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  TabController? _tab;
  int _currentTabIndex = 0;
  bool _joining = false;
  bool _cancelling = false;
  RealtimeChannel? _partChannel;
  RealtimeChannel? _inviteChannel;

  /// 지금 화면에 그릴 탭. build 에서 leagueDetailTabs 로 계산해 채운다.
  /// 탭바·TabBarView·컨트롤러 길이가 **모두 이 리스트 하나**를 쓴다.
  List<LeagueDetailTab> _tabs = const [];

  bool get _isHost =>
      ref.read(currentUserProvider)?.id == widget.league.hostId;

  /// 탭 컨트롤러를 만들고 인덱스 리스너를 붙인다.
  /// 재생성 시 리스너를 다시 붙이지 않으면 _currentTabIndex 가 얼어붙어
  /// 하단 조과 버튼 표시가 마지막 값에 멈춘다.
  TabController _newTabController(int length) {
    final c = TabController(length: length, vsync: this);
    c.addListener(() {
      if (c.indexIsChanging || !mounted) return;
      setState(() => _currentTabIndex = c.index);
    });
    return c;
  }

  /// 탭 개수가 바뀌면 컨트롤러를 갈아끼운다.
  ///
  /// 모집중 탭은 내 참가 상태(비동기)에 따라 생겼다 없어지므로 initState
  /// 시점에는 길이를 알 수 없다. build 에서 맞추되, 쓰던 컨트롤러를 build
  /// 도중에 dispose 하면 진행 중인 애니메이션이 터지므로 프레임 뒤로 넘긴다.
  void _syncTabController(int length) {
    if (_tab?.length == length) return;
    final old = _tab;
    _tab = length == 0 ? null : _newTabController(length);
    _currentTabIndex = 0;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  /// 탭 하나의 본문. _tabs 와 **같은 순서**로 쓰이므로 여기서만 매핑한다.
  Widget _tabBody(LeagueDetailTab t, League league, bool isDark, Color accent,
      bool preStart) {
    switch (t) {
      case LeagueDetailTab.team:
        return LeagueTeamRankingTab(
            league: league,
            isDark: isDark,
            accent: accent,
            preStart: preStart);
      case LeagueDetailTab.participants:
        return LeagueRankingTab(
          league: league,
          isDark: isDark,
          accent: accent,
          showRegisterHint: !preStart,
          preStart: preStart,
        );
      case LeagueDetailTab.review:
        return CatchReviewTab(leagueId: league.id);
      case LeagueDetailTab.info:
        return _InfoTab(league: league, isDark: isDark, accent: accent);
    }
  }

  void _refreshAll() {
    // leagueRanking은 무거운 RPC + 5분 keepAlive로 자동 갱신 + 사용자 액션 시
    // 이미 invalidate됨. resume마다 재페치하지 않음.
    ref.invalidate(leagueDetailProvider(widget.league.id));
    ref.invalidate(isJoinedProvider(widget.league.id));
    ref.invalidate(myParticipantStatusProvider(widget.league.id));
    if (_isHost && widget.league.status == 'in_progress') {
      ref.invalidate(leagueCatchesForReviewProvider(widget.league.id));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribeRealtime();
  }

  // 호스트가 참가 승인/거절/초대 취소 등을 했을 때 즉시 반영.
  void _subscribeRealtime() {
    final sb = Supabase.instance.client;
    final myId = sb.auth.currentUser?.id;
    if (myId == null) return;
    final leagueId = widget.league.id;

    // league_participants: 서버 측 user_id 필터로 내 행 변경만 broadcast 받음.
    // (egress 절약. league_id는 클라이언트에서 추가 체크.)
    _partChannel = sb
        .channel('league_part_${leagueId}_$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'league_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: myId,
          ),
          callback: (payload) {
            final row = payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord;
            if (row['league_id'] != leagueId) return;
            if (!mounted) return;
            ref.invalidate(myParticipantStatusProvider(leagueId));
            ref.invalidate(isJoinedProvider(leagueId));
            ref.invalidate(leagueDetailProvider(leagueId));
          },
        )
        .subscribe();

    // league_invites: 서버 측 invitee_id 필터로 나에게 온 초대만 broadcast.
    _inviteChannel = sb
        .channel('league_inv_${leagueId}_$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'league_invites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'invitee_id',
            value: myId,
          ),
          callback: (payload) {
            final row = payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord;
            if (row['league_id'] != leagueId) return;
            if (!mounted) return;
            ref.invalidate(myPendingInviteForLeagueProvider(leagueId));
            ref.invalidate(receivedLeagueInvitesProvider);
          },
        )
        .subscribe();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final sb = Supabase.instance.client;
    final p = _partChannel;
    final i = _inviteChannel;
    if (p != null) sb.removeChannel(p);
    if (i != null) sb.removeChannel(i);
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
      await ref
          .read(leagueRepositoryProvider)
          .joinLeague(widget.league.id);
      ref.invalidate(leagueDetailProvider(widget.league.id));
      ref.invalidate(isJoinedProvider(widget.league.id));
      ref.invalidate(myParticipantStatusProvider(widget.league.id));
      ref.invalidate(leagueRankingProvider(widget.league.id));
      if (mounted) {
        AppSnackBar.success(
          context,
          '참가 신청이 접수되었습니다. 호스트 승인 후 활동 가능합니다.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _cancelJoin() async {
    await showDeleteConfirmSheet(
      context,
      title: '참가 취소',
      content: '정말 참가를 취소하시겠습니까?\n취소 후 재신청이 가능합니다.',
      slideLabel: '밀어서 참가 취소',
      icon: LucideIcons.userMinus,
      onConfirmed: () async {
        setState(() => _cancelling = true);
        try {
          await ref.read(leagueRepositoryProvider).leaveLeague(widget.league.id);
          ref.invalidate(isJoinedProvider(widget.league.id));
          ref.invalidate(myParticipantStatusProvider(widget.league.id));
          ref.invalidate(leagueDetailProvider(widget.league.id));
          ref.invalidate(leagueRankingProvider(widget.league.id));
          if (mounted) AppSnackBar.info(context, '참가가 취소되었습니다.');
        } catch (e) {
          if (mounted) AppSnackBar.error(context, '취소 실패: $e');
        } finally {
          if (mounted) setState(() => _cancelling = false);
        }
      },
    );
  }

  void _shareLeague(BuildContext context) {
    final link = 'https://nakstar.app/league/${widget.league.id}';
    Clipboard.setData(ClipboardData(text: link));
        AppSnackBar.info(context, '초대 링크가 복사되었습니다');
  }

  @override
  Widget build(BuildContext context) {
    final league = widget.league;
    final isDark = widget.isDark;
    final accent = widget.accent;

    // 모집중에는 조과가 없으므로 순위가 아니라 명단으로 그린다.
    final preStart = league.status == 'recruiting';
    _tabs = leagueDetailTabs(
      status: league.status,
      isTeamMode: league.isTeamMode,
      isHost: _isHost,
      myStatus: ref.watch(myParticipantStatusProvider(league.id)).valueOrNull,
    );
    _syncTabController(_tabs.length);
    final hasTabs = _tabs.isNotEmpty;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ── 앱바 ──────────────────────────────────────
          SliverAppBar(
            pinned: true,
            forceElevated: innerBoxIsScrolled,
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () => _shareLeague(context),
              ),
            ],
          ),

          // ── 리그 기본 정보 ──────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(league.title,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      ),
                      if (league.hostUsername.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => context.push('${AppRoutes.userProfile}/${league.hostId}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '리그 개설자',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  UserAvatar(
                                    username: league.hostUsername,
                                    avatarUrl: league.hostAvatarUrl,
                                    radius: 13,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    league.hostUsername,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
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
                  if (league.startTime.hour != 0 || league.startTime.minute != 0 ||
                      league.endTime.hour != 0 || league.endTime.minute != 0) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(LucideIcons.clock, size: 14, color: accent),
                      const SizedBox(width: 4),
                      Text(
                        '${DateFormat('HH:mm').format(league.startTime)}  ~  ${DateFormat('HH:mm').format(league.endTime)}',
                        style: TextStyle(fontSize: 13,
                            color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── 탭바 (고정) ─────────────────────────────
          if (hasTabs)
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                tabBar: TabBar(
                  controller: _tab,
                  tabs: [
                    for (final t in _tabs)
                      Tab(text: leagueDetailTabLabel(t, league.status)),
                  ],
                ),
                isDark: isDark,
              ),
            ),
        ],

        // ── 탭 바디 ─────────────────────────────────
        body: hasTabs
            ? TabBarView(
                controller: _tab,
                children: [
                  for (final t in _tabs)
                    _tabBody(t, league, isDark, accent, preStart),
                ],
              )
            : _InfoTab(league: league, isDark: isDark, accent: accent),
      ),

      // ── 하단 버튼 ──────────────────────────────────
      bottomNavigationBar: _BottomBar(
        league: league,
        isDark: isDark,
        accent: accent,
        joining: _joining,
        cancelling: _cancelling,
        onJoin: _join,
        onCancelJoin: _cancelJoin,
        showCatchButton: isRankingTabIndex(_currentTabIndex,
            isTeamMode: widget.league.isTeamMode),
      ),
    );
  }
}

// ── 탭바 고정 헤더 delegate ──────────────────────────────
/// 하단 "조과 사진 등록" 버튼을 보여줄 탭인지.
///
/// 순위 탭은 팀전이면 두 개다 (0: 팀 순위, 1: 개인 순위). 팀 탭을 맨 앞에
/// 끼워 넣으면서 이 조건을 `index == 0` 으로 두면 개인 순위 탭에서 버튼이
/// 사라지고, 그 탭의 "아래 버튼으로 첫 조과를 등록해보세요!" 안내가 없는
/// 버튼을 가리키게 된다.
@visibleForTesting
bool isRankingTabIndex(int index, {required bool isTeamMode}) =>
    index <= (isTeamMode ? 1 : 0);

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabBarDelegate({required this.tabBar, required this.isDark});
  final TabBar tabBar;
  final bool isDark;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? AppColors.darkBg : Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar || isDark != oldDelegate.isDark;
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
    final divColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // ── 핵심 스탯 4칸 ─────────────────────────────
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
          _StatBox(label: '순위 방식', value: _ruleLabel(league), accent: accent),
          const SizedBox(width: 10),
          _StatBox(
            label: '공개',
            value: league.isPublic ? '공개 리그' : '비공개',
            accent: accent,
          ),
        ]),
        const SizedBox(height: 20),

        // ── 참가 현황 바 ─────────────────────────────
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

        // ── 대상 어종 ─────────────────────────────────
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

        // ── 순위 결정 방식 ────────────────────────────
        _InfoSection(
          title: '순위 결정 방식',
          icon: LucideIcons.trophy,
          accent: accent,
          isDark: isDark,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            radius: 10,
            borderColor: divColor,
            child: Row(children: [
              Icon(LucideIcons.barChart2, size: 16, color: accent),
              const SizedBox(width: 8),
              Text(_ruleLabel(league),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        const SizedBox(height: 16),

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

        if (league.description != null && league.description!.isNotEmpty) ...[
          _InfoSection(
            title: '대회 소개',
            icon: LucideIcons.fileText,
            accent: accent,
            isDark: isDark,
            child: AppCard(
              padding: const EdgeInsets.all(14),
              radius: 12,
              borderColor: divColor,
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
          const SizedBox(height: 16),
        ],

        // ── 소개 이미지 ───────────────────────────────
        if (league.introImageUrls.isNotEmpty) ...[
          _InfoSection(
            title: '소개 이미지',
            icon: LucideIcons.image,
            accent: accent,
            isDark: isDark,
            child: _IntroImageGallery(
              imageUrls: league.introImageUrls,
              divColor: divColor,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

// ── 소개 이미지 갤러리 ───────────────────────────────────
class _IntroImageGallery extends StatefulWidget {
  const _IntroImageGallery({required this.imageUrls, required this.divColor});
  final List<String> imageUrls;
  final Color divColor;

  @override
  State<_IntroImageGallery> createState() => _IntroImageGalleryState();
}

class _IntroImageGalleryState extends State<_IntroImageGallery> {
  int _currentIndex = 0;
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openFullscreen(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenImageViewer(
          imageUrls: widget.imageUrls,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: PageView.builder(
              controller: _pageController,
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _openFullscreen(i),
                child: CachedNetworkImage(
                  imageUrl: urls[i],
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, __, ___) => Container(
                    color: widget.divColor,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, size: 36, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (urls.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(urls.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentIndex == i ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentIndex == i ? Colors.grey[600] : Colors.grey[400],
                borderRadius: BorderRadius.circular(3),
              ),
            )),
          ),
        ],
      ],
    );
  }
}

// ── 이미지 전체화면 뷰어 ─────────────────────────────────
class _FullscreenImageViewer extends StatefulWidget {
  const _FullscreenImageViewer({required this.imageUrls, required this.initialIndex});
  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late int _current;
  late final PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_current + 1} / ${widget.imageUrls.length}',
            style: const TextStyle(color: Colors.white)),
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.imageUrls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: CachedNetworkImage(
              imageUrl: widget.imageUrls[i],
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) => const Icon(
                Icons.broken_image_outlined, size: 64, color: Colors.white54),
            ),
          ),
        ),
      ),
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
    required this.cancelling,
    required this.onJoin,
    required this.onCancelJoin,
    this.showCatchButton = true,
  });
  final League league;
  final bool isDark;
  final Color accent;
  final bool joining;
  final bool cancelling;
  final VoidCallback onJoin;
  final VoidCallback onCancelJoin;
  final bool showCatchButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (league.status == 'completed' || league.status == 'canceled') {
      return const SizedBox.shrink();
    }

    // ── 받은 pending 초대 있으면 수락/거절 우선 노출 (공개·비공개 공통) ──
    // (참가자 status가 아직 approved 아닐 때만; approved면 일반 흐름)
    {
      final inviteAsync =
          ref.watch(myPendingInviteForLeagueProvider(league.id));
      final partStatus = ref.watch(myParticipantStatusProvider(league.id));
      final invite = inviteAsync.valueOrNull;
      final pStatus = partStatus.valueOrNull;
      if (invite != null && pStatus != 'approved') {
        return SafeArea(
          minimum: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: _InviteResponseSection(invite: invite, league: league),
          ),
        );
      }
    }

    // ── 진행중: 참가자에게만 카메라 버튼 (순위 탭에서만) ─────
    if (league.status == 'in_progress') {
      if (!showCatchButton) return const SizedBox.shrink();
      return ref.watch(myParticipantStatusProvider(league.id)).when(
        data: (status) {
          if (status != 'approved') return const SizedBox.shrink();
          return SafeArea(
            minimum: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Row(
                children: [
                  // 앨범 버튼 (리그 설정에서 허용한 경우만)
                  if (league.allowGallery) ...[
                    SizedBox(
                      width: 54, height: 54,
                      child: OutlinedButton(
                        onPressed: () async {
                          File? picked;
                          try {
                            final img = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                            );
                            if (img != null) picked = File(img.path);
                          } catch (e) {
                            if (context.mounted) AppSnackBar.error(context, '갤러리 실행 실패: $e');
                            return;
                          }
                          if (picked == null || !context.mounted) return;
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (_) => LeagueCatchScreen(league: league, initialImage: picked),
                            ),
                          );
                          if (result == true) ref.invalidate(leagueRankingProvider(league.id));
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
                  ],
                  // 카메라 버튼
                  Expanded(
                    child: AppButton(
                      label: '조과 사진 등록',
                      icon: Icons.camera_alt_rounded,
                      onPressed: () async {
                        File? captured;
                        try {
                          final picked = await ImagePicker().pickImage(
                            source: ImageSource.camera,
                          );
                          if (picked != null) captured = File(picked.path);
                        } catch (e) {
                          if (context.mounted) AppSnackBar.error(context, '카메라 실행 실패: $e');
                          return;
                        }
                        if (captured == null || !context.mounted) return;
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => LeagueCatchScreen(league: league, initialImage: captured),
                          ),
                        );
                        if (result == true) ref.invalidate(leagueRankingProvider(league.id));
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      );
    }

    // ── 모집중: 참가 신청 / 참가 취소 ────────────────
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: ref.watch(myParticipantStatusProvider(league.id)).when(
          data: (status) {
            // 승인 대기 중 → 안내 + 취소 버튼
            if (status == 'pending') {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.clock, size: 18, color: AppColors.warning),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            '호스트 승인을 기다리는 중입니다',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: '신청 취소',
                    onPressed: cancelling ? null : onCancelJoin,
                    variant: AppButtonVariant.outline,
                    tone: AppButtonTone.error,
                    icon: LucideIcons.userMinus,
                    loading: cancelling,
                  ),
                ],
              );
            }
            // 거절·강퇴된 상태 → 비활성 안내
            if (status == 'rejected') {
              return Container(
                width: double.infinity,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  '참가가 거절되었습니다',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              );
            }
            if (status == 'approved') {
              // 참가 완료 상태 → 취소 버튼
              return AppButton(
                label: '참가 취소',
                onPressed: cancelling ? null : onCancelJoin,
                variant: AppButtonVariant.outline,
                tone: AppButtonTone.error,
                icon: LucideIcons.userMinus,
                loading: cancelling,
              );
            }
            // 미참가 → 비공개 리그는 초대 전용 안내 (위에서 invite는 이미 처리됨)
            if (!league.isPublic) {
              return Container(
                width: double.infinity,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.lock,
                        size: 16,
                        color: isDark ? const Color(0xFF888888) : const Color(0xFF888888)),
                    const SizedBox(width: 8),
                    Text(
                      '초대받은 사람만 참여할 수 있어요',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF999999) : const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              );
            }
            // 미참가 → 정원 초과 여부 확인
            final isFull = league.maxParticipants > 0 &&
                league.participantsCount >= league.maxParticipants;
            if (isFull) {
              return AppButton(
                label: '모집 마감',
                onPressed: null,
                icon: Icons.block_rounded,
                disabledColor:
                    isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
                disabledLabelColor:
                    isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA),
              );
            }
            return AppButton(
              label: '참가 신청하기',
              onPressed: joining ? null : onJoin,
              icon: Icons.how_to_reg_rounded,
              loading: joining,
            );
          },
          loading: () => const AppButton(
            label: '참가 신청하기',
            onPressed: null,
            loading: true,
          ),
          error: (_, __) => AppButton(
            label: '참가 신청하기',
            onPressed: onJoin,
          ),
        ),
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.accentColor.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: context.accentColor)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11,
                  color: context.isDark ? AppColors.darkTextSub : AppColors.lightTextSub)),
        ]),
      ),
    );
  }
}

// ── 초대 수락/거절 섹션 ────────────────────────────────
class _InviteResponseSection extends ConsumerStatefulWidget {
  const _InviteResponseSection({required this.invite, required this.league});
  final LeagueInvite invite;
  final League league;

  @override
  ConsumerState<_InviteResponseSection> createState() =>
      _InviteResponseSectionState();
}

class _InviteResponseSectionState
    extends ConsumerState<_InviteResponseSection> {
  bool _busy = false;

  Future<void> _respond(bool accept) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(leagueInviteRepositoryProvider)
          .respondInvite(widget.invite.id, accept: accept);
      ref.invalidate(myPendingInviteForLeagueProvider(widget.league.id));
      ref.invalidate(receivedLeagueInvitesProvider);
      if (accept) {
        ref.invalidate(myParticipantStatusProvider(widget.league.id));
        ref.invalidate(isJoinedProvider(widget.league.id));
        ref.invalidate(leagueDetailProvider(widget.league.id));
        ref.invalidate(leagueRankingProvider(widget.league.id));
      }
      if (mounted) {
        AppSnackBar.success(
          context,
          accept ? '초대를 수락했어요! 🎣' : '초대를 거절했어요',
        );
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, _humanize(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanize(Object e) {
    final s = e.toString();
    final m = RegExp(r'message:\s*([^,}]+)').firstMatch(s);
    if (m != null) return m.group(1)!.trim();
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.mail, size: 18, color: accent),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '이 리그에 초대받았어요',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: '거절',
                onPressed: _busy ? null : () => _respond(false),
                variant: AppButtonVariant.outline,
                tone: AppButtonTone.error,
                icon: LucideIcons.x,
                loading: _busy,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppButton(
                label: '수락하고 참가',
                onPressed: _busy ? null : () => _respond(true),
                icon: Icons.how_to_reg_rounded,
                loading: _busy,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── 룰 레이블 헬퍼 ───────────────────────────────────────
String _ruleLabel(League league) {
  if (league.rule == '마릿수') return '마릿수';
  final limit = league.catchLimit;
  final limitStr = limit == 0 ? '전체' : '${limit}마리';
  switch (league.rule) {
    case '최대어':   return '$limitStr 최대어';
    case '합산 길이': return '$limitStr 합산 길이';
    case '무게':     return '$limitStr 무게 합산';
    default:        return '$limitStr ${league.rule}';
  }
}
