# DM 미읽음 배지 + 스와이프 삭제 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 피드 AppBar DM 아이콘에 미읽음 빨간 점 표시, DM 목록 각 대화방에 미읽음 파란 점 표시, 대화방 좌 스와이프 삭제(나만 숨김)

**Architecture:** `conversations` 테이블에 `unread_count_user1/2`, `user1/2_hidden_at` 컬럼 추가. 세 개의 Supabase RPC 함수로 원자적 업데이트. `hasUnreadDmsProvider` (StreamProvider) 가 Realtime subscription으로 전역 배지 상태 관리.

**Tech Stack:** Flutter, Riverpod (riverpod_annotation), Supabase (REST + Realtime channels), Dart StreamController

---

## File Map

| 파일 | 변경 유형 | 역할 |
|------|-----------|------|
| `supabase/migration_dm_unread_swipe.sql` | 신규 | DB 컬럼 + RPC 함수 |
| `lib/features/dm/data/dm_repository.dart` | 수정 | 모델·메서드·provider |
| `lib/features/dm/data/dm_repository.g.dart` | 재생성 | build_runner |
| `lib/features/feed/presentation/screens/feed_screen.dart` | 수정 | DM 아이콘 배지 |
| `lib/features/dm/presentation/screens/dm_list_screen.dart` | 수정 | 항목 배지 + Dismissible |

---

## Task 1: DB 마이그레이션 SQL 작성 및 적용

**Files:**
- Create: `supabase/migration_dm_unread_swipe.sql`

- [ ] **Step 1: SQL 파일 작성**

```sql
-- conversations 테이블 컬럼 추가
ALTER TABLE conversations
  ADD COLUMN IF NOT EXISTS unread_count_user1 INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS unread_count_user2 INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS user1_hidden_at    TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS user2_hidden_at    TIMESTAMPTZ;

-- 메시지 전송 시 수신자 unread +1, 수신자 hidden_at 초기화
CREATE OR REPLACE FUNCTION on_dm_sent(
  p_conv_id  UUID,
  p_sender_id UUID,
  p_content  TEXT
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE conversations SET
    last_message        = p_content,
    last_message_at     = NOW(),
    unread_count_user1  = CASE WHEN user2_id = p_sender_id THEN unread_count_user1 + 1 ELSE unread_count_user1 END,
    unread_count_user2  = CASE WHEN user1_id = p_sender_id THEN unread_count_user2 + 1 ELSE unread_count_user2 END,
    user1_hidden_at     = CASE WHEN user2_id = p_sender_id THEN NULL ELSE user1_hidden_at END,
    user2_hidden_at     = CASE WHEN user1_id = p_sender_id THEN NULL ELSE user2_hidden_at END
  WHERE id = p_conv_id;
END;
$$;

-- 읽음 처리 시 내 unread_count 0으로 리셋
CREATE OR REPLACE FUNCTION on_dm_read(
  p_conv_id  UUID,
  p_reader_id UUID
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE conversations SET
    unread_count_user1 = CASE WHEN user1_id = p_reader_id THEN 0 ELSE unread_count_user1 END,
    unread_count_user2 = CASE WHEN user2_id = p_reader_id THEN 0 ELSE unread_count_user2 END
  WHERE id = p_conv_id;
END;
$$;

-- 대화방 나만 숨김
CREATE OR REPLACE FUNCTION hide_conversation(
  p_conv_id UUID,
  p_user_id UUID
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE conversations SET
    user1_hidden_at = CASE WHEN user1_id = p_user_id THEN NOW() ELSE user1_hidden_at END,
    user2_hidden_at = CASE WHEN user2_id = p_user_id THEN NOW() ELSE user2_hidden_at END
  WHERE id = p_conv_id;
END;
$$;
```

- [ ] **Step 2: Supabase Dashboard에서 SQL 실행**

  Supabase Dashboard → SQL Editor → 위 SQL 전체 붙여넣기 → Run

  성공 확인: `conversations` 테이블에 `unread_count_user1`, `unread_count_user2`, `user1_hidden_at`, `user2_hidden_at` 컬럼 생성됨

- [ ] **Step 3: Commit**

```bash
git add supabase/migration_dm_unread_swipe.sql
git commit -m "feat: DM unread count + hidden_at 컬럼 및 RPC 함수 추가"
```

---

## Task 2: DmConversation 모델 + getConversations() 업데이트

**Files:**
- Modify: `lib/features/dm/data/dm_repository.dart`

- [ ] **Step 1: DmConversation 모델에 hasUnread 필드 추가**

