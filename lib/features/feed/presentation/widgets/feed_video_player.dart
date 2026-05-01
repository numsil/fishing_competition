import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../data/post_model.dart';
import '../providers/video_mute_provider.dart';

class FeedVideoPlayer extends ConsumerStatefulWidget {
  const FeedVideoPlayer({super.key, required this.post, required this.accent});
  final Post post;
  final Color accent;

  @override
  ConsumerState<FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends ConsumerState<FeedVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _wasPlayingBeforeHide = false;
  bool _isSeeking = false;
  bool _hasEnded = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted || _controller == null || !_initialized) return;
    if (info.visibleFraction < 0.5) {
      if (_controller!.value.isPlaying) {
        _wasPlayingBeforeHide = true;
        _controller!.pause();
        if (mounted) setState(() {});
      }
    } else {
      if (_wasPlayingBeforeHide && !_hasEnded && !_controller!.value.isPlaying) {
        _wasPlayingBeforeHide = false;
        _controller!.setVolume(ref.read(videoMutedProvider) ? 0.0 : 1.0);
        _controller!.play();
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _togglePlay() async {
    if (_isLoading) return;

    if (_controller == null) {
      setState(() => _isLoading = true);
      try {
        final isMuted = ref.read(videoMutedProvider);
        final file = await DefaultCacheManager().getSingleFile(widget.post.videoUrl!);
        final ctrl = VideoPlayerController.file(file);
        await ctrl.initialize();
        ctrl.setLooping(false);
        ctrl.setVolume(isMuted ? 0.0 : 1.0);
        await ctrl.play();
        ctrl.addListener(_onControllerUpdate);
        setState(() {
          _controller = ctrl;
          _initialized = true;
          _isLoading = false;
        });
      } catch (_) {
        setState(() => _isLoading = false);
      }
      return;
    }

    if (_controller!.value.isPlaying) {
      _wasPlayingBeforeHide = false;
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
    setState(() {});
  }

  Future<void> _replay() async {
    if (_controller == null) return;
    setState(() => _hasEnded = false);
    await _controller!.seekTo(Duration.zero);
    await _controller!.play();
  }

  void _onControllerUpdate() {
    if (!mounted || _controller == null) return;
    final value = _controller!.value;
    if (!_hasEnded &&
        !value.isPlaying &&
        value.duration > Duration.zero &&
        value.position >= value.duration) {
      setState(() => _hasEnded = true);
    } else {
      setState(() {});
    }
  }

  void _toggleMute() {
    if (_controller == null) return;
    final isMuted = ref.read(videoMutedProvider);
    ref.read(videoMutedProvider.notifier).setMuted(!isMuted);
    _controller!.setVolume(isMuted ? 1.0 : 0.0);
    setState(() {});
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildSeekBar() {
    final pos = _controller!.value.position.inMilliseconds.toDouble();
    final dur = _controller!.value.duration.inMilliseconds.toDouble();
    final maxVal = dur > 0 ? dur : 1.0;

    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 2.5,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: _isSeeking ? 7.0 : 0.0),
        activeTrackColor: widget.accent,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
        thumbColor: widget.accent,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        trackShape: const RoundedRectSliderTrackShape(),
        overlayColor: widget.accent.withValues(alpha: 0.2),
      ),
      child: Slider(
        value: (pos / maxVal).clamp(0.0, 1.0),
        onChangeStart: (_) {
          _wasPlayingBeforeHide = _controller!.value.isPlaying;
          _controller!.pause();
          setState(() => _isSeeking = true);
        },
        onChanged: (v) {
          _controller!.seekTo(Duration(milliseconds: (v * maxVal).toInt()));
          setState(() {});
        },
        onChangeEnd: (_) {
          if (_wasPlayingBeforeHide) _controller!.play();
          setState(() => _isSeeking = false);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final isPlaying = _controller?.value.isPlaying ?? false;
    final isMuted = ref.watch(videoMutedProvider);

    return VisibilityDetector(
      key: Key('video_${p.id}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Stack(
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

          // 음소거 토글 (초기화 후 우하단, 시크바 위)
          if (_initialized)
            Positioned(
              bottom: 38, right: 10,
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

          // 시크바 + 시간 표시
          if (_initialized && _controller != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSeeking)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_controller!.value.position),
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                            Text(
                              _formatDuration(_controller!.value.duration),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    _buildSeekBar(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
