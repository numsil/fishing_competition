import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../deep_link/deep_link_service.dart';
import '../../features/notifications/data/notification_repository.dart';

/// FCM 토큰 등록·권한 요청·알림 탭 라우팅을 담당.
class PushService {
  PushService(this._router);
  final GoRouter _router;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;
  StreamSubscription<AuthState>? _authSub;

  Future<void> start() async {
    final messaging = FirebaseMessaging.instance;

    // 권한 요청 (iOS 필수, Android 13+ 권장)
    await messaging.requestPermission();

    await _registerToken(messaging);
    _tokenRefreshSub = messaging.onTokenRefresh.listen((t) => _saveToken(t));

    // 로그인 시점에 토큰 등록 (앱 시작 때 로그아웃 상태였다가 로그인하는 경우 대응)
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _registerToken(messaging);
      }
    });

    // 종료 상태에서 알림 탭으로 앱이 열린 경우
    final initial = await messaging.getInitialMessage();
    if (initial != null) _handleTap(initial);

    // 백그라운드(앱 살아있음)에서 알림 탭
    _messageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _messageOpenedSub?.cancel();
    _authSub?.cancel();
  }

  Future<void> _registerToken(FirebaseMessaging messaging) async {
    try {
      final token = await messaging.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      if (kDebugMode) debugPrint('[Push] token error: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentUser == null) return;
    final platform = Platform.isIOS ? 'ios' : 'android';
    await NotificationRepository(supabase).upsertDeviceToken(token, platform);
  }

  void _handleTap(RemoteMessage message) {
    final data = message.data;
    final route = routeFromNotification(
      data['type'] as String? ?? '',
      data['target_id'] as String?,
      actorId: data['actor_id'] as String?,
    );
    if (route != null) _router.go(route);
  }
}