`dm_repository.dart` 의 `DmConversation` 클래스를 아래로 교체:

```dart
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
```

- [ ] **Step 2: getConversations() 업데이트**

기존 `getConversations()` 메서드 전체를 아래로 교체:

```dart
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
```

- [ ] **Step 3: 앱 빌드 확인 (컴파일 에러 없는지)**

```bash
flutter analyze lib/features/dm/data/dm_repository.dart
```

Expected: 에러 없음 (hasUnread 필드 미사용 warning은 무시)

- [ ] **Step 4: Commit**

```bash
git add lib/features/dm/data/dm_repository.dart
git commit -m "feat: DmConversation hasUnread 필드 추가, getConversations 숨김 필터 적용"
```

---

## Task 3: sendMessage() + markAsRead() RPC로 전환

**Files:**
- Modify: `lib/features/dm/data/dm_repository.dart`

- [ ] **Step 1: sendMessage() 교체**

기존 `sendMessage()` 전체를 아래로 교체:

```dart
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
```

- [ ] **Step 2: markAsRead() 교체**

기존 `markAsRead()` 전체를 아래로 교체:

```dart
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
```

- [ ] **Step 3: hideConversation() 추가**

`markAsRead()` 메서드 아래에 새 메서드 추가:

```dart
Future<void> hideConversation(String conversationId) async {
  final myId = _myId;
  if (myId == null) return;

  await _supabase.rpc('hide_conversation', params: {
    'p_conv_id': conversationId,
    'p_user_id': myId,
  });
}
```

- [ ] **Step 4: 빌드 확인**

```bash
flutter analyze lib/features/dm/data/dm_repository.dart
```

Expected: 에러 없음

- [ ] **Step 5: Commit**

```bash
git add lib/features/dm/data/dm_repository.dart
git commit -m "feat: sendMessage/markAsRead RPC 전환, hideConversation 추가"
```

---

## Task 4: hasUnreadDmsProvider 추가 + build_runner 재생성

**Files:**
- Modify: `lib/features/dm/data/dm_repository.dart`
- Regenerate: `lib/features/dm/data/dm_repository.g.dart`

- [ ] **Step 1: hasUnreadDmsProvider 추가**

`dm_repository.dart` 맨 아래 `@riverpod dmMessages` provider 블록 아래에 추가:

```dart
@riverpod
Stream<bool> hasUnreadDms(HasUnreadDmsRef ref) {
  final myId = Supabase.instance.client.auth.currentUser?.id;
  if (myId == null) return Stream.value(false);

  final controller = StreamController<bool>.broadcast();

  Future<void> check() async {
    try {
      final supabase = Supabase.instance.client;
      final user1 = await supabase
          .from('conversations')
          .select('id')
          .eq('user1_id', myId)
          .gt('unread_count_user1', 0)
          .limit(1);
      if ((user1 as List).isNotEmpty) {
        if (!controller.isClosed) controller.add(true);
        return;
      }
      final user2 = await supabase
          .from('conversations')
          .select('id')
          .eq('user2_id', myId)
          .gt('unread_count_user2', 0)
          .limit(1);
      if (!controller.isClosed) controller.add((user2 as List).isNotEmpty);
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
        callback: (payload) => check(),
      )
      .subscribe();

  ref.onDispose(() {
    controller.close();
    Supabase.instance.client.removeChannel(channel);
  });

  return controller.stream;
}
```

- [ ] **Step 2: import 추가 확인**

`dm_repository.dart` 상단에 `dart:async` import가 없으면 추가:

```dart
import 'dart:async';
```

- [ ] **Step 3: build_runner 실행**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `dm_repository.g.dart` 에 `hasUnreadDmsProvider` 추가됨, 에러 없음

- [ ] **Step 4: 빌드 확인**

```bash
flutter analyze lib/features/dm/
```

Expected: 에러 없음

- [ ] **Step 5: Commit**

```bash
git add lib/features/dm/data/dm_repository.dart lib/features/dm/data/dm_repository.g.dart
git commit -m "feat: hasUnreadDmsProvider 추가 (Realtime 기반 전역 미읽음 감지)"
```

---

## Task 5: 피드 AppBar DM 아이콘 배지

**Files:**
- Modify: `lib/features/feed/presentation/screens/feed_screen.dart`

- [ ] **Step 1: import 추가 확인**

`feed_screen.dart` 상단에 dm_repository import가 없으면 추가:

```dart
import '../../../dm/data/dm_repository.dart';
```

- [ ] **Step 2: `_FeedAppBar` 의 DM IconButton을 Consumer로 교체**

`feed_screen.dart` 295~300라인의 아래 코드를:

