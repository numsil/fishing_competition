class AppConstants {
  AppConstants._();

  static const String appName = '피싱그램';
  static const String appVersion = '1.0.0';

  static const String baseUrl = 'https://api.huk.app';
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

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
}
