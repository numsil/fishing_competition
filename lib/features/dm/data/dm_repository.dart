import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

part 'dm_repository.g.dart';

/// 매물 카드 딥링크 마커. 메시지 본문에 심고 채팅 버블에서 카드로 렌더한다.
/// 리그 초대 링크(`https://nakstar.app/league/{id}`)와 동일 계열 포맷.
String marketItemLink(String itemId) => 'https://nakstar.app/market/$itemId';

/// 차단된 사용자에게 DM 시도 시 던지는 예외. UI 에서 친절한 메시지로 변환.
class DmBlockedException implements Exception {
  const DmBlockedException();
  @override
  String toString() => '차단한 사용자에게는 메시지를 보낼 수 없습니다';
}

class DmConversation {
  final String id;
  final String otherUserId;
  final String otherUsername;
  final String? otherAvatarUrl;
  final String? lastMessage;
  final DateTime lastMessageAt;
  final bool hasUnread;

  DmConversation({
    required this.id,
    required this.otherUserId,
    required this.otherUsername,
    this.otherAvatarUrl,
    this.lastMessage,
    required this.lastMessageAt,
    required this.hasUnread,
  });
}

class DmMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  DmMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory DmMessage.fromJson(Map<String, dynamic> json) {
    return DmMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

/// DM 채팅방에 문의 매물 컨텍스트를 실어 보내기 위한 표시용 값 객체.
/// marketplace 모델에 의존하지 않도록 원시값(문자열)만 담는다.
class DmPendingItem {
  final String itemId;
  final String title;
  final String priceLabel;
  final String? thumbnailUrl;
  const DmPendingItem({
    required this.itemId,
    required this.title,
    required this.priceLabel,
    this.thumbnailUrl,
  });
}

/// /dm/chat 라우트 extra: 대화방 + (선택) 문의 대기 매물.
/// pendingItem이 있으면 채팅방 입력창 위에 매물 미리보기 바를 띄운다.
class DmChatArgs {
  final DmConversation conversation;
  final DmPendingItem? pendingItem;
  const DmChatArgs({required this.conversation, this.pendingItem});
}

class DmRepository {
  final SupabaseClient _supabase;

  DmRepository(this._supabase);

  String? get _myId => _supabase.auth.currentUser?.id;

  Future<List<DmConversation>> getConversations() async {
    final myId = _myId;
    if (myId == null) return [];

    // 차단한 사용자와의 대화는 목록에서 숨김
    final blockedIds = await AuthRepository(_supabase).getBlockedUserIds();
    final blockedSet = blockedIds.toSet();

    final data = await _supabase
        .from('conversations')
        .select(
          'id, user1_id, user2_id, last_message, last_message_at, '
          'unread_count_user1, unread_count_user2, '
          'user1_hidden_at, user2_hidden_at, '
          'user1:users!user1_id(id, username, avatar_url), '
          'user2:users!user2_id(id, username, avatar_url)',
        )
        .or('user1_id.eq.$myId,user2_id.eq.$myId')
        .order('last_message_at', ascending: false);

    final conversations = <DmConversation>[];
    for (final row in data as List) {
      final isUser1 = (row['user1_id'] as String) == myId;

      final hiddenAtStr = isUser1
          ? row['user1_hidden_at'] as String?
          : row['user2_hidden_at'] as String?;
      final lastMessageAt = DateTime.parse(row['last_message_at'] as String).toLocal();
      if (hiddenAtStr != null) {
        final hiddenAt = DateTime.parse(hiddenAtStr).toLocal();
        if (!lastMessageAt.isAfter(hiddenAt)) continue;
      }

      final otherUserId =
          isUser1 ? row['user2_id'] as String : row['user1_id'] as String;

      // 차단한 사용자와의 대화 숨김
      if (blockedSet.contains(otherUserId)) continue;

      final otherUser =
          (isUser1 ? row['user2'] : row['user1']) as Map<String, dynamic>?;
      if (otherUser == null) continue;

      final unreadCount = isUser1
          ? row['unread_count_user1'] as int
          : row['unread_count_user2'] as int;

      conversations.add(DmConversation(
        id: row['id'] as String,
        otherUserId: otherUserId,
        otherUsername: otherUser['username'] as String,
        otherAvatarUrl: otherUser['avatar_url'] as String?,
        lastMessage: row['last_message'] as String?,
        lastMessageAt: lastMessageAt,
        hasUnread: unreadCount > 0,
      ));
    }
    return conversations;
  }

