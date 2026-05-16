import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/post_model.dart';
import '../../../../core/utils/youtube_url_parser.dart';
import 'feed_video_player.dart';
import 'fullscreen_image_viewer.dart';
import 'fullscreen_video_viewer.dart';
import 'youtube_feed_player.dart';

/// 게시물의 미디어를 PageView로 보여주는 공용 위젯.
/// - 사진/동영상 혼합 (post.effectiveMedia 기반)
/// - 단일 항목: 단순 뷰
/// - 다중: PageView + 상단 카운터 + 하단 dot 인디케이터
/// - 사진 탭 → 풀스크린 이미지 뷰어
/// - 동영상 풀스크린 버튼 → 풀스크린 동영상 뷰어
/// [overlay]: 하트 애니메이션 등 미디어 위에 올릴 위젯
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

  // 영상 게시물에 aspect_ratio가 비어있을 때 썸네일에서 추출한 비율
  double? _detectedVideoAspect;
  ImageStream? _aspectStream;
  ImageStreamListener? _aspectListener;

  List<MediaItem> get _media => widget.post.effectiveMedia;
  bool get _isMulti => _media.length > 1;

  void _openImageViewer(int index) {
    final imgs = _media.where((m) => m.type == 'image').toList();
    if (imgs.isEmpty) return;
    final urls = imgs.map((m) => m.url).toList();
    // 현재 페이지가 이미지면 그 위치, 아니면 0
    final cur = _media[index];
    int viewerIdx = 0;
    if (cur.type == 'image') {
      viewerIdx = imgs.indexOf(cur);
      if (viewerIdx < 0) viewerIdx = 0;
    }
    FullscreenImageViewer.open(
      context,
      urls: urls,
      initialIndex: viewerIdx,
    );
  }

  void _openVideoViewer(MediaItem item) {
    FullscreenVideoViewer.open(
      context,
      videoUrl: item.url,
      thumbnailUrl: item.thumbnailUrl ?? widget.post.imageUrl,
      accent: widget.accent,
    );
  }

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
    _maybeDetectVideoAspect();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    if (_aspectStream != null && _aspectListener != null) {
      _aspectStream!.removeListener(_aspectListener!);
    }
    super.dispose();
  }

  /// 영상이 첫 미디어인데 비율이 없는 경우, 썸네일 이미지에서 비율을 추출.
  void _maybeDetectVideoAspect() {
    final p = widget.post;
    if (p.aspectRatio != null) return;
    final first = _media.isNotEmpty ? _media.first : null;
    if (first == null || first.type != 'video') return;
    final thumb = first.thumbnailUrl ?? p.imageUrl;
    if (thumb.isEmpty) return;

    final provider = CachedNetworkImageProvider(thumb);
    _aspectStream = provider.resolve(ImageConfiguration.empty);
    _aspectListener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final aspect = info.image.width / info.image.height;
      if (aspect.isFinite && aspect > 0) {
        setState(() => _detectedVideoAspect = aspect);
      }
    });
    _aspectStream!.addListener(_aspectListener!);
  }

  double _computeAspect(BuildContext context) {
    final p = widget.post;
    if (p.youtubeUrl != null) {
      if (isYoutubeShortsUrl(p.youtubeUrl!)) {
        final media = MediaQuery.of(context);
        final cappedHeight = media.size.height * 0.75;
        final minAspect =
            cappedHeight > 0 ? media.size.width / cappedHeight : 9 / 16;
        return (9 / 16).clamp(minAspect, 1.91);
      }
      return 16 / 9;
    }
    final hasVideo = _media.any((m) => m.type == 'video');
    final natural = widget.post.aspectRatio ??
        (hasVideo ? _detectedVideoAspect : null) ??
        (4 / 3);
    if (hasVideo) {
      final media = MediaQuery.of(context);
      final cappedHeight = media.size.height * 0.75;
      final minAspect =
          cappedHeight > 0 ? media.size.width / cappedHeight : 0.5625;
      return natural.clamp(minAspect, 1.91);
    }
    return natural.clamp(0.8, 1.91);
  }

  Widget _buildPage(MediaItem item, int index) {
    if (item.type == 'video') {
      return FeedVideoPlayer(
        post: widget.post,
        accent: widget.accent,
        videoUrlOverride: item.url,
        thumbnailUrlOverride: item.thumbnailUrl ?? widget.post.imageUrl,
        keyIdOverride: '${widget.post.id}_$index',
        onTapFullscreen: () => _openVideoViewer(item),
      );
    }
    return _NetImage(
      url: item.url,
      isDark: widget.isDark,
      accent: widget.accent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final media = _media;
    final currentIsVideo = media.isNotEmpty &&
        _page < media.length &&
        media[_page].type == 'video';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 미디어 영역 ──────────────────────────
        GestureDetector(
          onTap: (p.youtubeUrl != null || currentIsVideo)
              ? null
              : () => _openImageViewer(_page),
          onDoubleTap: (p.youtubeUrl != null || currentIsVideo)
              ? null
              : widget.onDoubleTap,
          child: Container(
            width: double.infinity,
            color: widget.isDark
                ? const Color(0xFF0A0A0A)
                : const Color(0xFFF2F2F2),
            child: AspectRatio(
              aspectRatio: _computeAspect(context),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 미디어
                  if (p.youtubeUrl != null)
                    YoutubeFeedPlayer(
                      youtubeUrl: p.youtubeUrl!,
                      thumbnailUrl: p.imageUrl,
                    )
                  else if (media.isEmpty)
                    Center(
                      child: Icon(LucideIcons.image,
                          size: 60,
                          color: widget.isDark
                              ? const Color(0xFF3F3F46)
                              : const Color(0xFFA1A1AA)),
                    )
                  else if (!_isMulti)
                    _buildPage(media.first, 0)
                  else
                    PageView.builder(
                      controller: _ctrl,
                      itemCount: media.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) => _buildPage(media[i], i),
                    ),

                  // 리그 배지
                  if (p.leagueId != null)
                    Positioned(
                      top: 12, left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(LucideIcons.trophy,
                              size: 10, color: AppColors.gold),
                          const SizedBox(width: 5),
                          Text('리그 게시물',
                              style: TextStyle(
                                  color: widget.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),

                  // 다중 페이지 카운터 (우상단)
                  if (_isMulti)
                    Positioned(
                      top: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_page + 1} / ${media.length}',
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
              children: List.generate(media.length, (i) {
                final active = i == _page;
                final isVideoDot = media[i].type == 'video';
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: active ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: active
                        ? widget.accent
                        : (isVideoDot
                            ? widget.accent.withValues(alpha: 0.5)
                            : (widget.isDark
                                ? const Color(0xFF555555)
                                : const Color(0xFFCCCCCC))),
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
  const _NetImage(
      {required this.url, required this.isDark, required this.accent});
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
        child: Icon(LucideIcons.image,
            size: 60,
            color: isDark
                ? const Color(0xFF3F3F46)
                : const Color(0xFFA1A1AA)),
      ),
    );
  }
}
