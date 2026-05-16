import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../data/post_model.dart';
import '../providers/video_mute_provider.dart';

class FeedVideoPlayer extends ConsumerStatefulWidget {
  const FeedVideoPlayer({
    super.key,
    required this.post,
    required this.accent,
    this.videoUrlOverride,
    this.thumbnailUrlOverride,
    this.keyIdOverride,
    this.onTapFullscreen,
  });
  final Post post;
  final Color accent;
  // 혼합 미디어 캐러셀에서 특정 미디어 항목을 재생할 때 사용 (없으면 post.videoUrl 사용)
  final String? videoUrlOverride;
  final String? thumbnailUrlOverride;
  final String? keyIdOverride;
  // 풀스크린 진입 콜백. 지정 시 우상단에 풀스크린 버튼 표시.
  final VoidCallback? onTapFullscreen;

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

  String get _videoUrl =>
      widget.videoUrlOverride ?? widget.post.videoUrl ?? '';
  String get _thumbUrl =>
      widget.thumbnailUrlOverride ?? widget.post.imageUrl;
  String get _keyId =>
      widget.keyIdOverride ?? widget.post.id;

  // 더블탭 스킵 시 화면 좌/우에 잠깐 뜨는 오버레이
  int? _skipIndicator; // -10 / +10
  Timer? _skipIndicatorTimer;

  @override
  void dispose() {
    _skipIndicatorTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _seekRelative(int seconds) {
    final c = _controller;
    if (c == null || !_initialized) return;
    final pos = c.value.position;
    final dur = c.value.duration;
    var target = pos + Duration(seconds: seconds);
    if (target.isNegative) target = Duration.zero;
    if (target > dur) target = dur;
    c.seekTo(target);
    setState(() {
      _hasEnded = false;
      _skipIndicator = seconds;
    });
    _skipIndicatorTimer?.cancel();
    _skipIndicatorTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _skipIndicator = null);
    });
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
        final file = await DefaultCacheManager().getSingleFile(_videoUrl);
        final ctrl = VideoPlayerController.file(file);
        await ctrl.initialize();
        ctrl.setLooping(false);
        ctrl.setVolume(isMuted ? 0.0 : 1.0);
        await ctrl.play();
        ctrl.addListener(_onControllerUpdate);
        if (!mounted) {
          ctrl.removeListener(_onControllerUpdate);
          ctrl.dispose();
          return;
        }
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
    final isPlaying = _controller?.value.isPlaying ?? false;
    final isMuted = ref.watch(videoMutedProvider);

    ref.listen<bool>(videoMutedProvider, (_, muted) {
      _controller?.setVolume(muted ? 0.0 : 1.0);
    });

    return VisibilityDetector(
      key: Key('video_$_keyId'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 썸네일 or 동영상
          if (_initialized && _controller != null)
            ClipRect(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
          else if (_thumbUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: _thumbUrl,
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) => Container(color: const Color(0xFF1A1A1A)),
            )
          else
            Container(color: const Color(0xFF1A1A1A)),

          // 좌/우 탭 영역
          //  - 단일 탭: 재생/일시정지
          //  - 더블탭: -10초 / +10초 (YouTube 스타일)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _hasEnded ? null : _togglePlay,
                  onDoubleTap: () => _seekRelative(-5),
                  child: const SizedBox.expand(),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _hasEnded ? null : _togglePlay,
                  onDoubleTap: () => _seekRelative(5),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),

          // 더블탭 스킵 인디케이터 (잠깐 뜨고 사라짐)
          if (_skipIndicator != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: _skipIndicator! < 0
                            ? _SkipIndicator(seconds: -_skipIndicator!, forward: false)
                            : const SizedBox.shrink(),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _skipIndicator! > 0
                            ? _SkipIndicator(seconds: _skipIndicator!, forward: true)
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 재생 버튼
          if (!isPlaying && !_hasEnded)
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

          // 재생 완료 버튼
          if (_hasEnded)
            Center(
              child: GestureDetector(
                onTap: _replay,
                child: Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.replay_rounded, color: Colors.white, size: 38),
                ),
              ),
            ),

          // 로딩 스피너
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
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

          // 풀스크린 버튼
          if (widget.onTapFullscreen != null)
            Positioned(
              top: 10, right: 10,
              child: GestureDetector(
                onTap: widget.onTapFullscreen,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
                ),
              ),
            ),

          // 시크바 옆 보조 컨트롤 (좌: ±10초, 우: 음소거)
          if (_initialized)
            Positioned(
              bottom: 36, left: 10, right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _CtrlIconButton(
                        icon: Icons.replay_5,
                        onTap: () => _seekRelative(-5),
                      ),
                      const SizedBox(width: 6),
                      _CtrlIconButton(
                        icon: Icons.forward_5,
                        onTap: () => _seekRelative(5),
                      ),
                    ],
                  ),
                  _CtrlIconButton(
                    icon: isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    onTap: _toggleMute,
                  ),
                ],
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

class _CtrlIconButton extends StatelessWidget {
  const _CtrlIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _SkipIndicator extends StatelessWidget {
  const _SkipIndicator({required this.seconds, required this.forward});
  final int seconds;
  final bool forward;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            forward ? Icons.forward_5 : Icons.replay_5,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 6),
          Text(
            '$seconds초',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
