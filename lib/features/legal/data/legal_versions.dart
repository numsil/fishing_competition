/// 약관·정책 버전 상수.
/// 약관 본문 개정 시 이 숫자를 올린다 (예: '1.0' → '1.1').
/// 가입 시점에 users.{terms,privacy,marketing}_version 으로 저장되어
/// 추후 강제 재동의 흐름을 도입할 때 사용된다.
class LegalVersions {
  LegalVersions._();

  static const String terms = '1.0';
  static const String privacy = '1.0';
  static const String marketing = '1.0';
}
