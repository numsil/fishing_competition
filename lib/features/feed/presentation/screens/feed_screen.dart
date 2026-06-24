import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/post_image_carousel.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/feed_repository.dart';
import '../../data/post_model.dart';
import '../../../follow/data/follow_repository.dart';
import 'dart:async';
import 'dart:math';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/slide_to_confirm.dart';
import '../../../../core/utils/banned_error_handler.dart';
import '../../../../core/utils/time_ago.dart';
import '../../../../core/widgets/menu_item.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../dm/data/dm_repository.dart';
import '../../../ads/data/ad_model.dart';
import '../../../ads/data/ad_repository.dart';
import '../../../ads/presentation/widgets/ad_card.dart';
import '../utils/feed_search_utils.dart';
import '../../../report/presentation/widgets/report_reason_sheet.dart';
import '../../../marketplace/presentation/screens/marketplace_screen.dart';
import '../../../marketplace/presentation/screens/marketplace_upload_screen.dart';
import '../../../notifications/data/notification_repository.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isSearching = false;
  String _searchQuery = '';
  late final TextEditingController _searchCtrl;
  late final ScrollController _scrollCtrl;

  // 영상 게시물용 GlobalKey 저장소 (post.id → key). 스크롤 종료 시
  // 가까운 영상 카드를 viewport 상단에 정렬하기 위해 사용.
  final Map<String, GlobalKey> _videoPostKeys = {};
  bool _isSnapping = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchCtrl = TextEditingController();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isSearching) return;
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      ref.read(feedPostsProvider.notifier).loadMore();
    }
  }

  /// 게시물 사이에 광고를 minGap~maxGap 인터벌로 결정적 삽입.
  /// - post.id 해시 기반으로 다음 광고 위치 산정 → 같은 입력엔 같은 결과
  /// - 광고가 부족하면 라운드로빈 (활성 광고 1개라도 있으면 채움)
  List<Object> _interleaveAds(
    List<Post> posts,
    List<AdFeed> ads, {
    required int minGap,
    required int maxGap,
  }) {
    if (ads.isEmpty || posts.isEmpty) return List<Object>.from(posts);
    final lo = minGap > 0 ? minGap : 5;
    final hi = maxGap >= lo ? maxGap : lo;
    final range = hi - lo + 1;
    final result = <Object>[];
    int adIdx = 0;
    int sinceLastAd = 0;
    int nextAdAt = lo + (posts.first.id.hashCode.abs() % range);
    for (int i = 0; i < posts.length; i++) {
      result.add(posts[i]);
      sinceLastAd++;
      if (sinceLastAd >= nextAdAt) {
        result.add(ads[adIdx % ads.length]);
        adIdx++;
        sinceLastAd = 0;
        nextAdAt = lo + (posts[i].id.hashCode.abs() % range);
      }
    }
    return result;
  }

  bool _onScrollNotification(ScrollNotification notif) {
    // 자식 스크롤(즐겨찾기 가로 리스트 등)의 알림은 무시
    if (notif.depth != 0) return false;
    if (notif.metrics.axis != Axis.vertical) return false;
    if (notif is ScrollEndNotification) {
      if (_isSnapping) {
        _isSnapping = false;
        return false;
      }
      _maybeSnapToVideo();
    }
    return false;
  }

  /// 영상 게시물 중 viewport 상단 근처에 있는 것을 찾아 정렬.
  void _maybeSnapToVideo() {
    if (_isSearching) return;
    if (!_scrollCtrl.hasClients) return;
    if (!mounted) return;

    final scrollableCtx = _scrollCtrl.position.context.notificationContext;
    if (scrollableCtx == null) return;
    final scrollableBox = scrollableCtx.findRenderObject() as RenderBox?;
    if (scrollableBox == null || !scrollableBox.attached) return;

    // 절대 좌표 기준으로 viewport 상단 위치 계산 (ancestor 인자 없이 사용해 안정성 확보)
    final viewportTop = scrollableBox.localToGlobal(Offset.zero).dy;
    final viewportH = _scrollCtrl.position.viewportDimension;

    BuildContext? bestCtx;
    double bestDist = double.infinity;

    for (final key in _videoPostKeys.values) {
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;

      final postTop = box.localToGlobal(Offset.zero).dy;
      final dy = postTop - viewportTop;
      // 카드 상단이 화면 위로 자기 높이 이상 벗어났거나, 화면 절반 아래로
      // 내려가 있으면 후보 제외.
      if (dy < -box.size.height) continue;
      if (dy > viewportH * 0.5) continue;

      final dist = dy.abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestCtx = ctx;
      }
    }

    if (bestCtx == null) return;
    if (bestDist < 8) return; // 이미 정렬돼 있으면 스킵

    _isSnapping = true;
    Scrollable.ensureVisible(
      bestCtx,
      alignment: 0.0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    ).whenComplete(() {
      if (mounted) _isSnapping = false;
    });
  }

  void _onSearchChanged(String value) => setState(() {
        _searchQuery = value;
        _isSearching = value.isNotEmpty;
      });

  void _onSearchClear() {
    _searchCtrl.clear();
    setState(() {
      _searchQuery = '';
      _isSearching = false;
    });
  }

  // 피드/중고거래 상단 검색 입력 바 (그 자리에서 바로 입력). 즐겨찾기 바를 대체.
  Widget _buildSearchBar(BuildContext context) {
    final isDark = context.isDark;
    final hint = isDark ? const Color(0xFF888888) : const Color(0xFFAAAAAA);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: '검색',
          hintStyle: TextStyle(fontSize: 14, color: hint),
          prefixIcon: Icon(LucideIcons.search, size: 18, color: hint),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: _onSearchClear,
                  icon: Icon(LucideIcons.x, size: 16, color: hint),
                  visualDensity: VisualDensity.compact,
                )
              : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF0F0F0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
        ),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accent = context.accentColor;
    return Scaffold(
      appBar: _FeedAppBar(
        isDark: isDark,
        accent: accent,
        tabController: _tabController,
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // 탭 1: 조과 피드
          RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(feedPostsProvider);
          ref.invalidate(myFollowingsForFeedProvider);
        },
        child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            SliverToBoxAdapter(
              child: _buildSearchBar(context),
            ),
            ...ref.watch(feedPostsProvider).when(
              data: (posts) {
                final filtered = filterPosts(posts, _searchQuery);
                final showLoadMore = !_isSearching &&
                    _searchQuery.isEmpty &&
                    ref.read(feedPostsProvider.notifier).hasMore &&
                    posts.isNotEmpty;

                // 검색 중이 아닐 때만 광고 인터리브
                final rawAds = (_isSearching || _searchQuery.isNotEmpty)
                    ? const <AdFeed>[]
                    : (ref.watch(activeFeedAdsProvider).valueOrNull ?? const []);
                // 유저×날짜 시드로 셔플 → 사용자별로 광고 노출 분포 균등화.
                // 같은 사용자가 같은 날 안에선 순서 일정 (스크롤 안정성).
                final myId =
                    ref.watch(currentUserProvider)?.id ?? 'anon';
                final today = DateTime.now().toUtc();
                final dayKey = '${today.year}-${today.month}-${today.day}';
                final seed = ('$myId|$dayKey').hashCode;
                final ads = List<AdFeed>.from(rawAds)..shuffle(Random(seed));
                final gap = ref.watch(adGapConfigProvider).valueOrNull ??
                    const AdGapConfig(minGap: 5, maxGap: 7);
                final items = _interleaveAds(
                  filtered,
                  ads,
                  minGap: gap.minGap,
                  maxGap: gap.maxGap,
                );

                return [
                  if (_isSearching && _searchQuery.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _SearchResultBanner(
                        count: filtered.length,
                        isDark: context.isDark,
                      ),
                    ),
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? '아직 올라온 피드가 없습니다.\n첫 사진을 올려보세요!'
                              : '검색 결과가 없습니다.',
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final item = items[i];
                          if (item is AdFeed) {
                            final slotKey = '${item.id}_$i';
                            return KeyedSubtree(
                              key: ValueKey('ad_$slotKey'),
                              child: AdCard(ad: item, slotKey: slotKey),
                            );
                          }
                          final post = item as Post;
                          final isVideo = post.videoUrl != null;
                          final key = isVideo
                              ? (_videoPostKeys[post.id] ??= GlobalKey())
                              : null;
                          return KeyedSubtree(
                            key: key,
                            child: _InstaPost(
                              post: post,
                              isDark: context.isDark,
                              accent: context.accentColor,
                            ),
                          );
                        },
                        childCount: items.length,
                      ),
                    ),
                  if (showLoadMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ];
              },
              loading: () => [
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (e, st) => [
                const SliverFillRemaining(
                  child: Center(child: Text('피드를 불러오지 못했습니다.')),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
          // 탭 2: 중고거래
          Column(
            children: [
              _buildSearchBar(context),
              Expanded(child: MarketplaceScreen(searchQuery: _searchQuery)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 검색 결과 배너 ─────────────────────────────────────
class _SearchResultBanner extends StatelessWidget {
  const _SearchResultBanner({required this.count, required this.isDark});
  final int count;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
      child: Text(
        '결과 $count개',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373),
        ),
      ),
    );
  }
}

// ── AppBar ───────────────────────────────────────────────
class _FeedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _FeedAppBar({
    required this.isDark,
    required this.accent,
    required this.tabController,
  });

  final bool isDark;
  final Color accent;
  final TabController tabController;

  @override
  Size get preferredSize => const Size.fromHeight(44 + 40);

  @override
  Widget build(BuildContext context) {

    // 탭별로 공유/전용 액션 빌더
    Widget unitsBtn() => IconButton(
          onPressed: () => context.push(AppRoutes.units),
          icon: Icon(LucideIcons.ruler,
              color: isDark ? Colors.white : Colors.black, size: 22),
          visualDensity: VisualDensity.compact,
        );

    Widget notiBtn() => Consumer(
          builder: (context, ref, _) {
            final hasUnread =
                ref.watch(hasUnreadNotificationsProvider).valueOrNull ?? false;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () => context.push(AppRoutes.notifications),
                  icon: Icon(LucideIcons.bell,
                      color: isDark ? Colors.white : Colors.black, size: 22),
                  visualDensity: VisualDensity.compact,
                ),
                if (hasUnread)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          },
        );

    Widget dmBtn() => Consumer(
          builder: (context, ref, _) {
            final hasUnread =
                ref.watch(hasUnreadDmsProvider).valueOrNull ?? false;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () => context.push(AppRoutes.dm),
                  icon: Icon(LucideIcons.send,
                      color: isDark ? Colors.white : Colors.black, size: 22),
                  visualDensity: VisualDensity.compact,
                ),
                if (hasUnread)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          },
        );

    Widget plusBtn(VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(left: 4, right: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              LucideIcons.plus,
              color: isDark ? Colors.black : Colors.white,
              size: 18,
            ),
          ),
        );

    return AppBar(
      toolbarHeight: 44,
      backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: TabBar(
        controller: tabController,
        indicatorColor: accent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorWeight: 2,
        labelColor: accent,
        unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: '피드'),
          Tab(text: '중고거래'),
        ],
      ),
      titleSpacing: 12,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/images/nakstar.svg',
            height: 26,
            fit: BoxFit.contain,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          notiBtn(),
        ],
      ),
      actions: [
        ListenableBuilder(
          listenable: tabController,
          builder: (context, _) {
            final isMarket = tabController.index == 1;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: isMarket
                  // 중고거래: DM · 등록(+)  (검색은 탭 상단 바)
                  ? [
                      dmBtn(),
                      plusBtn(() => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const MarketplaceUploadScreen()),
                          )),
                    ]
                  // 조과: 자 · DM · 글쓰기(+)  (검색은 피드 상단 바, 알림은 로고 옆)
                  : [
                      unitsBtn(),
                      dmBtn(),
                      plusBtn(() => context.push(AppRoutes.upload)),
                    ],
            );
          },
        ),
      ],
    );
  }
}

