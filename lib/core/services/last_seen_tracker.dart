import 'package:supabase_flutter/supabase_flutter.dart';

/// users.last_seen_at 갱신 트래커.
/// - 앱 포그라운드 진입 시 호출
/// - 메모리 throttle: 5분 이내 재호출은 no-op (네트워크/DB 부담 회피)
/// - 앱 콜드 스타트 시 첫 호출은 무조건 실행
/// - 실패는 조용히 무시 (네트워크 일시 단절 등)
class LastSeenTracker {
  LastSeenTracker._();

  static const Duration _throttle = Duration(minutes: 5);
  static DateTime? _lastWrite;

  /// 외부 트리거 진입점. 호출자는 그냥 fire-and-forget.
  static Future<void> ping() async {
    final now = DateTime.now();
    if (_lastWrite != null && now.difference(_lastWrite!) < _throttle) return;

    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    _lastWrite = now; // throttle 먼저 세팅 (실패해도 5분간 재시도 X)
    try {
      await supabase.from('users').update({
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
    } catch (_) {
      // 네트워크/RLS 실패 무시. 다음 throttle 만료 후 재시도.
    }
  }

  /// 로그아웃·재로그인 시 throttle 리셋.
  static void reset() {
    _lastWrite = null;
  }
}
