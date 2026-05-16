import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../providers/video_mute_provider.dart';

/// 동영상 풀스크린 뷰어.
/// - 가로/세로 회전 지원 (디바이스 회전에 맞춰 동영상이 채워짐)
/// - 컨트롤 오버레이: 재생/일시정지, 시크바, ±5초, 음소거, 닫기
/// - 아래로 스와이프 또는 닫기 버튼으로 종료
class FullscreenVideoViewer extends ConsumerStatefulWidget {
  const FullscreenVideoViewer({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.accent,
    this.startAt,
  });

  final String videoUrl;
  final String? thumbnailUrl;
  final Color accent;
  final Duration? startAt;

  static Future<Duration?> open(
    BuildContext context, {
    required String videoUrl,
    String? thumbnailUrl,
    required Color accent,
    Duration? startAt,
  }) {
    return Navigator.of(context, rootNavigator: true).push<Duration>(
      PageRouteBuilder<Duration>(
        opaque: true,
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => FullscreenVideoViewer(
          videoUrl: videoUrl,
          thumbnailUrl: thumbnailUrl,
          accent: accent,
          startAt: startAt,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  ConsumerState<FullscreenVideoViewer> createState() =>
      _FullscreenVideoViewerState();
}

class _FullscreenVideoViewerState extends ConsumerState<FullscreenVideoViewer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _showControls = true;
  bool _isSeeking = false;
  bool _hasEnded = false;
  Timer? _hideTimer;

  double _dragDy = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    // 풀스크린 동안 모든 회전 허용
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _init();
  }

  Future<void> _init() async {
    try {
      final file =
          await DefaultCacheManager().getSingleFile(widget.videoUrl);
      final ctrl = VideoPlayerController.file(file);
      await ctrl.initialize();
      ctrl.setLooping(false);
      final isMuted = ref.read(videoMutedProvider);
      ctrl.setVolume(isMuted ? 0.0 : 1.0);
      if (widget.startAt != null) {
        await ctrl.seekTo(widget.startAt!);
      }
      await ctrl.play();
      ctrl.addListener(_onControllerUpdate);
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _controller = ctrl;
        _initialized = true;
      });
      _scheduleHideControls();
    } catch (_) {
      // 무시 — 썸네일로 폴백
    }
  }

  void _onControllerUpdate() {
    if (!mounted || _controller == null) return;
    final v = _controller!.value;
    if (!_hasEnded &&
        !v.isPlaying &&
        v.duration > Duration.zero &&
        v.position >= v.duration) {
      setState(() => _hasEnded = true);
    } else {
      setState(() {});
    }
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHideControls();
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c == null || !_initialized) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      if (_hasEnded) {
        await c.seekTo(Duration.zero);
        setState(() => _hasEnded = false);
      }
      await c.play();
    }
    setState(() {});
    _scheduleHideControls();
  }

  void _seekRelative(int seconds) {
    final c = _controller;
    if (c == null || !_initialized) return;
    var target = c.value.position + Duration(seconds: seconds);
    if (target.isNegative) target = Duration.zero;
    if (target > c.value.duration) target = c.value.duration;
    c.seekTo(target);
    setState(() {
      _hasEnded = false;
      _showControls = true;
    });
    _scheduleHideControls();
  }

  void _toggleMute() {
    final c = _controller;
    if (c == null) return;
    final isMuted = ref.read(videoMutedProvider);
    ref.read(videoMutedProvider.notifier).setMuted(!isMuted);
    c.setVolume(isMuted ? 1.0 : 0.0);
    setState(() {});
    _scheduleHideControls();
  }

  void _close() {
    final pos = _controller?.value.position;
    Navigator.of(context).pop(pos);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    // 화면 회전 원복
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final isPlaying = c?.value.isPlaying ?? false;
    final isMuted = ref.watch(videoMutedProvider);
    final dragOpacity = (1.0 - (_dragDy.abs() / 400)).clamp(0.0, 1.0);

    ref.listen<bool>(videoMutedProvider, (_, muted) {
      _controller?.setVolume(muted ? 0.0 : 1.0);
    });

    return GestureDetector(
      onVerticalDragStart: (_) => setState(() => _dragging = true),
      onVerticalDragUpdate: (d) => setState(() => _dragDy += d.delta.dy),
      onVerticalDragEnd: (_) {
        if (_dragDy.abs() > 120) {
          _close();
        } else {
          setState(() {
            _dragging = false;
            _dragDy = 0;
          });
        }
      },
      onTap: _toggleControls,
      onDoubleTap: _togglePlay,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: dragOpacity),
        body: Stack(
          children: [
            // 동영상 본체
            Center(
              child: Transform.translate(
                offset: _dragging ? Offset(0, _dragDy) : Offset.zero,
                child: _initialized && c != null
                    ? AspectRatio(
                        aspectRatio: c.value.aspectRatio,
                        child: VideoPlayer(c),
                      )
                    : (widget.thumbnailUrl != null
                        ? CachedNetworkImage(
                            imageUrl: widget.thumbnailUrl!,
                            fit: BoxFit.contain,
                          )
                        : const SizedBox.shrink()),
              ),
            ),

            // 로딩
            if (!_initialized)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),

            // 컨트롤 오버레이
            if (_showControls && _initialized && c != null) ...[
              // 상단: 닫기
              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _close,
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 28),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _toggleMute,
                          icon: Icon(
                            isMuted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 중앙: 재생/일시정지
              Center(
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _hasEnded
                          ? Icons.replay_rounded
                          : (isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded),
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
              ),

              // 하단: ±5초 + 시크바
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
                        Row(
                          children: [
                            _FsCtrlButton(
                              icon: Icons.replay_5,
                              onTap: () => _seekRelative(-5),
                            ),
                            const SizedBox(width: 6),
                            _FsCtrlButton(
                              icon: Icons.forward_5,
                              onTap: () => _seekRelative(5),
                            ),
                            const Spacer(),
                            Text(
                              '${_formatDuration(c.value.position)} / ${_formatDuration(c.value.duration)}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 2.5,
                            thumbShape: RoundSliderThumbShape(
                                enabledThumbRadius: _isSeeking ? 7.0 : 4.0),
                            activeTrackColor: widget.accent,
                            inactiveTrackColor:
                                Colors.white.withValues(alpha: 0.3),
                            thumbColor: widget.accent,
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 16),
                            overlayColor: widget.accent.withValues(alpha: 0.2),
                          ),
                          child: Slider(
                            value: (c.value.position.inMilliseconds /
                                    (c.value.duration.inMilliseconds == 0
                                        ? 1
                                        : c.value.duration.inMilliseconds))
                                .clamp(0.0, 1.0),
                            onChangeStart: (_) {
                              c.pause();
                              setState(() => _isSeeking = true);
                            },
                            onChanged: (v) {
                              c.seekTo(Duration(
                                  milliseconds: (v *
                                          c.value.duration.inMilliseconds)
                                      .toInt()));
                              setState(() {});
                            },
                            onChangeEnd: (_) {
                              c.play();
                              setState(() => _isSeeking = false);
                              _scheduleHideControls();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FsCtrlButton extends StatelessWidget {
  const _FsCtrlButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
