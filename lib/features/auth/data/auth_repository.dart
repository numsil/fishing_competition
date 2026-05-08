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
    if (response.user != null && await isCurrentUserBanned()) {
      pendingLoginMessage = '이용이 정지된 계정입니다. 문의: support@nakstar.app';
      await _supabase.auth.signOut();
      throw Exception('banned');
    }
    return response;
  }

  /// 현재 로그인된 사용자가 banned 상태인지 확인
  Future<bool> isCurrentUserBanned() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    final row = await _supabase
        .from('users')
        .select('status')
        .eq('id', user.id)
        .maybeSingle();
    return row?['status'] == 'banned';
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

  Future<AuthResponse> signUpWithEmail(String email, String password, String username) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
    if (response.user != null) {
      final userKey = await _generateUniqueUserKey(username);
      await _supabase.from('users').insert({
        'id': response.user!.id,
        'email': email,
        'username': username,
        'user_key': userKey,
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
