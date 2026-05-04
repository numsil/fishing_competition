import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'dm_repository.g.dart';

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
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class DmRepository {
  final SupabaseClient _supabase;

  DmRepository(this._supabase);

  String? get _myId => _supabase.auth.currentUser?.id;

  Future<List<DmConversation>> getConversations() async {
    final myId = _myId;
    if (myId == null) return [];

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

      // 숨김 처리된 대화방 필터링
      final hiddenAtStr = isUser1
          ? row['user1_hidden_at'] as String?
          : row['user2_hidden_at'] as String?;
      final lastMessageAt = DateTime.parse(row['last_message_at'] as String);
      if (hiddenAtStr != null) {
        final hiddenAt = DateTime.parse(hiddenAtStr);
        if (!lastMessageAt.isAfter(hiddenAt)) continue;
      }

      final otherUserId =
          isUser1 ? row['user2_id'] as String : row['user1_id'] as String;
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
  /// user1_id < user2_id 순으로 항상 정렬해서 저장
  Future<String> getOrCreateConversation(String otherUserId) async {
    final myId = _myId;
    if (myId == null) throw Exception('로그인이 필요합니다');

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

  Stream<List<DmMessage>> streamMessages(String conversationId) {
    // 주의: Supabase stream의 .order() 기본값은 ascending: false (DESC)
    // 오래된 메시지가 위, 최신 메시지가 아래에 오도록 ASC 명시
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((data) => data.map(DmMessage.fromJson).toList());
  }

  Future<void> sendMessage(String conversationId, String content) async {
    final myId = _myId;
    if (myId == null) throw Exception('로그인이 필요합니다');

    await _supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': myId,
      'content': content,
    });

    await _supabase.rpc('on_dm_sent', params: {
      'p_conv_id': conversationId,
      'p_sender_id': myId,
      'p_content': content,
    });
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

@riverpod
Future<List<DmConversation>> dmConversations(DmConversationsRef ref) {
  return ref.watch(dmRepositoryProvider).getConversations();
}

@riverpod
Stream<List<DmMessage>> dmMessages(DmMessagesRef ref, String conversationId) {
  return ref.watch(dmRepositoryProvider).streamMessages(conversationId);
}
