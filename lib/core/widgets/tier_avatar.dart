import 'dart:math';
import 'package:flutter/material.dart';
import 'score_card.dart';
import 'user_avatar.dart';

// ── 그랜드마스터: 심홍 + 골드 ────────────────────────────
const _gmColors = [
  Color(0xFF3D0000), Color(0xFFAA0000), Color(0xFFEE0000),
  Color(0xFFFF5500), Color(0xFFFFCC00), Color(0xFFFF5500),
  Color(0xFFEE0000), Color(0xFFAA0000), Color(0xFF3D0000),
];
const _gmGlow = Color(0xFFDD0000);
const _gmGem  = Color(0xFFFFCC00);

// ── 레전드: 순금 + 백금 ──────────────────────────────────
const _legendColors = [
  Color(0xFF3D2800), Color(0xFFAA7700), Color(0xFFFFCC00),
  Color(0xFFFFEE99), Color(0xFFFFFFFF), Color(0xFFFFEE99),
  Color(0xFFFFCC00), Color(0xFFAA7700), Color(0xFF3D2800),
];
const _legendGlow = Color(0xFFFFCC00);
const _legendGem  = Color(0xFFFFFFFF);

// ── 마스터: 보라 + 글로우 ─────────────────────────────────
const _masterColors = [
  Color(0xFF1A0028), Color(0xFF6A0080), Color(0xFF9C27B0),
  Color(0xFFCE93D8), Color(0xFF9C27B0), Color(0xFF6A0080),
  Color(0xFF1A0028),
];
const _masterGlow = Color(0xFF9C27B0);
const _masterGem  = Color(0xFFCE93D8);

class TierAvatar extends StatefulWidget {
  const TierAvatar({
    super.key,
    required this.username,
    required this.score,
    this.avatarUrl,
    required this.radius,
    required this.isDark,
    this.borderWidth = 3.0,
  });

  final String username;
  final int score;
  final String? avatarUrl;
  final double radius;
  final bool isDark;
  final double borderWidth;

  @override
  State<TierAvatar> createState() => _TierAvatarState();
}

class _TierAvatarState extends State<TierAvatar>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  Duration _duration() => Duration(
    seconds: widget.score >= 20000 ? 2 : widget.score >= 10000 ? 3 : 4,
  );

  @override
  void initState() {
    super.initState();
    if (widget.score >= 5000) {
      _ctrl = AnimationController(vsync: this, duration: _duration())
        ..repeat();
    }
  }

  @override
  void didUpdateWidget(TierAvatar old) {
    super.didUpdateWidget(old);
    if (widget.score >= 5000 && _ctrl == null) {
      _ctrl = AnimationController(vsync: this, duration: _duration())
        ..repeat();
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = scoreTier(widget.score);
    final inner = UserAvatar(
      username: widget.username,
      avatarUrl: widget.avatarUrl,
      radius: widget.radius - widget.borderWidth - 1,
      isDark: widget.isDark,
    );

    if (widget.score >= 20000) {
      return _FancyFrame(
        ctrl: _ctrl!,
        radius: widget.radius,
        bw: widget.borderWidth,
        colors: _legendColors,
        glow: _legendGlow,
        gem: _legendGem,
        gemCount: 8,
        child: inner,
      );
    }

    if (widget.score >= 10000) {
      return _FancyFrame(
        ctrl: _ctrl!,
        radius: widget.radius,
        bw: widget.borderWidth,
        colors: _gmColors,
        glow: _gmGlow,
        gem: _gmGem,
        gemCount: 4,
        child: inner,
      );
    }

    if (widget.score >= 5000) {
      return _FancyFrame(
        ctrl: _ctrl!,
        radius: widget.radius,
        bw: widget.borderWidth,
        colors: _masterColors,
        glow: _masterGlow,
        gem: _masterGem,
        gemCount: 2,
        child: inner,
      );
    }

    return UserAvatar(
      username: widget.username,
      avatarUrl: widget.avatarUrl,
      radius: widget.radius - widget.borderWidth,
      isDark: widget.isDark,
      borderColor: tier.color,
      borderWidth: widget.borderWidth,
    );
  }
}

// ── 화려한 프레임 (Master / GM / Legend) ─────────────────
class _FancyFrame extends AnimatedWidget {
  const _FancyFrame({
    required AnimationController ctrl,
    required this.radius,
    required this.bw,
    required this.colors,
    required this.glow,
    required this.gem,
    required this.gemCount,
    required this.child,
  }) : super(listenable: ctrl);

  final double radius, bw;
  final List<Color> colors;
  final Color glow, gem;
  final int gemCount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    final size = radius * 2;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FancyPainter(
          colors: colors,
          bw: bw,
          glow: glow,
          gem: gem,
          gemCount: gemCount,
          progress: t,
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ── Fancy Painter ─────────────────────────────────────────
class _FancyPainter extends CustomPainter {
  const _FancyPainter({
    required this.colors,
    required this.bw,
    required this.glow,
    required this.gem,
    required this.gemCount,
    required this.progress,
  });

  final List<Color> colors;
  final double bw, progress;
  final Color glow, gem;
  final int gemCount;

  RRect _rrect(Size size) {
    final cr = (size.width / 2 - bw) * 0.32 + bw * 0.4;
    return RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(bw / 2),
      Radius.circular(cr),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rr = _rrect(size);
    final rect = Offset.zero & size;

    // 1. 외부 글로우 (정적)
    canvas.drawRRect(rr, Paint()
      ..color = glow.withValues(alpha: 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, bw * 2.0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = bw);

    // 2. 내부 글로우 (정적)
    canvas.drawRRect(rr, Paint()
      ..color = glow.withValues(alpha: 0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.inner, bw * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = bw);

    // 3. 그라데이션 테두리 — 테두리 모양 고정, 색상만 순환 회전
    canvas.drawRRect(rr, Paint()
      ..shader = SweepGradient(
        colors: colors,
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        transform: GradientRotation(progress * 2 * pi),
      ).createShader(rect)
      ..strokeWidth = bw
      ..style = PaintingStyle.stroke);

    // 4. 보석 (정적)
    _drawGems(canvas, size);
  }

  void _drawGems(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - bw * 0.5;
    final gs = bw * 1.1;

    for (int i = 0; i < gemCount; i++) {
      final angle = (2 * pi * i / gemCount) - pi / 2;
      final mx = cx + cos(angle) * r * 0.91;
      final my = cy + sin(angle) * r * 0.91;

      canvas.drawPath(_diamond(mx, my, gs + 0.5),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));

      canvas.drawPath(_diamond(mx, my, gs + 0.3),
          Paint()..color = glow.withValues(alpha: 0.6));

      canvas.drawPath(_diamond(mx, my, gs),
          Paint()..color = gem);

      canvas.drawCircle(
        Offset(mx - gs * 0.15, my - gs * 0.3),
        gs * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }
  }

  Path _diamond(double x, double y, double s) => Path()
    ..moveTo(x, y - s)
    ..lineTo(x + s * 0.65, y)
    ..lineTo(x, y + s)
    ..lineTo(x - s * 0.65, y)
    ..close();

  @override
  bool shouldRepaint(covariant _FancyPainter old) =>
      old.progress != progress;
}
