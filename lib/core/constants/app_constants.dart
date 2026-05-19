class AppConstants {
  AppConstants._();

  static const String appName = 'Nakstar';
  static const String appVersion = '1.0.0';

  static const int defaultPageSize = 20;

  // 배지 기준
  static const double lunkerBassThreshold = 50.0; // cm
  static const double bigFishThreshold = 40.0;

  // 점수
  static const int hostSuccessScore = 100;
  static const int win1stScore = 300;
  static const int win2ndScore = 200;
  static const int win3rdScore = 100;
  static const int participationScore = 50;

  /// 관리자 시드 계정 UUID (DB에 시드됨, 문의하기 DM 상대방).
  /// 변경 시 supabase/migrations/20260510175213_admin_user_seed.sql 동기화 필요.
  static const String adminUserId = '00000000-0000-0000-0000-000000000001';
  static const String adminUsername = 'NAKSTAR 관리자';
}
