import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── 다크 모드 (기본) ──────────────────────────────
  static const Color darkBg = Color(0xFF0A0A0A);         // 배경
  static const Color darkSurface = Color(0xFF141414);    // 카드
  static const Color darkSurface2 = Color(0xFF1E1E1E);   // 입력창
  static const Color neonGreen = Color(0xFF00FF88);      // 형광 녹색 (메인 포인트)
  static const Color neonGreenDim = Color(0xFF00CC6A);   // 형광 녹색 (어두운)
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkTextSub = Color(0xFF9E9E9E);
  static const Color darkDivider = Color(0xFF2A2A2A);

  // ── 라이트 모드 ───────────────────────────────────
  static const Color lightBg = Color(0xFFF8F9FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color navy = Color(0xFF1A2A6C);           // 남색 (메인)
  static const Color navyLight = Color(0xFF2E4099);
  static const Color lightText = Color(0xFF111827);
  static const Color lightTextSub = Color(0xFF6B7280);
  static const Color lightDivider = Color(0xFFE5E7EB);

  // ── 공통 ─────────────────────────────────────────
  static const Color gold = Color(0xFFFFD700);
  static const Color silver = Color(0xFFB0BEC5);
  static const Color bronze = Color(0xFFCD7F32);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color liveRed = Color(0xFFFF3B30);
}
