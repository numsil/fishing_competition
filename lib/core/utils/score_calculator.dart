import 'dart:math';

/// 배스 길이(cm) → 점수 변환
///
/// 공식: round(length^2.5 / 800) × tier_multiplier
/// 30cm 이하 = 0점
int calculateFishScore(double? lengthCm) {
  if (lengthCm == null || lengthCm <= 30) return 0;

  final base = pow(lengthCm, 2.5) / 800;

  final double multiplier;
  if (lengthCm >= 60)      multiplier = 10.0;
  else if (lengthCm >= 55) multiplier = 7.0;
  else if (lengthCm >= 50) multiplier = 5.0;
  else if (lengthCm >= 45) multiplier = 3.0;
  else if (lengthCm >= 40) multiplier = 2.0;
  else                     multiplier = 1.5; // 31~39cm

  return (base * multiplier).round();
}
