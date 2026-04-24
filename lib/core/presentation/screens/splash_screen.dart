import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../router/app_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _introCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _fade;
  late Animation<double> _scale;
  late Animation<double> _textFade;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();

    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fade = CurvedAnimation(parent: _introCtrl, curve: Curves.easeIn);
    _scale = Tween(begin: 0.80, end: 1.0).animate(
      CurvedAnimation(parent: _introCtrl, curve: Curves.easeOutBack),
    );
    _textFade = CurvedAnimation(
      parent: CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
      curve: Curves.linear,
    );
    _glow = Tween(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _introCtrl.forward();

    Future.delayed(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      final user = Supabase.instance.client.auth.currentUser;
      context.go(user != null ? AppRoutes.feed : AppRoutes.login);
    });
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060A0A),
      body: Stack(
        children: [
          // ── 물결 배경 ──────────────────────────────────
          const Positioned.fill(child: _WaterBackground()),

          // ── 로고 + 텍스트 ──────────────────────────────
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: AnimatedBuilder(
                  animation: _glow,
                  builder: (_, __) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HukSvgLogo(glowIntensity: _glow.value),
                      const SizedBox(height: 22),
                      FadeTransition(
                        opacity: _textFade,
                        child: Text(
                          '우리 동네 낚시 리그 & 조과 SNS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 13,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 0.8,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  물결 배경 CustomPainter
// ─────────────────────────────────────────────────────────────────

class _WaterBackground extends StatelessWidget {
  const _WaterBackground();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _WaterPainter());
}

class _WaterPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 방사형 그라디언트 - 중앙이 약간 밝게
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.85,
      colors: const [Color(0xFF0D1818), Color(0xFF060A0A)],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // 미세한 파형 선
    final wavePaint = Paint()
      ..color = const Color(0xFF0C1E1E).withValues(alpha: 0.9)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    final rand = Random(42);
    for (double y = -30; y < size.height + 30; y += 16) {
      final path = Path();
      final offset = rand.nextDouble() * pi * 2;
      path.moveTo(0, y);
      for (double x = 0; x <= size.width; x += 2) {
        final wave = sin(x * 0.018 + offset) * 5 +
            sin(x * 0.04 + offset * 1.3) * 2.5;
        path.lineTo(x, y + wave);
      }
      canvas.drawPath(path, wavePaint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────
//  HUK SVG 로고 (형광 그린 + 글로우)
// ─────────────────────────────────────────────────────────────────

class _HukSvgLogo extends StatelessWidget {
  const _HukSvgLogo({required this.glowIntensity});
  final double glowIntensity;

  static const _neon = Color(0xFF00FF88);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 외부 글로우 — 크고 투명하게 (맥동)
        Opacity(
          opacity: 0.18 * glowIntensity,
          child: SvgPicture.asset(
            'assets/images/huk_logo.svg',
            width: 272,
            colorFilter: const ColorFilter.mode(_neon, BlendMode.srcIn),
          ),
        ),
        // 내부 글로우 — 중간 크기
        Opacity(
          opacity: 0.40 * glowIntensity,
          child: SvgPicture.asset(
            'assets/images/huk_logo.svg',
            width: 252,
            colorFilter: const ColorFilter.mode(_neon, BlendMode.srcIn),
          ),
        ),
        // 선명한 로고
        SvgPicture.asset(
          'assets/images/huk_logo.svg',
          width: 240,
          colorFilter: const ColorFilter.mode(_neon, BlendMode.srcIn),
        ),
      ],
    );
  }
}
