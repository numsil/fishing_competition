import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/data/auth_repository.dart';

const String _bannedMessage = '이용이 정지된 계정입니다. 문의: support@nakstar.app';

/// RLS의 active_user_required_* 정책 위반 또는 권한 부족(42501)인지 판별.
///
/// 정지(banned)·삭제 유저는 모든 쓰기 INSERT/UPDATE에서
/// "row-level security policy" 에러를 받게 된다.
bool isBannedWriteError(Object error) {
  if (error is PostgrestException) {
    if (error.code == '42501') return true;
    final m = error.message.toLowerCase();
    if (m.contains('row-level security') ||
        m.contains('violates row-level security policy')) {
      return true;
    }
  }
  final s = error.toString().toLowerCase();
  return s.contains('row-level security') ||
      s.contains('violates row-level security policy');
}

/// 쓰기 호출의 catch 블록에서 사용. banned로 판별되면
///   - 다음 로그인 화면에 띄울 메시지를 세팅하고
///   - 즉시 signOut → ProviderScope 재생성으로 로그인 화면 이동
/// 처리했으면 true 반환 (호출부는 이후 자체 에러 표시를 건너뛰면 됨).
Future<bool> handleIfBanned(Object error) async {
  if (!isBannedWriteError(error)) return false;
  AuthRepository.pendingLoginMessage = _bannedMessage;
  try {
    await Supabase.instance.client.auth.signOut();
  } catch (_) {/* 무시 */}
  return true;
}
