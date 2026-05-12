import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// 광고 영상 플레이어.
/// - 화면 50%+ 보일 때 자동재생, 보이지 않으면 일시정지
/// - 무음 시작, 루프 재생
/// - 컨트롤 UI 없음 (탭은 부모 GestureDetector가 처리해 외부 링크로)
class AdVideoPlayer extends StatefulWidget {
  const AdVideoPlayer({
    super.key,
    required this.adId,
    required this.slotKey,
    required this.videoUrl,
    this.thumbnailUrl,
  });

  final String adId;
  final String slotKey; // 같은 광고가 여러 슬롯에 노출돼도 키 충돌 안 나게
  final String videoUrl;
  final String? thumbnailUrl;

  @override
  State<AdVideoPlayer> createState() => _AdVideoPlayerState();
}

class _AdVideoPlayerState extends State<AdVideoPlayer> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _visible = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await c.initialize();
      if (_disposed) {
        await c.dispose();
        return;
      }
      await c.setLooping(true);
      await c.setVolume(0);
      _ctrl = c;
      if (mounted) setState(() => _initialized = true);
      if (_visible) _ctrl!.play();
    } catch (_) {
      await c.dispose();
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final isVisible = info.visibleFraction >= 0.5;
    if (isVisible == _visible) return;
    _visible = isVisible;
    final c = _ctrl;
    if (c == null || !_initialized) return;
    if (isVisible) {
      c.play();
    } else {
      c.pause();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('ad_video_${widget.slotKey}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: _initialized && _ctrl != null
          ? FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _ctrl!.value.size.width,
                height: _ctrl!.value.size.height,
                child: VideoPlayer(_ctrl!),
              ),
            )
          : (widget.thumbnailUrl?.isNotEmpty == true
              ? CachedNetworkImage(
                  imageUrl: widget.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Container(color: const Color(0xFF1A1A1A)),
                )
              : Container(color: const Color(0xFF1A1A1A))),
    );
  }
}
