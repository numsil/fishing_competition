import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_repository.g.dart';

/// 본인 계정 상태 통합 DTO. users 테이블의 비공개 컬럼(email, status, role 등)은
/// REST 로 직접 조회할 수 없으므로 `get_my_account_status` RPC 응답을 래핑한다.
class MyAccountStatus {
  final String status;
  final bool isDeleted;
  final String? role;
  final bool isVerifier;
  final DateTime? locationAgreedAt;
  final String? email;

  MyAccountStatus({
    required this.status,
    required this.isDeleted,
    required this.role,
    required this.isVerifier,
    required this.locationAgreedAt,
    required this.email,
  });

  bool get isBanned => status == 'banned';
  bool get isAdmin => role == 'admin';
}

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  /// signOut 직후 ProviderScope가 재생성되면서 호출자의 SnackBar가 사라지므로,
  /// 다음에 로그인 화면이 떴을 때 보여줄 안내문을 여기에 보관한다.
  /// 표시 후 login_screen 쪽에서 null로 초기화.
  static String? pendingLoginMessage;

  // 본인 계정 상태 in-memory 캐시 (TTL 5분). main/auth/verification/location_consent
  // 4곳에서 공유. 로그아웃 시 invalidate, 차단 검사 시 forceRefresh.
  static MyAccountStatus? _cachedStatus;
  static DateTime? _cachedStatusAt;
  static const _statusCacheTtl = Duration(minutes: 5);

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

  /// 본인 계정 상태 조회. 5분 캐시. status/role/is_verifier/location_agreed_at/email
  /// 같이 한 번에 받음. 비로그인 / 행 없음 시 null.
  Future<MyAccountStatus?> getMyAccountStatus({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedStatus != null &&
        _cachedStatusAt != null &&
        DateTime.now().difference(_cachedStatusAt!) < _statusCacheTtl) {
      return _cachedStatus;
    }
    if (_supabase.auth.currentUser == null) return null;
    final res = await _supabase.rpc('get_my_account_status');
    if (res is! List || res.isEmpty) return null;
    final r = res.first as Map<String, dynamic>;
    final fetched = MyAccountStatus(
      status: (r['status'] as String?) ?? 'active',
      isDeleted: (r['is_deleted'] as bool?) ?? false,
      role: r['role'] as String?,
      isVerifier: (r['is_verifier'] as bool?) ?? false,
      locationAgreedAt: r['location_agreed_at'] == null
          ? null
          : DateTime.parse(r['location_agreed_at'] as String).toUtc(),
      email: r['email'] as String?,
    );
    _cachedStatus = fetched;
    _cachedStatusAt = DateTime.now();
    return fetched;
  }

  /// 캐시 무효화 (로그아웃 / 위치 동의 갱신 등에서 호출).
  static void invalidateAccountStatusCache() {
    _cachedStatus = null;
    _cachedStatusAt = null;
  }

  /// 로그인 후 차단 사유 확인 (정지 / 탈퇴). 차단되어야 한다면 사용자에게 보일 메시지 반환.
  Future<String?> _checkLoginBlock() async {
    final s = await getMyAccountStatus(forceRefresh: true);
    if (s == null) return null;
    if (s.isBanned) {
      return '이용이 정지된 계정입니다. 문의: support@nakstar.app';
    }
    if (s.isDeleted) {
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
    invalidateAccountStatusCache();
    await _supabase.auth.signOut();
  }

  /// 가입. raw_user_meta_data 에 모든 정보 담아 보내면 DB 트리거 handle_new_user 가
  /// public.users 행을 자동 생성한다 (Email Confirm ON 환경에서도 작동).
  Future<AuthResponse> signUpWithEmail(
    String email,
    String password,
    String username, {
    required DateTime birthDate,
    required String gender, // 'M' or 'F'
    required bool marketingAgreed,
    required String termsVersion,
    required String privacyVersion,
    required String marketingVersion,
  }) async {
    final birthStr =
        '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}';
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'username': username,
        'birth_date': birthStr,
        'gender': gender,
        'marketing_agreed': marketingAgreed,
        'terms_version': termsVersion,
        'privacy_version': privacyVersion,
        'marketing_version': marketingVersion,
      },
    );
  }

  Future<void> signOut() async {
    invalidateAccountStatusCache();
    await _supabase.auth.signOut();
  }

  // ─────────────────────────────────────────
  // 비밀번호 변경 (이메일 OTP 방식)
  // ─────────────────────────────────────────

  /// 1단계: 이메일로 6자리 OTP 발송.
  /// Supabase 기본은 magic link + token 둘 다 보내지만 우리는 token만 사용.
  /// 이메일 존재 여부는 응답에 노출되지 않음 (privacy).
  Future<void> requestPasswordOtp(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  /// 2-A 단계: OTP 검증만.
  /// 성공하면 recovery 세션이 만들어져서 이후 updateUser 호출 가능.
  /// 이 단계에서 banned/탈퇴 검사도 같이 수행.
  Future<void> verifyPasswordOtp({
    required String email,
    required String token,
  }) async {
    final res = await _supabase.auth.verifyOTP(
      type: OtpType.recovery,
      email: email,
      token: token,
    );
    if (res.user == null) {
      throw Exception('OTP 검증에 실패했습니다');
    }
    // 정지·탈퇴 계정이면 비번 변경 자체를 막고 강제 로그아웃
    final blockReason = await _checkLoginBlock();
    if (blockReason != null) {
      pendingLoginMessage = blockReason;
      await _supabase.auth.signOut();
      throw Exception('blocked');
    }
  }

  /// 2-B 단계: 현재 세션(recovery)으로 비번만 업데이트.
  /// 같은 비번이면 Supabase 가 422 same_password 에러를 던짐 → 호출부에서 분기.
  Future<void> changePasswordWithSession(String newPassword) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
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
