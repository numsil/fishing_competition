import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_model.dart';

part 'notification_repository.g.dart';

class NotificationRepository {
  final SupabaseClient _supabase;
  NotificationRepository(this._supabase);

  String? get _myId => _supabase.auth.currentUser?.id;

  Future<List<AppNotification>> getNotifications() async {
    final myId = _myId;
    if (myId == null) return [];
    final data = await _supabase
        .from('notifications')
        .select(
            'id, type, actor_id, target_id, body, is_read, created_at, actor:users!actor_id(username, avatar_url)')
        .eq('user_id', myId)
        .order('created_at', ascending: false)
        .limit(50);
    final all = (data as List)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();

    // DM 알림은 대화(target_id)별 최신 1개만 노출해 알림함이 지저분해지지 않게 한다.
    // (created_at 내림차순이라 각 대화의 첫 등장이 최신 = 유지)
    final seenDmConversations = <String>{};
    return all.where((n) {
      if (n.type != 'dm') return true;
      final key = n.targetId ?? n.actorId; // 대화 식별자(없으면 상대방 기준)
      return seenDmConversations.add(key); // 처음이면 true(유지), 중복이면 false(제외)
    }).toList();
  }

  Future<void> markAllRead() async {
    final myId = _myId;
    if (myId == null) return;
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', myId)
        .eq('is_read', false);
  }

  Future<void> deleteNotification(String id) async {
    await _supabase.from('notifications').delete().eq('id', id);
  }

  Future<void> upsertDeviceToken(String token, String platform) async {
    final myId = _myId;
    if (myId == null) return;
    await _supabase.from('device_tokens').upsert({
      'user_id': myId,
      'token': token,
      'platform': platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> deleteDeviceToken(String token) async {
    await _supabase.from('device_tokens').delete().eq('token', token);
  }
}

@riverpod
NotificationRepository notificationRepository(NotificationRepositoryRef ref) {
  return NotificationRepository(Supabase.instance.client);
}

// 알림 목록 (Realtime INSERT/UPDATE 시 재조회)
@riverpod
Stream<List<AppNotification>> notificationList(NotificationListRef ref) {
  final myId = Supabase.instance.client.auth.currentUser?.id;
  if (myId == null) return Stream.value([]);

  final controller = StreamController<List<AppNotification>>.broadcast();
  final repo = ref.read(notificationRepositoryProvider);

  Future<void> fetch() async {
    try {
      final list = await repo.getNotifications();
      if (!controller.isClosed) controller.add(list);
    } catch (e) {
      if (!controller.isClosed) controller.addError(e);
    }
  }

  fetch();

  final channel = Supabase.instance.client
      .channel('notifications_$myId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: myId,
        ),
        callback: (_) => fetch(),
      )
      .subscribe();

  ref.onDispose(() {
    controller.close();
    Supabase.instance.client.removeChannel(channel);
  });

  return controller.stream;
}

// 안읽음 배지
@riverpod
Stream<bool> hasUnreadNotifications(HasUnreadNotificationsRef ref) {
  final myId = Supabase.instance.client.auth.currentUser?.id;
  if (myId == null) return Stream.value(false);

  final controller = StreamController<bool>.broadcast();

  Future<void> check() async {
    try {
      final rows = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', myId)
          .eq('is_read', false)
          .limit(1);
      if (!controller.isClosed) controller.add((rows as List).isNotEmpty);
    } catch (_) {
      if (!controller.isClosed) controller.add(false);
    }
  }

  check();

  final channel = Supabase.instance.client
      .channel('notif_badge_$myId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: myId,
        ),
        callback: (_) => check(),
      )
      .subscribe();

  ref.onDispose(() {
    controller.close();
    Supabase.instance.client.removeChannel(channel);
  });

  return controller.stream;
}
