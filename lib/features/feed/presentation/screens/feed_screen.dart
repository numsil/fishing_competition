import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_svg.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;

    return Scaffold(
      appBar: _FeedAppBar(isDark: isDark, accent: accent),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _FavoritesBar(isDark: isDark, accent: accent)),
          SliverToBoxAdapter(
            child: Divider(
              height: 0.5,
              thickness: 0.5,
              color: isDark ? const Color(0xFF262626) : const Color(0xFFDBDBDB),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _InstaPost(
                post: _posts[i % _posts.length],
                isDark: isDark,
                accent: accent,
              ),
              childCount: 8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── AppBar ───────────────────────────────────────────────
class _FeedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _FeedAppBar({required this.isDark, required this.accent});
  final bool isDark;
  final Color accent;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 44,
      backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        'FishingGram',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white : Colors.black,
          letterSpacing: -0.8,
          fontFamily: 'serif',
        ),
      ),
      actions: [
        // 피드 올리기
        GestureDetector(
          onTap: () => context.push(AppRoutes.upload),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded,
                    color: isDark ? Colors.black : Colors.white, size: 18),
                const SizedBox(width: 4),
                Text(
                  '올리기',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.favorite_border_rounded,
              color: isDark ? Colors.white : Colors.black, size: 26),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.send_outlined,
              color: isDark ? Colors.white : Colors.black, size: 24),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ── 즐겨찾기 스토리 바 ──────────────────────────────────
class _FavoritesBar extends StatelessWidget {
  const _FavoritesBar({required this.isDark, required this.accent});
  final bool isDark;
  final Color accent;

