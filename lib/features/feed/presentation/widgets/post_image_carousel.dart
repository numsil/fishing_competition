import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/post_model.dart';
import 'feed_video_player.dart';

/// image_urls (다중) 또는 image_url (단일)을 PageView로 보여주는 공용 위젯.
/// - 단일 이미지 or 동영상: 기존과 동일한 단순 뷰
/// - 다중 이미지: PageView + 상단 "N/총" 카운터 + 하단 dot 인디케이터
/// [overlay]: 하트 애니메이션 등 이미지 위에 올릴 위젯
class PostImageCarousel extends StatefulWidget {
  const PostImageCarousel({
    super.key,
    required this.post,
    required this.isDark,
    required this.accent,
    this.onDoubleTap,
    this.overlay,
  });

  final Post post;
  final bool isDark;
  final Color accent;
  final VoidCallback? onDoubleTap;
  final Widget? overlay;

  @override
  State<PostImageCarousel> createState() => _PostImageCarouselState();
}

class _PostImageCarouselState extends State<PostImageCarousel> {
  late final PageController _ctrl;
  int _page = 0;

  List<String> get _urls {
    final p = widget.post;
    if (p.imageUrls != null && p.imageUrls!.isNotEmpty) return p.imageUrls!;
    if (p.imageUrl.isNotEmpty) return [p.imageUrl];
    return [];
  }

  bool get _isMulti => _urls.length > 1;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final urls = _urls;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 이미지 / 동영상 영역 ──────────────────────────
        GestureDetector(
          onDoubleTap: p.videoUrl != null ? null : widget.onDoubleTap,
          child: Container(
            width: double.infinity,
            color: widget.isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F2F2),
            child: AspectRatio(
              aspectRatio: (widget.post.aspectRatio ?? (4 / 3)).clamp(0.8, 1.91),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 미디어
                  if (p.videoUrl != null)
                    FeedVideoPlayer(post: p, accent: widget.accent)
                  else if (_isMulti)
                    PageView.builder(
                      controller: _ctrl,
                      itemCount: urls.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) => _NetImage(
                        url: urls[i],
                        isDark: widget.isDark,
                        accent: widget.accent,
                      ),
                    )
                  else if (urls.isNotEmpty)
                    _NetImage(
                      url: urls.first,
                      isDark: widget.isDark,
                      accent: widget.accent,
                    )
                  else
                    Center(
                      child: Icon(LucideIcons.image, size: 60,
                          color: widget.isDark ? const Color(0xFF3F3F46) : const Color(0xFFA1A1AA)),
                    ),

                  // 리그 배지
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
                          const Icon(LucideIcons.trophy, size: 10, color: AppColors.gold),
                          const SizedBox(width: 5),
                          Text('리그 게시물',
                              style: TextStyle(
                                  color: widget.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),

                  // 다중 이미지 페이지 카운터 (우상단)
                  if (_isMulti)
                    Positioned(
                      top: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_page + 1} / ${urls.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                  // 커스텀 오버레이 (하트 애니메이션 등)
                  if (widget.overlay != null)
                    Positioned.fill(
                      child: IgnorePointer(child: widget.overlay!),
                    ),
                ],
              ),
            ),
          ),
        ),

        // ── dot 인디케이터 ────────────────────────────────
        if (_isMulti)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(urls.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: active ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: active
                        ? widget.accent
                        : (widget.isDark
                            ? const Color(0xFF555555)
                            : const Color(0xFFCCCCCC)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _NetImage extends StatelessWidget {
  const _NetImage({required this.url, required this.isDark, required this.accent});
  final String url;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: accent),
      ),
      errorWidget: (_, __, ___) => Center(
        child: Icon(LucideIcons.image, size: 60,
            color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFA1A1AA)),
      ),
    );
  }
}