  /// 두 유저 사이의 대화방 ID를 반환 (없으면 생성)
  /// user1_id < user2_id 순으로 항상 정렬해서 저장.
  /// 차단한 사용자에 대해서는 [DmBlockedException] 던짐.
  Future<String> getOrCreateConversation(String otherUserId) async {
    final myId = _myId;
    if (myId == null) throw Exception('로그인이 필요합니다');

    final blockedIds = await AuthRepository(_supabase).getBlockedUserIds();
    if (blockedIds.contains(otherUserId)) {
      throw const DmBlockedException();
    }

    final ids = [myId, otherUserId]..sort();
    final user1Id = ids[0];
    final user2Id = ids[1];

    final existing = await _supabase
        .from('conversations')
        .select('id')
        .eq('user1_id', user1Id)
        .eq('user2_id', user2Id)
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    final result = await _supabase
        .from('conversations')
        .insert({'user1_id': user1Id, 'user2_id': user2Id})
        .select('id')
        .single();

    return result['id'] as String;
  }

  // 초기 fetch + postgres_changes INSERT만 수신 → 전체 재전송 없음
  Stream<List<DmMessage>> streamMessages(String conversationId) {
    final controller = StreamController<List<DmMessage>>();
    final messages = <DmMessage>[];
    final seenIds = <String>{};

    Future<void> initialFetch() async {
      try {
        final data = await _supabase
            .from('messages')
            .select('id, conversation_id, sender_id, content, is_read, created_at')
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: true);
        for (final item in data as List) {
          final msg = DmMessage.fromJson(item);
          if (seenIds.add(msg.id)) messages.add(msg);
        }
        if (!controller.isClosed) controller.add(List.of(messages));
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    final channel = _supabase
        .channel('messages_$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            try {
              final newMsg = DmMessage.fromJson(payload.newRecord);
              if (seenIds.add(newMsg.id)) {
                messages.add(newMsg);
                if (!controller.isClosed) controller.add(List.of(messages));
              }
            } catch (_) {}
          },
        )
        .subscribe();

    initialFetch();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
    };

    return controller.stream;
  }

  Future<DmMessage> sendMessage(String conversationId, String content) async {
    final myId = _myId;
    if (myId == null) throw Exception('로그인이 필요합니다');

    // 차단 체크: 대화 상대가 차단 목록에 있으면 차단 (차단 후 기존 대화창에서
    // 메시지 보내려는 케이스 차단).
    final convRow = await _supabase
        .from('conversations')
        .select('user1_id, user2_id')
        .eq('id', conversationId)
        .maybeSingle();
    if (convRow != null) {
      final otherId = (convRow['user1_id'] as String) == myId
          ? convRow['user2_id'] as String
          : convRow['user1_id'] as String;
      final blockedIds = await AuthRepository(_supabase).getBlockedUserIds();
      if (blockedIds.contains(otherId)) {
        throw const DmBlockedException();
      }
    }

    final row = await _supabase
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': myId,
          'content': content,
        })
        .select('id, conversation_id, sender_id, content, is_read, created_at')
        .single();

    await _supabase.rpc('on_dm_sent', params: {
      'p_conv_id': conversationId,
      'p_sender_id': myId,
      'p_content': content,
    });

    return DmMessage.fromJson(row);
  }

  /// 매물 문의 카드를 메시지로 전송. content엔 마커 URL을 넣어 채팅 버블이 카드로
  /// 렌더하고, 목록 미리보기(last_message)엔 raw URL 대신 친화 텍스트('📦 제목')를 넣는다.
  Future<DmMessage> sendItemCard(
    String conversationId, {
    required String itemId,
    required String title,
  }) async {
    final myId = _myId;
    if (myId == null) throw Exception('로그인이 필요합니다');

    // 차단 체크(sendMessage와 동일 규칙): 카드 전송이 차단을 우회하지 않도록.
    final convRow = await _supabase
        .from('conversations')
        .select('user1_id, user2_id')
        .eq('id', conversationId)
        .maybeSingle();
    if (convRow != null) {
      final otherId = (convRow['user1_id'] as String) == myId
          ? convRow['user2_id'] as String
          : convRow['user1_id'] as String;
      final blockedIds = await AuthRepository(_supabase).getBlockedUserIds();
      if (blockedIds.contains(otherId)) {
        throw const DmBlockedException();
      }
    }

    final content = marketItemLink(itemId);
    final row = await _supabase
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': myId,
          'content': content,
        })
        .select('id, conversation_id, sender_id, content, is_read, created_at')
        .single();

    // 목록 미리보기는 마커 URL이 아니라 친화 텍스트로 저장.
    await _supabase.rpc('on_dm_sent', params: {
      'p_conv_id': conversationId,
      'p_sender_id': myId,
      'p_content': '📦 $title',
    });

    return DmMessage.fromJson(row);
  }

  Future<void> markAsRead(String conversationId) async {
    final myId = _myId;
    if (myId == null) return;

    await _supabase
        .from('messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', myId)
        .eq('is_read', false);

    await _supabase.rpc('on_dm_read', params: {
      'p_conv_id': conversationId,
      'p_reader_id': myId,
    });
  }

  Future<void> hideConversation(String conversationId) async {
    final myId = _myId;
    if (myId == null) return;

    await _supabase.rpc('hide_conversation', params: {
      'p_conv_id': conversationId,
      'p_user_id': myId,
    });
  }
}

