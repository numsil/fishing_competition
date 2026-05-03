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
}
