import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_repository.g.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  /// signOut 직후 ProviderScope가 재생성되면서 호출자의 SnackBar가 사라지므로,
  /// 다음에 로그인 화면이 떴을 때 보여줄 안내문을 여기에 보관한다.
  /// 표시 후 login_screen 쪽에서 null로 초기화.
  static String? pendingLoginMessage;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
  User? get currentUser => _supabase.auth.currentUser;

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(email: email, password: password);
    if (response.user != null) {
      final blockReason = await _checkLoginBlock();
      if (blockReason != null) {
        pendingLoginMessage = blockReason;
        await _supabase.auth.signOut();
        throw Exception('blocked');
      }
    }
    return response;
  }

  /// 로그인 후 차단 사유 확인 (정지 / 탈퇴). 차단되어야 한다면 사용자에게 보일 메시지 반환.
  Future<String?> _checkLoginBlock() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final row = await _supabase
        .from('users')
        .select('status, is_deleted')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) return null;
    if (row['status'] == 'banned') {
      return '이용이 정지된 계정입니다. 문의: support@nakstar.app';
    }
    if (row['is_deleted'] == true) {
      return '탈퇴한 계정입니다.';
    }
    return null;
  }

  /// (deprecated alias for legacy callers)
  Future<bool> isCurrentUserBanned() async {
    return (await _checkLoginBlock()) != null;
  }

  /// 회원 탈퇴 (soft-delete). RPC가 users + posts 를 한 트랜잭션으로 처리.
  /// auth.users 의 hard-delete 는 service_role 필요하므로 여기서는 미수행.
  Future<void> withdraw() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    await _supabase.rpc('withdraw_user');
    await _supabase.auth.signOut();
  }

  Future<String> _generateUniqueUserKey(String username) async {
    String candidate = username;
    int suffix = 2;
    while (true) {
      final existing = await _supabase
          .from('users')
          .select('id')
          .eq('user_key', candidate)
          .maybeSingle();
      if (existing == null) return candidate;
      candidate = '$username$suffix';
      suffix++;
    }
  }

  Future<AuthResponse> signUpWithEmail(
    String email,
    String password,
    String username, {
    required DateTime birthDate,
    required String gender, // 'M' or 'F'
    required bool marketingAgreed,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
    if (response.user != null) {
      final userKey = await _generateUniqueUserKey(username);
      final now = DateTime.now().toUtc().toIso8601String();
      await _supabase.from('users').insert({
        'id': response.user!.id,
        'email': email,
        'username': username,
        'user_key': userKey,
        'birth_date':
            '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
        'gender': gender,
        'terms_agreed_at': now,
        'privacy_agreed_at': now,
        if (marketingAgreed) 'marketing_agreed_at': now,
      });
    }
    return response;
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepository(Supabase.instance.client);
}

@riverpod
Stream<AuthState> authState(AuthStateRef ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
}

@riverpod
User? currentUser(CurrentUserRef ref) {
  return ref.watch(authRepositoryProvider).currentUser;
}