```dart
IconButton(
  onPressed: () => context.push(AppRoutes.dm),
  icon: Icon(LucideIcons.send,
      color: isDark ? Colors.white : Colors.black, size: 22),
  visualDensity: VisualDensity.compact,
),
```

아래 코드로 교체:

```dart
Consumer(
  builder: (context, ref, _) {
    final hasUnread =
        ref.watch(hasUnreadDmsProvider).valueOrNull ?? false;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => context.push(AppRoutes.dm),
          icon: Icon(LucideIcons.send,
              color: isDark ? Colors.white : Colors.black, size: 22),
          visualDensity: VisualDensity.compact,
        ),
        if (hasUnread)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  },
),
```

- [ ] **Step 3: 빌드 확인**

```bash
flutter analyze lib/features/feed/presentation/screens/feed_screen.dart
```

Expected: 에러 없음

- [ ] **Step 4: Commit**

```bash
git add lib/features/feed/presentation/screens/feed_screen.dart
git commit -m "feat: 피드 AppBar DM 아이콘 미읽음 빨간 점 배지 추가"
```

---

## Task 6: DM 목록 — 항목 미읽음 파란 점 + Dismissible 삭제

**Files:**
- Modify: `lib/features/dm/presentation/screens/dm_list_screen.dart`

- [ ] **Step 1: ListView.separated → ListView.builder + Dismissible로 교체**

`dm_list_screen.dart` 의 `RefreshIndicator` child 전체를 아래로 교체:

```dart
return RefreshIndicator(
  onRefresh: () async => ref.invalidate(dmConversationsProvider),
  child: ListView.builder(
    itemCount: conversations.length,
    itemBuilder: (context, i) {
      final conv = conversations[i];
      final dividerColor = context.isDark
          ? const Color(0xFF222222)
          : const Color(0xFFEEEEEE);
      final sub = context.isDark
          ? const Color(0xFF8E8E8E)
          : const Color(0xFF737373);

      return Dismissible(
        key: ValueKey(conv.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.red,
          child: const Icon(Icons.delete_outline,
              color: Colors.white, size: 24),
        ),
        onDismissed: (_) {
          ref.read(dmRepositoryProvider).hideConversation(conv.id);
          ref.invalidate(dmConversationsProvider);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => context.push(AppRoutes.dmChat, extra: conv),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        UserAvatar(
                          username: conv.otherUsername,
                          avatarUrl: conv.otherAvatarUrl,
                          radius: 26,
                          isDark: context.isDark,
                        ),
                        if (conv.hasUnread)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0084FF),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.isDark
                                      ? AppColors.darkBg
                                      : Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            conv.otherUsername,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            conv.lastMessage ?? '대화를 시작해보세요',
                            style: TextStyle(
                              fontSize: 13,
                              color: conv.lastMessage != null
                                  ? (context.isDark
                                      ? const Color(0xFFAAAAAA)
                                      : const Color(0xFF888888))
                                  : sub,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(conv.lastMessageAt),
                      style: TextStyle(fontSize: 11, color: sub),
                    ),
                  ],
                ),
              ),
            ),
            if (i < conversations.length - 1)
              Divider(
                height: 0.5,
                thickness: 0.5,
                indent: 76,
                color: dividerColor,
              ),
          ],
        ),
      );
    },
  ),
);
```

- [ ] **Step 2: 빌드 확인**

```bash
flutter analyze lib/features/dm/presentation/screens/dm_list_screen.dart
```

Expected: 에러 없음

- [ ] **Step 3: Commit**

```bash
git add lib/features/dm/presentation/screens/dm_list_screen.dart
git commit -m "feat: DM 목록 미읽음 파란 점 표시 + 스와이프 숨김 삭제"
```

---

## 수동 검증 체크리스트

Task 6 완료 후 앱을 실행해서 확인:

- [ ] 상대방이 DM 보냈을 때 피드 AppBar send 아이콘 오른쪽 상단에 빨간 점 표시
- [ ] DM 목록 진입 후 빨간 점 사라짐 (markAsRead 호출)
- [ ] DM 목록에서 미읽은 대화방 아바타 하단에 파란 점 표시
- [ ] DM 채팅방 진입 → 뒤로가기 → 파란 점 사라짐
- [ ] 대화방 아이템 왼쪽으로 스와이프 → 빨간 배경 + 휴지통 아이콘 표시
- [ ] 스와이프 완료 → 목록에서 항목 사라짐
- [ ] 숨긴 대화방에서 상대방이 새 메시지 보내면 → 목록에 다시 나타남
