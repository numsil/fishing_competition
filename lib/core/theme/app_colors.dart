import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── 다크 모드 (기본) ──────────────────────────────
  static const Color darkBg = Color(0xFF09090B);         // Zinc-950
  static const Color darkSurface = Color(0xFF18181B);    // Zinc-900
  static const Color darkSurface2 = Color(0xFF27272A);   // Zinc-800
  static const Color neonGreen = Color(0xFF00FF88);      // 형광 녹색 (메인 포인트)
  static const Color neonGreenDim = Color(0xFF00CC6A);   // 형광 녹색 (어두운)
  static const Color darkText = Color(0xFFFAFAFA);       // Zinc-50
  static const Color darkTextSub = Color(0xFFA1A1AA);    // Zinc-400
  static const Color darkDivider = Color(0xFF27272A);    // Zinc-800

  // ── 라이트 모드 ───────────────────────────────────
  static const Color lightBg = Color(0xFFF4F4F5);        // Zinc-100
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color navy = Color(0xFF1A2A6C);           // 남색 (메인)
  static const Color navyLight = Color(0xFF2E4099);
  static const Color lightText = Color(0xFF09090B);      // Zinc-950
  static const Color lightTextSub = Color(0xFF71717A);   // Zinc-500
  static const Color lightDivider = Color(0xFFE4E4E7);   // Zinc-200

  // ── 공통 ─────────────────────────────────────────
  static const Color gold = Color(0xFFFFD700);
  static const Color silver = Color(0xFFB0BEC5);
  static const Color bronze = Color(0xFFCD7F32);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color liveRed = Color(0xFFFF3B30);

  // ── 팀전 팀 색상 ──
  // 키는 league_teams.color 에 저장되는 값이다. 변경 금지.
  // 색상만으로 구분되지 않도록 UI 에서 팀명을 항상 함께 표시한다.
  static const Map<String, Color> teamColors = {
    'red': Color(0xFFE8674B),
    'blue': Color(0xFF4B8FE8),
    'green': Color(0xFF3DD6A0),
    'amber': Color(0xFFE8B84B),
    'purple': Color(0xFFA77BE8),
    'pink': Color(0xFFE86BA8),
  };

  /// 저장된 색 키를 Color 로. 알 수 없는 키/없는 값은 첫 색으로 대체한다.
  static Color teamColor(String? key) =>
      teamColors[key] ?? teamColors.values.first;

  /// 새 팀에 돌아가며 배정할 색 키.
  static String teamColorKeyAt(int index) =>
      teamColors.keys.elementAt(index % teamColors.length);

  /// 아직 쓰지 않은 첫 색 키. 팔레트를 다 쓰면 첫 색으로 되돌아간다.
  ///
  /// 팀 개수를 인덱스로 쓰면 중간 팀을 삭제한 뒤 추가할 때 남은 팀과 색이
  /// 겹쳐 호스트가 구분할 수 없게 된다 (색 변경 외에 되돌릴 방법이 없다).
  static String nextUnusedTeamColorKey(Iterable<String?> usedKeys) {
    final used = usedKeys.whereType<String>().toSet();
    for (final key in teamColors.keys) {
      if (!used.contains(key)) return key;
    }
    return teamColors.keys.first;
  }
}
