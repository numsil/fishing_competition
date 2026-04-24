import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../data/post_model.dart';

class FeedVideoPlayer extends StatefulWidget {
  const FeedVideoPlayer({super.key, required this.post, required this.accent});
  final Post post;
  final Color accent;

  @override
  State<FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<FeedVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_controller == null) {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.post.videoUrl!));
      await ctrl.initialize();
      ctrl.setLooping(true);
      ctrl.setVolume(0.0);
      await ctrl.play();
      ctrl.addListener(() { if (mounted) setState(() {}); });
      setState(() { _controller = ctrl; _initialized = true; });
      return;
    }
    if (_controller!.value.isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
    setState(() {});
  }

  void _toggleMute() {
    if (_controller == null) return;
    final isMuted = _controller!.value.volume == 0;
    _controller!.setVolume(isMuted ? 1.0 : 0.0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final isPlaying = _controller?.value.isPlaying ?? false;
    final isMuted = (_controller?.value.volume ?? 0) == 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 썸네일 or 동영상
        if (_initialized && _controller != null)
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          )
        else if (p.imageUrl.isNotEmpty)
          Image.network(
            p.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A1A)),
          )
        else
          Container(color: const Color(0xFF1A1A1A)),

        // 전체 탭 영역 (재생/일시정지)
        GestureDetector(
          onTap: _togglePlay,
          child: Container(color: Colors.transparent),
        ),

        // 재생 버튼
        if (!isPlaying)
          Center(
            child: GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
              ),
            ),
          ),

        // 동영상 아이콘 (썸네일 상태일 때 우상단)
        if (!_initialized)
          const Positioned(
            top: 10, right: 10,
            child: Icon(Icons.videocam, color: Colors.white, size: 20, shadows: [
              Shadow(color: Colors.black54, blurRadius: 4),
            ]),
          ),

        // 음소거 토글 (재생 중일 때 우하단)
        if (_initialized)
          Positioned(
            bottom: 10, right: 10,
            child: GestureDetector(
              onTap: _toggleMute,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
