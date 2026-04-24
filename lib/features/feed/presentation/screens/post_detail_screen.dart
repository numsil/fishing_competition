import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../league/data/league_repository.dart';
import '../../../profile/data/profile_repository.dart';
import '../../data/feed_repository.dart';
import '../../data/post_model.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.post});
  final Post post;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _liked = false;
  bool _showHeart = false;
  late AnimationController _heartCtrl;
  late Animation<double> _heartAnim;
  final List<_Comment> _comments = [];

  @override
  void initState() {
    super.initState();
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
      if (s == AnimationStatus.completed) setState(() => _showHeart = false);
    });
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  void _doubleTapLike() {
    setState(() => _showHeart = true);
    _heartCtrl.forward(from: 0);
    if (!_liked) _toggleLike();
  }

  Future<void> _toggleLike() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final wasLiked = _liked;
    setState(() => _liked = !wasLiked);
    try {
      await ref.read(feedRepositoryProvider).toggleLike(widget.post.id, user.id);
      ref.invalidate(feedPostsProvider);
    } catch (_) {
      if (mounted) setState(() => _liked = wasLiked);
    }
  }

  String _stripHashtags(String caption) {
    return caption.split(RegExp(r'\s+')).where((w) => !w.startsWith('#')).join(' ').trim();
  }

  List<String> _extractHashtags(String? caption) {
    if (caption == null || caption.isEmpty) return [];
    return caption.split(RegExp(r'\s+')).where((w) => w.startsWith('#') && w.length > 1).toList();
  }

  Future<void> _sharePostToFeed() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(feedRepositoryProvider).sharePostToFeed(widget.post);
      ref.invalidate(feedPostsProvider);
      ref.invalidate(myPostsProvider);
      ref.invalidate(myProfileProvider);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('내 피드에 공유되었습니다.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('공유 실패: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('게시물 삭제', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('이 게시물을 삭제하시겠습니까?\n삭제된 게시물은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(feedRepositoryProvider).deletePost(widget.post.id);
      ref.invalidate(feedPostsProvider);
      ref.invalidate(myPostsProvider);
      if (widget.post.leagueId != null) {
        ref.invalidate(leagueUserPostsProvider((widget.post.leagueId!, widget.post.userId)));
        ref.invalidate(leagueRankingProvider(widget.post.leagueId!));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 실패: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _openComments() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentSheet(
        post: widget.post,
        isDark: isDark,
        accent: accent,
        comments: _comments,
        onCommentAdded: (c) => setState(() => _comments.add(c)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    final p = widget.post;
    final iconColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);
    final bgColor = isDark ? AppColors.darkBg : Colors.white;
    final likeCount = _liked ? p.likesCount + 1 : p.likesCount;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('게시물', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: iconColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.moreHorizontal, color: iconColor),
            onPressed: () {
              final currentUserId = ref.read(currentUserProvider)?.id;
              showModalBottomSheet(
                context: context,
                backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) => _MoreMenu(
                  isDark: isDark,
                  postId: p.id,
                  post: p,
                  isOwner: currentUserId != null && currentUserId == p.userId,
                  onDelete: () {
                    Navigator.pop(context); // 바텀시트 닫기
                    _deletePost();
                  },
                  onShareToFeed: () {
                    Navigator.pop(context);
                    _sharePostToFeed();
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Container(
              color: bgColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.push('${AppRoutes.userProfile}/${p.userId}'),
                  child: UserAvatar(
                    username: p.username,
                    avatarUrl: p.avatarUrl.isNotEmpty ? p.avatarUrl : null,
                    radius: 18,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push('${AppRoutes.userProfile}/${p.userId}'),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(p.username,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        if (p.isLunker) ...[
                          const SizedBox(width: 4),
                          Icon(LucideIcons.checkCircle, size: 13, color: accent),
                        ],
                      ]),
                      if (p.location != null)
                        Text(p.location!, style: TextStyle(fontSize: 11, color: subColor)),
                    ]),
                  ),
                ),
              ]),
            ),

            // 이미지
            GestureDetector(
              onDoubleTap: _doubleTapLike,
              child: Container(
                width: double.infinity,
                color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F2F2),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(fit: StackFit.expand, children: [
                    Image.network(
                      p.imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            color: accent,
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(LucideIcons.image, size: 60,
                            color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFA1A1AA)),
                      ),
                    ),
                    if (p.leagueId != null)
                      Positioned(
                        top: 12, left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(LucideIcons.trophy, size: 10, color: AppColors.gold),
                            const SizedBox(width: 5),
                            Text('리그 게시물',
                                style: TextStyle(color: accent, fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    if (_showHeart)
                      Center(
                        child: AnimatedBuilder(
                          animation: _heartAnim,
                          builder: (_, __) => Transform.scale(
                            scale: _heartAnim.value,
                            child: const Icon(Icons.favorite_rounded,
                                color: Colors.white, size: 80),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ),

            // 액션 버튼
            Container(
              color: bgColor,
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
              child: Row(children: [
                IconButton(
                  onPressed: _toggleLike,
                  icon: Icon(LucideIcons.heart,
                      color: _liked ? AppColors.error : iconColor, size: 24),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _openComments,
                  icon: Icon(LucideIcons.messageCircle, color: iconColor, size: 24),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () {
                    final link = 'https://huk.app/p/${p.id}';
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
                  icon: Icon(LucideIcons.link2, color: iconColor, size: 24),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ]),
            ),

            // 좋아요 수
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text('좋아요 $likeCount개',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),

            // 조과 정보 (길이, 어종)
            if (p.length != null || p.fishType.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    Icon(LucideIcons.fish, size: 16, color: accent),
                    const SizedBox(width: 8),
                    Text(p.fishType,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: accent)),
                    if (p.length != null) ...[
                      const SizedBox(width: 10),
                      Text('${p.length}cm',
                          style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.w600)),
                    ],
                    if (p.isLunker) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('런커',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black)),
                      ),
                    ],
                  ]),
                ),
              ),

            // 캡션
            if (p.caption != null && p.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: p.username,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const TextSpan(text: '  '),
                    TextSpan(text: _stripHashtags(p.caption!),
                        style: const TextStyle(fontSize: 13)),
                  ]),
                ),
              ),

            // 해시태그
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                ['#${p.fishType}', ..._extractHashtags(p.caption), '#낚시', '#조과'].join('  '),
                style: TextStyle(fontSize: 13,
                    color: isDark ? const Color(0xFF4A9ECC) : const Color(0xFF00376B)),
              ),
            ),

            // 댓글 보기
            GestureDetector(
              onTap: _openComments,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _comments.isEmpty
                      ? '댓글 달기...'
                      : '댓글 ${_comments.length}개 모두 보기',
                  style: TextStyle(fontSize: 13, color: subColor),
                ),
              ),
            ),

            // 최신 댓글 미리보기
            if (_comments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: _comments.last.user,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const TextSpan(text: '  '),
                    TextSpan(text: _comments.last.text, style: const TextStyle(fontSize: 13)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // 시간
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              child: Text(
                _timeAgo(p.createdAt),
                style: TextStyle(fontSize: 11, color: subColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}일 전';
    if (diff.inHours > 0) return '${diff.inHours}시간 전';
    if (diff.inMinutes > 0) return '${diff.inMinutes}분 전';
    return '방금';
  }
}

// ── 더보기 메뉴 ──────────────────────────────────────────
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.isDark,
    required this.postId,
    required this.post,
    required this.isOwner,
    required this.onDelete,
    required this.onShareToFeed,
  });
  final bool isDark;
  final String postId;
  final Post post;
  final bool isOwner;
  final VoidCallback onDelete;
  final VoidCallback onShareToFeed;

  bool get _canShareToFeed =>
      isOwner && (post.leagueId != null || post.isPersonalRecord);

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;
    final divColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;

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
          if (_canShareToFeed) ...[
            _MenuItem(
              icon: LucideIcons.send,
              label: '내 피드에 공유하기',
              color: accent,
              onTap: onShareToFeed,
            ),
            Divider(height: 1, color: divColor),
          ],
          _MenuItem(
            icon: LucideIcons.link2, label: '링크 복사', color: textColor,
            onTap: () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: 'https://huk.app/p/$postId'));
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
          _MenuItem(icon: LucideIcons.share, label: '공유하기', color: textColor,
              onTap: () => Navigator.pop(context)),
          if (isOwner) ...[
            Divider(height: 1, color: divColor),
            _MenuItem(
              icon: LucideIcons.trash2,
              label: '게시물 삭제',
              color: AppColors.error,
              onTap: onDelete,
            ),
          ] else ...[
            Divider(height: 1, color: divColor),
            _MenuItem(icon: LucideIcons.flag, label: '신고하기', color: AppColors.error,
                onTap: () => Navigator.pop(context)),
          ],
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
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ── 댓글 시트 ────────────────────────────────────────────
class _CommentSheet extends ConsumerStatefulWidget {
  const _CommentSheet({
    required this.post, required this.isDark, required this.accent,
    required this.comments, required this.onCommentAdded,
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
  late List<_Comment> _localComments;

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

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(currentUserProvider);
    final username = user?.userMetadata?['username'] as String? ?? '나';
    final comment = _Comment(user: username, text: text, timeAgo: '방금');
    setState(() => _localComments.add(comment));
    widget.onCommentAdded(comment);
    _ctrl.clear();
    if (user != null) {
      try {
        await ref.read(feedRepositoryProvider).addComment(widget.post.id, user.id, text);
        ref.invalidate(feedPostsProvider);
      } catch (_) {}
    }
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
          child: Column(children: [
            const SizedBox(height: 10),
            Container(width: 36, height: 4,
                decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
                    borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('댓글', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            Divider(height: 1, color: divColor),
            Expanded(
              child: _localComments.isEmpty
                  ? Center(child: Text('첫 번째 댓글을 달아보세요',
                      style: TextStyle(color: subColor, fontSize: 14)))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _localComments.length,
                      itemBuilder: (_, i) {
                        final c = _localComments[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 32, height: 32,
                                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
                                child: Center(child: Text(c.user[0],
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : Colors.black))),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text.rich(TextSpan(children: [
                              TextSpan(text: c.user,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              const TextSpan(text: '  '),
                              TextSpan(text: c.text, style: const TextStyle(fontSize: 13)),
                            ]))),
                          ]),
                        );
                      },
                    ),
            ),
            Divider(height: 1, color: divColor),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12, right: 12, top: 10,
                  bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 12,
                ),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '댓글 달기...',
                        hintStyle: TextStyle(color: subColor, fontSize: 14),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: divColor)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: divColor)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: accent)),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                      child: Text('게시',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                              color: val.text.trim().isNotEmpty ? accent : subColor)),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _Comment {
  const _Comment({required this.user, required this.text, required this.timeAgo});
  final String user, text, timeAgo;
}
