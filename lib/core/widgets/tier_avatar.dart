import 'dart:math';
import 'package:flutter/material.dart';
import 'score_card.dart';
import 'user_avatar.dart';

// ── 그랜드마스터: 심홍 + 골드 (LoL Grandmaster 스타일) ────
const _gmColors = [
  Color(0xFF3D0000), Color(0xFFAA0000), Color(0xFFEE0000),
  Color(0xFFFF5500), Color(0xFFFFCC00), Color(0xFFFF5500),
  Color(0xFFEE0000), Color(0xFFAA0000), Color(0xFF3D0000),
];
const _gmGlow   = Color(0xFFDD0000);
const _gmGem    = Color(0xFFFFCC00);

// ── 레전드: 순금 + 백금 (LoL Challenger 스타일) ──────────
const _legendColors = [
  Color(0xFF3D2800), Color(0xFFAA7700), Color(0xFFFFCC00),
  Color(0xFFFFEE99), Color(0xFFFFFFFF), Color(0xFFFFEE99),
  Color(0xFFFFCC00), Color(0xFFAA7700), Color(0xFF3D2800),
];
const _legendGlow = Color(0xFFFFCC00);
const _legendGem  = Color(0xFFFFFFFF);

// ── 마스터: 보라 + 글로우 ─────────────────────────────────
const _masterGlow = Color(0xFF9C27B0);

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

  @override
  void initState() {
    super.initState();
    if (widget.score >= 10000) {
      _ctrl = AnimationController(
        vsync: this,
        duration: Duration(seconds: widget.score >= 20000 ? 2 : 3),
      )..repeat();
    }
  }

  @override
  void didUpdateWidget(TierAvatar old) {
    super.didUpdateWidget(old);
    if (widget.score >= 10000 && _ctrl == null) {
      _ctrl = AnimationController(
        vsync: this,
        duration: Duration(seconds: widget.score >= 20000 ? 2 : 3),
      )..repeat();
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

    // 레전드
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

    // 그랜드마스터
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

    // 마스터: 글로우 + 단색
    if (widget.score >= 5000) {
      return _GlowFrame(
        radius: widget.radius,
        bw: widget.borderWidth,
        color: tier.color,
        glow: _masterGlow,
        child: inner,
      );
    }

    // 루키~다이아몬드: 단색 테두리
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

// ── 화려한 프레임 (GM / Legend) ───────────────────────────
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
          rotation: t * 2 * pi,
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ── 글로우 프레임 (Master) ────────────────────────────────
class _GlowFrame extends StatelessWidget {
  const _GlowFrame({
    required this.radius,
    required this.bw,
    required this.color,
    required this.glow,
    required this.child,
  });

  final double radius, bw;
  final Color color, glow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GlowPainter(color: color, glow: glow, bw: bw),
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
    required this.rotation,
  });

  final List<Color> colors;
  final double bw, rotation;
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
    final rect = Offset.zero & size;
    final rr = _rrect(size);

    // 1. 외부 글로우
    canvas.drawRRect(rr, Paint()
      ..color = glow.withValues(alpha: 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, bw * 2.0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = bw);

    // 2. 내부 글로우 (얇게)
    canvas.drawRRect(rr, Paint()
      ..color = glow.withValues(alpha: 0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.inner, bw * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = bw);

    // 3. 그라데이션 테두리
    canvas.drawRRect(rr, Paint()
      ..shader = SweepGradient(
        colors: colors,
        startAngle: rotation,
        endAngle: rotation + 2 * pi,
      ).createShader(rect)
      ..strokeWidth = bw
      ..style = PaintingStyle.stroke);

    // 4. 보석 장식
    _drawGems(canvas, size);
  }

  void _drawGems(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // 스쿼클에서 보석 위치: 테두리 중심선 위
    final r = size.width / 2 - bw * 0.5;
    final gs = bw * 1.1; // 보석 크기

    for (int i = 0; i < gemCount; i++) {
      final angle = (2 * pi * i / gemCount) - pi / 2;
      // squircle 근사: 원형 + 약간 압축
      final mx = cx + cos(angle) * r * 0.91;
      final my = cy + sin(angle) * r * 0.91;

      // 그림자
      canvas.drawPath(_diamond(mx, my, gs + 0.5),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));

      // 외곽 (어두운 색)
      canvas.drawPath(_diamond(mx, my, gs + 0.3),
          Paint()..color = glow.withValues(alpha: 0.6));

      // 보석 본체
      canvas.drawPath(_diamond(mx, my, gs),
          Paint()..color = gem);

      // 하이라이트 (상단 작은 점)
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
      old.rotation != rotation;
}

// ── Glow Painter (Master) ─────────────────────────────────
class _GlowPainter extends CustomPainter {
  const _GlowPainter({
    required this.color,
    required this.glow,
    required this.bw,
  });

  final Color color, glow;
  final double bw;

  @override
  void paint(Canvas canvas, Size size) {
    final cr = (size.width / 2 - bw) * 0.32 + bw * 0.4;
    final rr = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(bw / 2),
      Radius.circular(cr),
    );

    canvas.drawRRect(rr, Paint()
      ..color = glow.withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, bw * 1.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = bw);

    canvas.drawRRect(rr, Paint()
      ..color = color
      ..strokeWidth = bw
      ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) => old.color != color;
}