// ── 인스타그램 스타일 포스트 ──────────────────────────────
class _InstaPost extends ConsumerStatefulWidget {
  const _InstaPost({required this.post, required this.isDark, required this.accent});
  final Post post;
  final bool isDark;
  final Color accent;

  @override
  ConsumerState<_InstaPost> createState() => _InstaPostState();
}

class _InstaPostState extends ConsumerState<_InstaPost> {
  // 댓글 목록 (로컬 상태)
  late List<_Comment> _comments;

  @override
  void initState() {
    super.initState();
    _comments = [];
  }

  /// 캡션에서 해시태그(#으로 시작하는 단어)를 제거한 텍스트 반환
  String _stripHashtags(String caption) {
    return caption
        .split(RegExp(r'\s+'))
        .where((w) => !w.startsWith('#'))
        .join(' ')
        .trim();
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentSheet(
        post: widget.post,
        isDark: widget.isDark,
        accent: widget.accent,
        comments: _comments,
        onCommentAdded: (c) => setState(() => _comments.add(c)),
      ),
    );
  }

  void _openMoreMenu() {
    final isDark = widget.isDark;
    final currentUserId = ref.read(currentUserProvider)?.id;
    final isOwner =
        currentUserId != null && currentUserId == widget.post.userId;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _MoreMenu(
        isDark: isDark,
        postId: widget.post.id,
        isOwner: isOwner,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final isDark = widget.isDark;
    final accent = widget.accent;
    final iconColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);
    final bgColor = isDark ? AppColors.darkBg : Colors.white;
    final commentCount = p.commentsCount;
    final hashTags = extractHashtags(p.caption);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 헤더 ──
        Container(
          color: bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.push('${AppRoutes.userProfile}/${p.userId}'),
                child: UserAvatar(
                  username: p.username,
                  avatarUrl: p.avatarUrl.isNotEmpty ? p.avatarUrl : null,
                  radius: 16,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('${AppRoutes.userProfile}/${p.userId}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            p.username,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                      if (p.userKey.isNotEmpty)
                        Text('@${p.userKey}', style: TextStyle(fontSize: 11, color: subColor)),
                      if (p.location != null)
                        Text(p.location!, style: TextStyle(fontSize: 11, color: subColor)),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: _openMoreMenu,
                icon: Icon(LucideIcons.moreHorizontal, color: iconColor, size: 20),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),

        // ── 어종 정보 칩 ──
        if (p.length != null || p.weight != null || p.catchCount > 1)
          Container(
            color: bgColor,
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
            child: Row(
              children: [
                if (p.length != null) ...[
                  Icon(LucideIcons.ruler, size: 12, color: accent),
                  const SizedBox(width: 4),
                  Text(
                    '${p.length!.toStringAsFixed(1)}cm',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent),
                  ),
                  const SizedBox(width: 12),
                ],
                if (p.weight != null) ...[
                  Icon(LucideIcons.scale, size: 12, color: subColor),
                  const SizedBox(width: 4),
                  Text(
                    '${(p.weight! / 1000).toStringAsFixed(p.weight! >= 1000 ? 2 : 1)}kg',
                    style: TextStyle(fontSize: 13, color: subColor),
                  ),
                  const SizedBox(width: 12),
                ],
                if (p.catchCount > 1) ...[
                  Icon(LucideIcons.fish, size: 12, color: subColor),
                  const SizedBox(width: 4),
                  Text(
                    '${p.catchCount}마리',
                    style: TextStyle(fontSize: 13, color: subColor),
                  ),
                ],
              ],
            ),
          ),

        // ── 미디어 (이미지 슬라이드 or 동영상) ──
        PostImageCarousel(
          post: p,
          isDark: isDark,
          accent: accent,
        ),

        // ── 액션 버튼 ──
        Container(
          color: bgColor,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
          child: Row(
            children: [
              // 좋아요
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    ref.read(feedPostsProvider.notifier).toggleLike(p.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Icon(
                    p.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: p.isLiked ? AppColors.error : iconColor,
                    size: 22,
                  ),
                ),
              ),
              if (p.likeCount > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '${p.likeCount}',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: iconColor),
                ),
              ],
              const SizedBox(width: 16),
              // 댓글
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openComments,
                child: Icon(LucideIcons.messageCircle, color: iconColor, size: 22),
              ),
              if (commentCount > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '$commentCount',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: iconColor),
                ),
              ],
              const SizedBox(width: 16),
              // 공유
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final link = 'https://nakstar.app/post/${p.id}';
                  Clipboard.setData(ClipboardData(text: link));
                  AppSnackBar.info(context, '링크가 복사되었습니다');
                },
                child: Icon(LucideIcons.share2, color: iconColor, size: 22),
              ),
            ],
          ),
        ),

        // ── 캡션 (해시태그 제외한 일반 텍스트만) ──
        if (p.caption != null && p.caption!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: p.username,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const TextSpan(text: '  '),
                  TextSpan(
                    text: _stripHashtags(p.caption!),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        // ── 해시태그 행 ──
        if (hashTags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 3, 16, 0),
            child: Text(
              hashTags.join('  '),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF4A9ECC) : const Color(0xFF00376B),
              ),
            ),
          ),

        // ── 댓글 더보기 ──
        if (commentCount > 0)
          GestureDetector(
            onTap: _openComments,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
              child: Text(
                '댓글 $commentCount개 모두 보기',
                style: TextStyle(fontSize: 13, color: subColor),
              ),
            ),
          ),

        // ── 최신 댓글 1개 미리보기 ──
        if (_comments.isNotEmpty)
          GestureDetector(
            onTap: _openComments,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 3, 16, 0),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _comments.last.user,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const TextSpan(text: '  '),
                    TextSpan(
                      text: _comments.last.text,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

        // ── 시간 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 5, 16, 12),
          child: Text(
            formatTimeAgo(p.createdAt),
            style: TextStyle(fontSize: 10, color: subColor),
          ),
        ),

        Divider(
          height: 0.5,
          thickness: 0.5,
          color: isDark ? const Color(0xFF262626) : const Color(0xFFDBDBDB),
        ),
      ],
    );
  }
}

