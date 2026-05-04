import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';

const _gmTextColors   = [Color(0xFFEE0000), Color(0xFFFF8800), Color(0xFFFFCC00)];
const _legendTextColors = [Color(0xFFAA7700), Color(0xFFFFCC00), Color(0xFFFFFFFF), Color(0xFFFFCC00), Color(0xFFAA7700)];

({String name, Color color, int next, int prev}) scoreTier(int score) {
  if (score < 300)   return (name: '루키',        color: const Color(0xFF9E9E9E), next: 300,   prev: 0);
  if (score < 800)   return (name: '앵글러',      color: const Color(0xFF4CAF50), next: 800,   prev: 300);
  if (score < 2000)  return (name: '프로',        color: const Color(0xFF2196F3), next: 2000,  prev: 800);
  if (score < 5000)  return (name: '다이아몬드', color: const Color(0xFF00BCD4), next: 5000,  prev: 2000);
  if (score < 10000) return (name: '마스터',      color: const Color(0xFF9C27B0), next: 10000, prev: 5000);
  if (score < 20000) return (name: '그랜드마스터', color: const Color(0xFFE91E63), next: 20000, prev: 10000);
  return                    (name: '레전드',      color: AppColors.gold,          next: 20000, prev: 20000);
}

class ScoreCard extends StatelessWidget {
  const ScoreCard({
    super.key,
    required this.label,
    required this.icon,
    required this.score,
    required this.isDark,
    required this.accent,
  });

  final String label;
  final IconData icon;
  final int score;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tier = scoreTier(score);
    final isLegend = score >= 5000;
    final progressInTier = isLegend
        ? 1.0
        : (score - tier.prev) / (tier.next - tier.prev);

    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: 14,
      borderColor: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
      child: Column(children: [
        Row(children: [
          Icon(icon, size: 14, color: tier.color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          _TierBadge(name: tier.name, color: tier.color, score: score),
          const SizedBox(width: 8),
          _TierScore(score: score, color: tier.color),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progressInTier.clamp(0.0, 1.0),
            backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
            valueColor: AlwaysStoppedAnimation(tier.color),
            minHeight: 6,
          ),
        ),
        if (!isLegend) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '다음 티어까지 ${tier.next - score}pt',
              style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub),
            ),
          ),
        ],
      ]),
    );
  }
}

List<Color>? _gradientForScore(int score) {
  if (score >= 20000) return _legendTextColors;
  if (score >= 10000) return _gmTextColors;
  return null;
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.name, required this.color, required this.score});
  final String name;
  final Color color;
  final int score;

  @override
  Widget build(BuildContext context) {
    final colors = _gradientForScore(score);
    Widget text = Text(name,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: colors == null ? color : Colors.white));
    if (colors != null) {
      text = ShaderMask(
        shaderCallback: (b) =>
            LinearGradient(colors: colors).createShader(b),
        blendMode: BlendMode.srcIn,
        child: text,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: text,
    );
  }
}

class _TierScore extends StatelessWidget {
  const _TierScore({required this.score, required this.color});
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = _gradientForScore(score);
    Widget text = Text('${score}pt',
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: colors == null ? color : Colors.white));
    if (colors != null) {
      text = ShaderMask(
        shaderCallback: (b) =>
            LinearGradient(colors: colors).createShader(b),
        blendMode: BlendMode.srcIn,
        child: text,
      );
    }
    return text;
  }
}
