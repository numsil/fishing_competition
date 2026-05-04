import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../feed/data/post_model.dart';

class CatchReviewItem extends StatelessWidget {
  const CatchReviewItem({
    super.key,
    required this.post,
    required this.isDark,
    required this.onTap,
    required this.onHold,
    required this.onUnhold,
  });

  final Post post;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onHold;
  final VoidCallback onUnhold;

  bool get _isHeld => post.reviewStatus == 'held';

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final divColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Opacity(
      opacity: _isHeld ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHeld ? AppColors.error.withValues(alpha: 0.4) : divColor,
            ),
          ),
          child: Row(
            children: [
              // 썸네일
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: CachedNetworkImage(
                    imageUrl: post.imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
                      child: const Icon(Icons.image_not_supported_outlined,
                          color: Colors.grey, size: 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 조과 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.username,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _measureText(),
                          style: TextStyle(fontSize: 12, color: sub),
                        ),
                        if (post.reviewStatus == 'approved') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(LucideIcons.badgeCheck, size: 10, color: Colors.green[700]),
                              const SizedBox(width: 2),
                              Text('인증',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.green[700])),
                            ]),
                          ),
                        ],
                      ],
                    ),
                    if (_isHeld)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '보류 중',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 보류 / 해지 버튼
              GestureDetector(
                onTap: _isHeld ? onUnhold : onHold,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _isHeld
                        ? AppColors.error.withValues(alpha: 0.15)
                        : (isDark ? AppColors.darkSurface2 : const Color(0xFFF0F0F0)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isHeld ? AppColors.error : divColor,
                    ),
                  ),
                  child: Text(
                    _isHeld ? '해지' : '보류',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _isHeld ? AppColors.error : sub,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _measureText() {
    final parts = <String>[];
    if (post.length != null) parts.add('${post.length!.toStringAsFixed(0)}cm');
    if (post.weight != null) parts.add('${post.weight!.toStringAsFixed(0)}g');
    if (parts.isEmpty) parts.add(post.fishType);
    return parts.join(' · ');
  }
}