// ── 더보기 메뉴 (••• 버튼) ────────────────────────────
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.isDark,
    required this.postId,
    required this.isOwner,
  });
  final bool isDark;
  final String postId;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;
    final divColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          AppMenuItem(
            icon: LucideIcons.link2,
            label: '링크 복사',
            color: textColor,
            onTap: () {
              Navigator.pop(context);
              final link = 'https://nakstar.app/post/$postId';
              Clipboard.setData(ClipboardData(text: link));
                            AppSnackBar.info(context, '링크가 복사되었습니다');
            },
          ),
          Divider(height: 1, color: divColor),
          AppMenuItem(
            icon: LucideIcons.share,
            label: '공유하기',
            color: textColor,
            onTap: () => Navigator.pop(context),
          ),
          if (!isOwner) ...[
            Divider(height: 1, color: divColor),
            AppMenuItem(
              icon: LucideIcons.flag,
              label: '신고하기',
              color: AppColors.error,
              onTap: () {
                Navigator.pop(context);
                ReportReasonSheet.show(context, postId);
              },
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── 댓글 시트 ─────────────────────────────────────────
class _CommentSheet extends ConsumerStatefulWidget {
  const _CommentSheet({
    required this.post,
    required this.isDark,
    required this.accent,
    required this.comments,
    required this.onCommentAdded,
  });
  final Post post;
  final bool isDark;
  final Color accent;
  final List<_Comment> comments;
  final ValueChanged<_Comment> onCommentAdded;

  @override
  ConsumerState<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends ConsumerState<_CommentSheet> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  late List<_Comment> _localComments;
  String? _replyTo;
  String? _editingId; // 수정 중인 댓글 id (null이면 일반 작성 모드)
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _localComments = [];
    Future.microtask(() => _loadComments());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// "수정" 탭 → 해당 댓글 본문을 입력창에 불러오고 수정 모드 진입.
  void _startEditComment(_Comment comment) {
    if (comment.id.isEmpty) return;
    setState(() {
      _editingId = comment.id;
      _replyTo = null;
      _ctrl.text = comment.text;
      _ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _ctrl.text.length),
      );
    });
    _focusNode.requestFocus();
  }

  void _cancelEdit() {
    setState(() => _editingId = null);
    _ctrl.clear();
    _focusNode.unfocus();
  }

  /// 댓글 꾹 누르면 뜨는 액션 시트. 본인 댓글: 수정/삭제, 남의 댓글: 신고.
  void _showCommentActions(_Comment comment) {
    if (comment.id.isEmpty) return;
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        Widget action(IconData icon, String label, Color color, VoidCallback onTap) {
          return ListTile(
            leading: Icon(icon, color: color, size: 22),
            title: Text(label,
                style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(ctx);
              onTap();
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              if (comment.isMe) ...[
                action(LucideIcons.pencil, '수정', textColor, () => _startEditComment(comment)),
                action(LucideIcons.trash2, '삭제', AppColors.error, () => _confirmDeleteComment(comment)),
              ] else
                action(LucideIcons.flag, '신고', AppColors.error, () {
                  ReportReasonSheet.showForComment(context, comment.id, postId: widget.post.id);
                }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadComments() async {
    try {
      final data = await ref.read(feedRepositoryProvider).getComments(widget.post.id);
      if (!mounted) return;
      final currentUser = ref.read(currentUserProvider);
      setState(() {
        _localComments = data.map((d) => _commentFromDb(d, currentUser?.id ?? '')).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  _Comment _commentFromDb(Map<String, dynamic> data, String currentUserId) {
    final usersData = data['users'] as Map?;
    final username = usersData?['username'] as String? ?? '알 수 없음';
    final avatarUrl = usersData?['avatar_url'] as String? ?? '';
    final userKey = usersData?['user_key'] as String? ?? '';
    final userId = data['user_id'] as String? ?? '';
    final createdAt = DateTime.tryParse(data['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now();
    final timeAgo = formatTimeAgo(createdAt);
    return _Comment(
      id: data['id'] as String? ?? '',
      user: username,
      text: data['content'] as String? ?? '',
      timeAgo: timeAgo,
      isMe: userId == currentUserId,
      userId: userId,
      userKey: userKey,
      avatarUrl: avatarUrl,
    );
  }

  Future<void> _confirmDeleteComment(_Comment comment) async {
    if (comment.id.isEmpty) return;
    showDeleteConfirmSheet(
      context,
      title: '댓글 삭제',
      content: '이 댓글을 삭제하시겠습니까?',
      onConfirmed: () async {
        try {
          await ref.read(feedRepositoryProvider).deleteComment(comment.id);
          if (!mounted) return;
          setState(() => _localComments.removeWhere((c) => c.id == comment.id));
          ref.invalidate(feedPostsProvider);
        } catch (e) {
          if (mounted) AppSnackBar.error(context, '삭제 실패: $e');
        }
      },
    );
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    // 수정 모드: 해당 댓글만 로컬에서 즉시 교체(낙관적) → 서버 반영 → 실패 시 롤백.
    // (전체 재조회 _loadComments를 없애 ap-south-1 왕복 1회로 단축, 즉시 반영)
    if (_editingId != null) {
      final id = _editingId!;
      final idx = _localComments.indexWhere((c) => c.id == id);
      final prev = idx != -1 ? _localComments[idx] : null;

      setState(() {
        if (idx != -1 && prev != null) {
          _localComments[idx] = _Comment(
            id: prev.id,
            user: prev.user,
            text: text,
            timeAgo: prev.timeAgo,
            isMe: prev.isMe,
            userId: prev.userId,
            userKey: prev.userKey,
            avatarUrl: prev.avatarUrl,
          );
        }
        _editingId = null;
      });
      _ctrl.clear();
      _focusNode.unfocus();

      try {
        await ref.read(feedRepositoryProvider).updateComment(id, text);
      } catch (e) {
        // 실패 시 원래 댓글로 롤백
        if (mounted && idx != -1 && prev != null) {
          setState(() => _localComments[idx] = prev);
        }
        if (await handleIfBanned(e)) return;
        if (mounted) AppSnackBar.error(context, '댓글 수정 실패: $e');
      }
      return;
    }

    final user = ref.read(currentUserProvider);
    final username = user?.userMetadata?['username'] as String? ?? '나';

    // 답글이면 @멘션을 붙인 본문을 화면·DB에 동일하게 사용한다.
    // (이전엔 화면엔 @멘션을 표시하면서 DB엔 원문만 저장 → 재진입 시 일반 댓글로 보였음)
    final content = _replyTo != null ? '@$_replyTo $text' : text;

    final comment = _Comment(
      user: username,
      text: content,
      timeAgo: '방금',
      isMe: true,
    );
    setState(() {
      _localComments.add(comment);
      _replyTo = null;
    });
    widget.onCommentAdded(comment);
    _ctrl.clear();

    if (user != null) {
      try {
        await ref.read(feedRepositoryProvider).addComment(
          widget.post.id,
          user.id,
          content,
        );
        ref.invalidate(feedPostsProvider);
        await _loadComments();
      } catch (e) {
        if (await handleIfBanned(e)) return;
        // 로컬 UI는 유지, 서버 저장 실패 무시
      }
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final accent = widget.accent;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final subColor = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);
    final divColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // 핸들
              const SizedBox(height: 10),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 제목
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  '댓글',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              Divider(height: 1, color: divColor),

              // 댓글 목록
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2))
                    : _localComments.isEmpty
                        ? Center(
                            child: Text(
                              '첫 번째 댓글을 달아보세요',
                              style: TextStyle(color: subColor, fontSize: 14),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _localComments.length,
                            itemBuilder: (_, i) => _CommentTile(
                              comment: _localComments[i],
                              isDark: isDark,
                              accent: accent,
                              subColor: subColor,
                              onReply: (user) {
                                if (_editingId != null) _cancelEdit();
                                setState(() => _replyTo = user);
                              },
                              onLongPress: () => _showCommentActions(_localComments[i]),
                            ),
                          ),
              ),

              // 답글 대상 표시
              if (_replyTo != null)
                Container(
                  color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '@$_replyTo 에게 답글 작성 중',
                        style: TextStyle(fontSize: 12, color: subColor),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _replyTo = null),
                        child: Icon(LucideIcons.x, size: 16, color: subColor),
                      ),
                    ],
                  ),
                ),

              // 수정 중 표시
              if (_editingId != null)
                Container(
                  color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(LucideIcons.pencil, size: 14, color: subColor),
                      const SizedBox(width: 6),
                      Text(
                        '댓글 수정 중',
                        style: TextStyle(fontSize: 12, color: subColor),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _cancelEdit,
                        child: Icon(LucideIcons.x, size: 16, color: subColor),
                      ),
                    ],
                  ),
                ),

              Divider(height: 1, color: divColor),

              // 댓글 입력창
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 10,
                    bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
                        ),
                        child: Center(
                          child: Text(
                            '나',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focusNode,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: _editingId != null ? '댓글 수정...' : '댓글 달기...',
                            hintStyle: TextStyle(color: subColor, fontSize: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(color: divColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(color: divColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(color: accent),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _submit(),
                          textInputAction: TextInputAction.send,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder(
                        valueListenable: _ctrl,
                        builder: (_, val, __) => GestureDetector(
                          onTap: val.text.trim().isNotEmpty ? _submit : null,
                          child: Text(
                            _editingId != null ? '수정' : '게시',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: val.text.trim().isNotEmpty
                                  ? accent
                                  : subColor,
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
        );
      },
    );
  }
}

class _CommentTile extends StatefulWidget {
  const _CommentTile({
    required this.comment,
    required this.isDark,
    required this.accent,
    required this.subColor,
    required this.onReply,
    required this.onLongPress,
  });
  final _Comment comment;
  final bool isDark;
  final Color accent;
  final Color subColor;
  final ValueChanged<String> onReply;
  final VoidCallback onLongPress;

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final isDark = widget.isDark;

    void goToProfile() {
      if (c.userId.isNotEmpty) {
        context.push('${AppRoutes.userProfile}/${c.userId}');
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: widget.onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아바타
          GestureDetector(
            onTap: goToProfile,
            child: UserAvatar(
              username: c.user,
              avatarUrl: c.avatarUrl.isNotEmpty ? c.avatarUrl : null,
              radius: 16,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: goToProfile,
                          child: Text(
                            c.user,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: c.text,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(c.timeAgo, style: TextStyle(fontSize: 11, color: widget.subColor)),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: () => widget.onReply(c.userKey.isNotEmpty ? c.userKey : c.user),
                      child: Text(
                        '답글 달기',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.subColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ── 데이터 모델 ─────────────────────────────────────────
class _Comment {
  const _Comment({
    this.id = '',
    required this.user,
    required this.text,
    required this.timeAgo,
    this.isMe = false,
    this.userId = '',
    this.userKey = '',
    this.avatarUrl = '',
  });
  final String id;
  final String user, text, timeAgo;
  final bool isMe;
  final String userId;
  final String userKey;
  final String avatarUrl;
}
