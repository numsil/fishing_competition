import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<AuthState>? _authSub;

  /// 포그라운드 알림을 직접 그리기 위한 플러그인 (Android 전용).
  final _local = FlutterLocalNotificationsPlugin();

  /// 포그라운드 알림 채널. 백그라운드 FCM 알림은 Firebase SDK 가 만드는
  /// 기본 채널을 쓴다 — 매니페스트의 default_notification_channel_id 를
  /// 이 채널로 바꾸면 통일되지만, 채널이 없을 때 백그라운드 알림이 조용히
  /// 안 뜨는 위험이 있어 건드리지 않았다.
  static const _channel = AndroidNotificationChannel(
    'huk_foreground',
    '앱 사용 중 알림',
    description: '앱을 보고 있을 때 도착한 알림',
    importance: Importance.high,
  );

  Future<void> start() async {
    final messaging = FirebaseMessaging.instance;

    // 권한 요청 (iOS 필수, Android 13+ 권장)
    await messaging.requestPermission();

    await _setupForeground(messaging);

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

    // 포그라운드(앱 보는 중)로 도착한 알림
    _foregroundSub = FirebaseMessaging.onMessage.listen(_showForeground);
  }

  /// 포그라운드에서 알림을 보여줄 준비.
  ///
  /// iOS 는 `setForegroundNotificationPresentationOptions` 만으로 시스템이
  /// 직접 배너를 띄운다. 그래서 iOS 에서는 로컬 알림을 쓰지 않는다 —
  /// 둘 다 쓰면 같은 알림이 두 번 뜬다.
  ///
  /// Android 는 FCM SDK 가 포그라운드에서 시스템 알림을 아예 그리지 않으므로
  /// 로컬 알림으로 직접 다시 띄워야 한다.
  Future<void> _setupForeground(FirebaseMessaging messaging) async {
    try {
      if (Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        return;
      }

      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: _onLocalTap,
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    } catch (e) {
      if (kDebugMode) debugPrint('[Push] foreground setup error: $e');
    }
  }

  /// 포그라운드 메시지 → Android 로컬 알림.
  void _showForeground(RemoteMessage message) {
    if (!Platform.isAndroid) return;
    final n = message.notification;
    if (n == null) return; // data-only 메시지는 보여줄 문구가 없다
    try {
      _local.show(
        // id 가 겹치면 알림이 서로를 덮어쓴다. 32비트 범위로 자른 시각.
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title: n.title,
        body: n.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        // 탭 라우팅은 FCM data 를 그대로 받아서 처리한다.
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Push] foreground show error: $e');
    }
  }

  /// 로컬 알림 탭 → FCM 알림 탭과 같은 경로로 라우팅.
  void _onLocalTap(NotificationResponse res) {
    final raw = res.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final data = (jsonDecode(raw) as Map).cast<String, dynamic>();
      _route(
        data['type'] as String? ?? '',
        data['target_id'] as String?,
        data['actor_id'] as String?,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Push] local tap payload error: $e');
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _messageOpenedSub?.cancel();
    _foregroundSub?.cancel();
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
    _route(
      data['type'] as String? ?? '',
      data['target_id'] as String?,
      data['actor_id'] as String?,
    );
  }

  void _route(String type, String? targetId, String? actorId) {
    final route = routeFromNotification(type, targetId, actorId: actorId);
    if (route != null) _router.go(route);
  }
}
