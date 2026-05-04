import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../feed/data/post_model.dart';
import '../../data/league_repository.dart';

class CatchReviewDetailScreen extends ConsumerStatefulWidget {
  const CatchReviewDetailScreen({
    super.key,
    required this.post,
    required this.leagueId,
  });

  final Post post;
  final String leagueId;

  @override
  ConsumerState<CatchReviewDetailScreen> createState() =>
      _CatchReviewDetailScreenState();
}

class _CatchReviewDetailScreenState
    extends ConsumerState<CatchReviewDetailScreen> {
  late Post _post;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  bool get _isHeld => _post.reviewStatus == 'held';

  Future<void> _toggleHold() async {
    setState(() => _loading = true);
    try {
      if (_isHeld) {
        await ref.read(leagueRepositoryProvider).unholdPost(_post.id);
        setState(() => _post = _post.copyWith(reviewStatus: 'approved'));
      } else {
        await ref.read(leagueRepositoryProvider).holdPost(_post.id);
        setState(() => _post = _post.copyWith(reviewStatus: 'held'));
      }
      ref.invalidate(leagueCatchesForReviewProvider(widget.leagueId));
      ref.invalidate(leagueRankingProvider(widget.leagueId));
    } catch (e) {
      if (mounted) AppSnackBar.error(context, '처리 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accent = context.accentColor;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          _post.username,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          if (_isHeld)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
              ),
              child: const Text(
                '보류 중',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── 사진 ──────────────────────────────────────
          Expanded(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: _post.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    size: 64,
                    color: Colors.white38,
                  ),
                ),
              ),
            ),
          ),

          // ── 하단 정보 + 버튼 ──────────────────────────
          Container(
            color: isDark ? AppColors.darkSurface : Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 조과 정보
                Row(
                  children: [
                    Icon(LucideIcons.fish, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      _post.fishType,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('yyyy.MM.dd HH:mm').format(_post.createdAt.toLocal()),
                      style: TextStyle(fontSize: 12, color: sub),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_post.length != null) ...[
                      Icon(LucideIcons.ruler, size: 13, color: sub),
                      const SizedBox(width: 4),
                      Text(
                        '${_post.length!.toStringAsFixed(1)}cm',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (_post.weight != null) ...[
                      Icon(LucideIcons.scale, size: 13, color: sub),
                      const SizedBox(width: 4),
                      Text(
                        '${_post.weight!.toStringAsFixed(0)}g',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ],
                ),
                if (_post.caption != null && _post.caption!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _post.caption!,
                    style: TextStyle(fontSize: 13, color: sub),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 16),
                // 보류 / 해지 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _toggleHold,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isHeld
                                ? AppColors.darkSurface2
                                : AppColors.error,
                            foregroundColor: _isHeld ? sub : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _isHeld ? '보류 해지' : '보류 처리',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
