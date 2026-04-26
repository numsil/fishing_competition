/// 애니메이션 지속 시간 토큰.
class AppDurations {
  AppDurations._();

  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 450);

  /// async + Navigator 패턴에서 다이얼로그 닫힘 애니메이션 대기 시간
  static const Duration dialogClose = Duration(milliseconds: 300);

  /// 스낵바 표시 시간
  static const Duration snackBar = Duration(milliseconds: 1800);
}