  static const _favorites = [
    _Favorite(name: '충주호 리그', type: _FavType.leagueLive, initials: 'L'),
    _Favorite(name: '김민준', type: _FavType.user, initials: '김'),
    _Favorite(name: '소양강 리그', type: _FavType.league, initials: 'L'),
    _Favorite(name: '이서연', type: _FavType.user, initials: '이'),
    _Favorite(name: '박태준', type: _FavType.user, initials: '박'),
    _Favorite(name: '가평 대회', type: _FavType.league, initials: 'L'),
    _Favorite(name: '최현수', type: _FavType.user, initials: '최'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 0, 8),
          child: Row(
            children: [
              Icon(Icons.star_rounded, size: 14,
                  color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF888888)),
              const SizedBox(width: 4),
              Text(
                '즐겨찾기',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF888888),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: _favorites.length,
            itemBuilder: (_, i) => _StoryItem(
              fav: _favorites[i],
              isDark: isDark,
              accent: accent,
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

enum _FavType { leagueLive, league, user }

class _Favorite {
  const _Favorite({required this.name, required this.type, required this.initials});
  final String name, initials;
  final _FavType type;
}

class _StoryItem extends StatelessWidget {
  const _StoryItem({required this.fav, required this.isDark, required this.accent});
  final _Favorite fav;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isLive = fav.type == _FavType.leagueLive;
    final isLeague = fav.type == _FavType.league || isLive;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isLive
                      ? const LinearGradient(
                          colors: [AppColors.liveRed, Color(0xFFFF6B6B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : isLeague
                          ? LinearGradient(
                              colors: [accent, accent.withValues(alpha: 0.5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                ),
              ),
              Container(
                width: 59,
                height: 59,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.darkBg : Colors.white,
                ),
              ),
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
                ),
                child: isLeague
                    ? Padding(
                        padding: const EdgeInsets.all(13),
                        child: AppSvg(
                          AppIcons.trophy,
                          color: isLive ? AppColors.liveRed : accent,
                        ),
                      )
                    : Center(
                        child: Text(
                          fav.initials,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
              ),
              if (isLive)
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.liveRed,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isDark ? AppColors.darkBg : Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              if (isLeague && !isLive)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBg : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(Icons.emoji_events_rounded, size: 12, color: accent),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 64,
            child: Text(
              fav.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white : const Color(0xFF111111),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 인스타그램 스타일 포스트 ──────────────────────────────
class _InstaPost extends StatefulWidget {
  const _InstaPost({required this.post, required this.isDark, required this.accent});
  final _Post post;
  final bool isDark;
  final Color accent;

  @override
  State<_InstaPost> createState() => _InstaPostState();
}

class _InstaPostState extends State<_InstaPost>
    with SingleTickerProviderStateMixin {
  bool _liked = false;
  bool _showHeart = false;
  late AnimationController _heartCtrl;
  late Animation<double> _heartAnim;

  // 댓글 목록 (로컬 상태)
  late List<_Comment> _comments;

  @override
  void initState() {
    super.initState();
    _comments = List.from(widget.post.commentList);
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heartAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.4), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOut));
    _heartCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() => _showHeart = false);
      }
    });
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  void _doubleTapLike() {
    setState(() {
      _liked = true;
      _showHeart = true;
    });
    _heartCtrl.forward(from: 0);
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
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _MoreMenu(
        isDark: isDark,
        postId: widget.post.id,
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
    final avatarBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEFEFEF);
    final likeCount = _liked ? p.likes + 1 : p.likes;
    final commentCount = _comments.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 헤더 ──
        Container(
          color: bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(shape: BoxShape.circle, color: avatarBg),
                child: Center(
                  child: Text(
                    p.user[0],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          p.user,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        if (p.isLunker) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.verified_rounded, size: 13, color: accent),
                        ],
                      ],
                    ),
                    if (p.location != null)
                      Text(p.location!, style: TextStyle(fontSize: 11, color: subColor)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _openMoreMenu,
                icon: Icon(Icons.more_horiz, color: iconColor, size: 20),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),

        // ── 이미지 ──
        GestureDetector(
          onDoubleTap: _doubleTapLike,
          child: Container(
            width: double.infinity,
            color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F2F2),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 물고기 SVG
                  Center(
                    child: AppSvg(
                      AppIcons.fish,
                      width: MediaQuery.of(context).size.width * 0.55,
                      color: isDark ? const Color(0xFF1A3026) : const Color(0xFFC8E6D4),
                    ),
                  ),
                  // 리그 태그
                  if (p.league != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppSvg(AppIcons.trophy, size: 10, color: AppColors.gold),
                            const SizedBox(width: 5),
                            Text(
                              p.league!,
                              style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // 더블탭 하트 애니메이션
                  if (_showHeart)
                    Center(
                      child: AnimatedBuilder(
                        animation: _heartAnim,
                        builder: (_, __) => Transform.scale(
                          scale: _heartAnim.value,
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 80,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // ── 액션 버튼 ──
        Container(
          color: bgColor,
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
          child: Row(
            children: [
              // 좋아요
              IconButton(
                onPressed: () => setState(() => _liked = !_liked),
                icon: Icon(
                  _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _liked ? AppColors.error : iconColor,
                  size: 26,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 4),
              // 댓글
              IconButton(
                onPressed: _openComments,
                icon: Icon(Icons.chat_bubble_outline_rounded, color: iconColor, size: 24),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 4),
              // 링크 복사
              IconButton(
                onPressed: () {
                  final link = 'https://fishinggram.app/p/${p.id}';
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('링크가 복사되었습니다'),
                      backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.black87,
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                icon: Icon(Icons.link_rounded, color: iconColor, size: 24),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),

        // ── 좋아요 수 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            '좋아요 $likeCount개',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),

        // ── 캡션 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: p.user,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const TextSpan(text: '  '),
                TextSpan(
                  text: p.caption,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // ── 해시태그 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 3, 16, 0),
          child: Text(
            '#${p.fish}  #${p.lure}  #낚시  #조과',
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
            p.timeAgo,
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
  const _MoreMenu({required this.isDark, required this.postId});
  final bool isDark;
  final String postId;

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
          _MenuItem(
            icon: Icons.link_rounded,
            label: '링크 복사',
            color: textColor,
            onTap: () {
              Navigator.pop(context);
              final link = 'https://fishinggram.app/p/$postId';
              Clipboard.setData(ClipboardData(text: link));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('링크가 복사되었습니다'),
                  backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.black87,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
          ),
          Divider(height: 1, color: divColor),
          _MenuItem(
            icon: Icons.share_outlined,
            label: '공유하기',
            color: textColor,
            onTap: () => Navigator.pop(context),
          ),
          Divider(height: 1, color: divColor),
          _MenuItem(
            icon: Icons.person_add_outlined,
            label: '팔로우',
            color: textColor,
            onTap: () => Navigator.pop(context),
          ),
          Divider(height: 1, color: divColor),
          _MenuItem(
            icon: Icons.flag_outlined,
            label: '신고하기',
            color: AppColors.error,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── 댓글 시트 ─────────────────────────────────────────
class _CommentSheet extends StatefulWidget {
  const _CommentSheet({
    required this.post,
    required this.isDark,
    required this.accent,
    required this.comments,
    required this.onCommentAdded,
  });
  final _Post post;
  final bool isDark;
  final Color accent;
  final List<_Comment> comments;
  final ValueChanged<_Comment> onCommentAdded;

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late List<_Comment> _localComments;
  String? _replyTo;

  @override
  void initState() {
    super.initState();
    _localComments = List.from(widget.comments);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final comment = _Comment(
      user: '나',
      text: _replyTo != null ? '@$_replyTo $text' : text,
      timeAgo: '방금',
      isMe: true,
    );
    setState(() {
      _localComments.add(comment);
      _replyTo = null;
    });
    widget.onCommentAdded(comment);
    _ctrl.clear();
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
                child: _localComments.isEmpty
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
                            setState(() => _replyTo = user);
                          },
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
                        child: Icon(Icons.close, size: 16, color: subColor),
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
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: '댓글 달기...',
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
                            '게시',
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
  });
  final _Comment comment;
  final bool isDark;
  final Color accent;
  final Color subColor;
  final ValueChanged<String> onReply;

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final isDark = widget.isDark;
    final avatarBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아바타
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, color: avatarBg),
            child: Center(
              child: Text(
                c.user[0],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: c.user,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
                      onTap: () => widget.onReply(c.user),
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
          const SizedBox(width: 8),
          // 댓글 좋아요
          GestureDetector(
            onTap: () => setState(() => _liked = !_liked),
            child: Icon(
              _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 16,
              color: _liked ? AppColors.error : widget.subColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 데이터 모델 ─────────────────────────────────────────
class _Comment {
  const _Comment({
    required this.user,
    required this.text,
    required this.timeAgo,
    this.isMe = false,
  });
  final String user, text, timeAgo;
  final bool isMe;
}

class _Post {
  const _Post({
    required this.id,
    required this.user,
    this.location,
    required this.caption,
    required this.fish,
    required this.size,
    required this.lure,
    required this.likes,
    required this.timeAgo,
    this.league,
    this.isLunker = false,
    this.commentList = const [],
  });

  final String id, user, caption, fish, size, lure, timeAgo;
  final String? location, league;
  final int likes;
  final bool isLunker;
  final List<_Comment> commentList;
}

const _posts = [
  _Post(
    id: 'post_001',
    user: '김민준',
    location: '충주호 북쪽 포인트',
    caption: '드디어 런커 달성!! 52cm 배스. 빅베이트 스로잉으로 낚았습니다. 충주호 최고의 포인트 발견',
    fish: '배스',
    size: '52.3cm',
    lure: '빅베이트',
    likes: 1284,
    timeAgo: '3시간 전',
    league: '충주호 리그',
    isLunker: true,
    commentList: [
      _Comment(user: '이서연', text: '대박이다!! 런커 축하해요 🎣', timeAgo: '2시간 전'),
      _Comment(user: '박태준', text: '충주호 포인트 여쭤봐도 될까요?', timeAgo: '1시간 전'),
      _Comment(user: '강준혁', text: '빅베이트 사이즈가 어떻게 되세요?', timeAgo: '45분 전'),
      _Comment(user: '정민호', text: '와 진짜 런커네요 부럽다', timeAgo: '30분 전'),
    ],
  ),
  _Post(
    id: 'post_002',
    user: '이서연',
    location: '소양강 댐 하류',
    caption: '오늘 쏘가리 4마리 조과! 날씨도 좋고 물도 맑고. 스피너베이트가 제격이었네요',
    fish: '쏘가리',
    size: '38.5cm',
    lure: '스피너베이트',
    likes: 876,
    timeAgo: '5시간 전',
    commentList: [
      _Comment(user: '김민준', text: '4마리나요? 대단해요!', timeAgo: '4시간 전'),
      _Comment(user: '최현수', text: '소양강 요즘 잘 나오나요?', timeAgo: '3시간 전'),
    ],
  ),
  _Post(
    id: 'post_003',
    user: '박태준',
    location: '팔당호',
    caption: '주말 가족 낚시. 아이들이 너무 좋아해서 매주 오게 될 것 같네요 😊',
    fish: '붕어',
    size: '30.0cm',
    lure: '지렁이',
    likes: 2031,
    timeAgo: '8시간 전',
    commentList: [
      _Comment(user: '이서연', text: '가족 낚시 너무 좋아요~', timeAgo: '7시간 전'),
      _Comment(user: '강준혁', text: '아이들 반응이 어떤가요 ㅋㅋ', timeAgo: '6시간 전'),
      _Comment(user: '정민호', text: '팔당 붕어 포인트 알 수 있을까요?', timeAgo: '5시간 전'),
    ],
  ),
  _Post(
    id: 'post_004',
    user: '최현수',
    location: '가평 계곡',
    caption: '계곡 배스 공략 성공. 탑워터 플러그에 폭발적인 반응. 가평은 역시 배스 성지',
    fish: '배스',
    size: '44.8cm',
    lure: '탑워터',
    likes: 543,
    timeAgo: '어제',
    commentList: [
      _Comment(user: '김민준', text: '가평 탑워터 시즌이군요!', timeAgo: '어제'),
    ],
  ),
];
