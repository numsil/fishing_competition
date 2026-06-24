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

    // 세션이 생기는 모든 경우에 토큰 등록.
    // 자동 로그인(세션 복원)은 signedIn 이 아니라 initialSession 이벤트라서
    // session != null 전체를 처리해야 토큰이 누락되지 않는다.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
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
      // iOS: FCM 토큰은 APNs 토큰이 준비된 뒤에야 발급된다. 준비될 때까지 대기.
      if (Platform.isIOS) {
        var apns = await messaging.getAPNSToken();
        var tries = 0;
        while (apns == null && tries < 15) {
          await Future.delayed(const Duration(milliseconds: 500));
          apns = await messaging.getAPNSToken();
          tries++;
        }
        if (apns == null) {
          if (kDebugMode) debugPrint('[Push] APNS token 아직 없음 → 등록 보류');
          return;
        }
      }
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
