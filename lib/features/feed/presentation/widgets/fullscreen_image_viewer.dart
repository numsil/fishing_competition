import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// 피드 이미지를 풀스크린으로 띄우는 뷰어.
/// - 핀치 줌 / 더블탭 줌 / 드래그 이동
/// - 다중 이미지: 좌우 스와이프
/// - 아래로 스와이프 또는 X 버튼 → 닫기
class FullscreenImageViewer extends StatefulWidget {
  const FullscreenImageViewer({
    super.key,
    required this.urls,
    required this.initialIndex,
  });

  final List<String> urls;
  final int initialIndex;

  static Future<void> open(
    BuildContext context, {
    required List<String> urls,
    required int initialIndex,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => FullscreenImageViewer(
          urls: urls,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late final PageController _pageCtrl;
  late int _page;

  // 아래/위로 스와이프 닫기용 (확대 안 됐고 한 손가락일 때만)
  double _dragDy = 0;
  bool _dragging = false;

  // 줌 상태일 땐 페이지 스와이프 잠금
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onDismissDrag(double dy) {
    setState(() {
      _dragDy = dy;
      _dragging = true;
    });
  }

  void _onDismissEnd(double dy, double velocityY) {
    _dragging = false;
    final shouldClose = dy.abs() > 120 || velocityY.abs() > 700;
    if (shouldClose) {
      Navigator.of(context).pop();
    } else {
      setState(() => _dragDy = 0);
    }
  }

  void _onDismissCancel() {
    if (_dragDy == 0 && !_dragging) return;
    setState(() {
      _dragDy = 0;
      _dragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dy = _dragDy;
    final progress = (dy.abs() / 300).clamp(0.0, 1.0);
    final bgOpacity = (1.0 - progress).clamp(0.0, 1.0);
    final scale = (1.0 - progress * 0.15).clamp(0.85, 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 (드래그에 따라 투명도 변화)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: bgOpacity),
              ),
            ),
          ),

          // 이미지 영역 — 닫기 드래그는 각 이미지의 InteractiveViewer 콜백에서
          // 손가락 수/확대 상태로 분기 처리하므로, 경쟁하는 바깥 제스처는 두지 않는다.
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(0, dy),
              child: Transform.scale(
                scale: scale,
                child: PageView.builder(
                  controller: _pageCtrl,
                  physics: _zoomed
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  itemCount: widget.urls.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _ZoomableImage(
                    url: widget.urls[i],
                    onZoomChanged: (z) {
                      if (z != _zoomed) setState(() => _zoomed = z);
                    },
                    onDismissDrag: _onDismissDrag,
                    onDismissEnd: _onDismissEnd,
                    onDismissCancel: _onDismissCancel,
                  ),
                ),
              ),
            ),
          ),

          // 상단 오버레이 (닫기 + 카운터)
          AnimatedOpacity(
            opacity: _dragging || _zoomed ? 0 : 1,
            duration: const Duration(milliseconds: 150),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    _CircleIconBtn(
                      icon: LucideIcons.x,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (widget.urls.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${_page + 1} / ${widget.urls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconBtn extends StatelessWidget {
  const _CircleIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({
    required this.url,
    required this.onZoomChanged,
    required this.onDismissDrag,
    required this.onDismissEnd,
    required this.onDismissCancel,
  });

  final String url;
  final ValueChanged<bool> onZoomChanged;

  /// 닫기 드래그 진행(누적 dy 전달)
  final ValueChanged<double> onDismissDrag;

  /// 닫기 드래그 종료(누적 dy, 세로 속도)
  final void Function(double dy, double velocityY) onDismissEnd;

  /// 닫기 드래그 취소(핀치 시작 등)
  final VoidCallback onDismissCancel;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  final TransformationController _ctrl = TransformationController();
  late final AnimationController _animCtrl;
  Animation<Matrix4>? _anim;
  TapDownDetails? _doubleTapDetails;

  // 닫기 드래그 상태
  bool _dismissing = false;
  double _dismissDy = 0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (_anim != null) _ctrl.value = _anim!.value;
      });
    _ctrl.addListener(_handleZoomChange);
  }

  void _handleZoomChange() {
    final s = _ctrl.value.getMaxScaleOnAxis();
    widget.onZoomChanged(s > 1.05);
  }

  // ── 닫기 드래그: InteractiveViewer 콜백에서 손가락 수/확대상태로 분기 ──
  void _onInteractionStart(ScaleStartDetails d) {
    _animCtrl.stop();
    final scale = _ctrl.value.getMaxScaleOnAxis();
    // 한 손가락 + 확대 안 된 상태에서만 닫기 후보
    _dismissing = d.pointerCount == 1 && scale <= 1.01;
    _dismissDy = 0;
  }

  void _onInteractionUpdate(ScaleUpdateDetails d) {
    // 두 손가락(핀치)이 들어오면 닫기 취소 → 줌에 양보
    if (d.pointerCount >= 2) {
      if (_dismissing) {
        _dismissing = false;
        _dismissDy = 0;
        widget.onDismissCancel();
      }
      return;
    }
    if (!_dismissing) return; // 확대 상태면 InteractiveViewer가 패닝 담당
    _dismissDy += d.focalPointDelta.dy;
    widget.onDismissDrag(_dismissDy);
  }

  void _onInteractionEnd(ScaleEndDetails d) {
    if (!_dismissing) return;
    _dismissing = false;
    widget.onDismissEnd(_dismissDy, d.velocity.pixelsPerSecond.dy);
    _dismissDy = 0;
  }

  @override
  void dispose() {
    _ctrl.removeListener(_handleZoomChange);
    _ctrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _animateTo(Matrix4 target) {
    _anim = Matrix4Tween(begin: _ctrl.value, end: target)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward(from: 0);
  }

  void _onDoubleTap() {
    final isZoomed = _ctrl.value.getMaxScaleOnAxis() > 1.05;
    if (isZoomed) {
      _animateTo(Matrix4.identity());
    } else {
      final pos = _doubleTapDetails?.localPosition ?? Offset.zero;
      const scale = 2.5;
      final x = -pos.dx * (scale - 1);
      final y = -pos.dy * (scale - 1);
      final target = Matrix4.identity()
        // ignore: deprecated_member_use
        ..translate(x, y)
        // ignore: deprecated_member_use
        ..scale(scale);
      _animateTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _ctrl,
        minScale: 1.0,
        maxScale: 5.0,
        clipBehavior: Clip.none,
        onInteractionStart: _onInteractionStart,
        onInteractionUpdate: _onInteractionUpdate,
        onInteractionEnd: _onInteractionEnd,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.url,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              ),
            ),
            errorWidget: (_, __, ___) => const Center(
              child: Icon(LucideIcons.image,
                  size: 60, color: Color(0xFF3F3F46)),
            ),
          ),
        ),
      ),
    );
  }
}
