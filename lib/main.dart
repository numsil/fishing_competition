import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router/app_router.dart';
import 'core/services/last_seen_tracker.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경변수 로드
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('.env 파일을 찾을 수 없습니다.');
  }

  // Supabase 초기화
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } else {
    debugPrint('Supabase URL 또는 Anon Key가 설정되지 않았습니다.');
  }

  runApp(const AppRootWidget());
}

/// Supabase signedOut 이벤트를 감지해 ProviderScope를 재생성 → 모든 캐시 초기화
class AppRootWidget extends StatefulWidget {
  const AppRootWidget({super.key});

  @override
  State<AppRootWidget> createState() => _AppRootWidgetState();
}

class _AppRootWidgetState extends State<AppRootWidget>
    with WidgetsBindingObserver {
  int _scopeKey = 0;
  StreamSubscription<AuthState>? _authSub;
  bool _checkingBan = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 콜드 스타트 시 1회 (이미 로그인 상태면)
    LastSeenTracker.ping();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        LastSeenTracker.reset();
        setState(() => _scopeKey++);
      } else if (data.event == AuthChangeEvent.signedIn) {
        LastSeenTracker.ping();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verifyNotBanned();
      LastSeenTracker.ping();
    }
  }

  /// 앱이 포그라운드로 돌아올 때 banned/삭제 상태를 재확인.
  /// 정지된 유저는 즉시 강제 로그아웃 → ProviderScope 리셋되어 로그인 화면으로 이동.
  Future<void> _verifyNotBanned() async {
    if (_checkingBan) return;
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    _checkingBan = true;
    try {
      final row = await supabase
          .from('users')
          .select('status, is_deleted')
          .eq('id', user.id)
          .maybeSingle();
      final inactive = row == null ||
          row['status'] == 'banned' ||
          row['is_deleted'] == true;
      if (inactive) {
        AuthRepository.pendingLoginMessage =
            '이용이 정지된 계정입니다. 문의: support@nakstar.app';
        await supabase.auth.signOut();
      }
    } catch (_) {/* 네트워크 에러는 무시 (다음 resume 때 재시도) */}
    _checkingBan = false;
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      key: ValueKey(_scopeKey),
      child: const FishingCompetitionApp(),
    );
  }
}

class FishingCompetitionApp extends ConsumerWidget {
  const FishingCompetitionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Nakstar',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
    );
  }
}
