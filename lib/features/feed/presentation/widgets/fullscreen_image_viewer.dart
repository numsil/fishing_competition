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
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 200),
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

  // 아래로 스와이프 닫기용
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

  void _onVerticalDragStart(DragStartDetails d) {
    if (_zoomed) return;
    _dragging = true;
    _dragDy = 0;
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    setState(() => _dragDy += d.delta.dy);
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    final shouldClose =
        _dragDy.abs() > 120 || d.primaryVelocity != null && d.primaryVelocity!.abs() > 700;
    if (shouldClose) {
      Navigator.of(context).pop();
    } else {
      setState(() => _dragDy = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dy = _dragDy;
    final progress = (dy.abs() / 300).clamp(0.0, 1.0);
    final bgOpacity = (1.0 - progress).clamp(0.0, 1.0);
    final scale = (1.0 - progress * 0.15).clamp(0.85, 1.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 배경 (드래그에 따라 투명도 변화)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: bgOpacity),
              ),
            ),
          ),

          // 이미지 영역
          Positioned.fill(
            child: GestureDetector(
              onVerticalDragStart: _onVerticalDragStart,
              onVerticalDragUpdate: _onVerticalDragUpdate,
              onVerticalDragEnd: _onVerticalDragEnd,
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
                    ),
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
  });

  final String url;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  final TransformationController _ctrl = TransformationController();
  late final AnimationController _animCtrl;
  Animation<Matrix4>? _anim;
  TapDownDetails? _doubleTapDetails;

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
      // ignore: deprecated_member_use
      final target = Matrix4.identity()
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