@riverpod
DmRepository dmRepository(DmRepositoryRef ref) {
  return DmRepository(Supabase.instance.client);
}

// Future → Stream: conversations 테이블 UPDATE 수신으로 목록 자동 갱신
@riverpod
Stream<List<DmConversation>> dmConversations(DmConversationsRef ref) {
  final myId = Supabase.instance.client.auth.currentUser?.id;
  if (myId == null) return Stream.value([]);

  final controller = StreamController<List<DmConversation>>.broadcast();
  final repo = ref.read(dmRepositoryProvider);

  Future<void> fetch() async {
    try {
      final convs = await repo.getConversations();
      if (!controller.isClosed) controller.add(convs);
    } catch (e) {
      if (!controller.isClosed) controller.addError(e);
    }
  }

  fetch();

  final channel = Supabase.instance.client
      .channel('conversations_list_$myId')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'conversations',
        callback: (payload) {
          final row = payload.newRecord;
          final u1 = row['user1_id'] as String?;
          final u2 = row['user2_id'] as String?;
          // 내가 포함된 대화방 업데이트만 처리
          if (u1 != myId && u2 != myId) return;
          fetch();
        },
      )
      .subscribe();

  ref.onDispose(() {
    controller.close();
    Supabase.instance.client.removeChannel(channel);
  });

  return controller.stream;
}

@riverpod
Stream<List<DmMessage>> dmMessages(DmMessagesRef ref, String conversationId) {
  return ref.watch(dmRepositoryProvider).streamMessages(conversationId);
}

// conversations UPDATE 이벤트 수신 시 payload로 내 대화방인지 먼저 확인 후 쿼리
// 쿼리 2개 → 1개(OR 조건)로 통합
@riverpod
Stream<bool> hasUnreadDms(HasUnreadDmsRef ref) {
  final myId = Supabase.instance.client.auth.currentUser?.id;
  if (myId == null) return Stream.value(false);

  final controller = StreamController<bool>.broadcast();

  Future<void> check() async {
    try {
      final supabase = Supabase.instance.client;
      final rows = await supabase
          .from('conversations')
          .select('user1_id, unread_count_user1, unread_count_user2')
          .or('user1_id.eq.$myId,user2_id.eq.$myId');
      final hasUnread = (rows as List).any((row) {
        final isUser1 = (row['user1_id'] as String) == myId;
        final count = isUser1
            ? (row['unread_count_user1'] as int? ?? 0)
            : (row['unread_count_user2'] as int? ?? 0);
        return count > 0;
      });
      if (!controller.isClosed) controller.add(hasUnread);
    } catch (_) {
      if (!controller.isClosed) controller.add(false);
    }
  }

  check();

  final channel = Supabase.instance.client
      .channel('unread_badge_$myId')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'conversations',
        callback: (payload) {
          final row = payload.newRecord;
          final u1 = row['user1_id'] as String?;
          final u2 = row['user2_id'] as String?;
          // 내가 포함된 대화방 변경만 처리
          if (u1 != myId && u2 != myId) return;
          check();
        },
      )
      .subscribe();

  ref.onDispose(() {
    controller.close();
    Supabase.instance.client.removeChannel(channel);
  });

  return controller.stream;
}
