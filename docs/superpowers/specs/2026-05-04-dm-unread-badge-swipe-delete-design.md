# DM 미읽음 배지 + 스와이프 삭제 설계

Date: 2026-05-04

## 개요

두 가지 기능을 추가한다.
1. 피드 AppBar DM 아이콘 + DM 목록 각 대화방에 읽지 않은 메시지가 있을 때 빨간/파란 점 표시
2. DM 목록에서 대화방 왼쪽으로 스와이드해서 나만 숨김 처리 (상대방 새 메시지 수신 시 자동 복원)

---

## DB 변경 (Supabase migration)

`conversations` 테이블에 컬럼 4개 추가.

```sql
alter table conversations
  add column unread_count_user1 int not null default 0,
  add column unread_count_user2 int not null default 0,
  add column user1_hidden_at    timestamptz,
  add column user2_hidden_at    timestamptz;
```

### 읽지 않은 메시지 카운트 규칙
- `sendMessage()` 호출 시: 수신자의 `unread_count_userX`를 +1
- `markAsRead()` 호출 시: 내 `unread_count_userX`를 0으로 리셋, 해당 대화 메시지 `is_read = true`

### 나만 숨김 규칙
- `hideConversation()` 호출 시: 내 `userX_hidden_at` = now()
- `getConversations()` 필터: `userX_hidden_at IS NULL OR last_message_at > userX_hidden_at`
- `sendMessage()` 호출 시: 수신자의 `userX_hidden_at` = NULL (새 메시지 오면 다시 표시)

---

## DmConversation 모델 변경

```dart
class DmConversation {
  // 기존 필드 유지
  final bool hasUnread;  // 추가
}
```

`getConversations()` 쿼리에서 `unread_count_user1`, `unread_count_user2` 포함해서 select,
내가 user1이면 `unread_count_user1 > 0`, user2면 `unread_count_user2 > 0` → `hasUnread`

---

## 새 Repository 메서드

### `hideConversation(String conversationId)`
- conversations에서 내가 user1인지 user2인지 판별
- 해당 hidden_at 컬럼을 now()로 UPDATE
- invalidate dmConversationsProvider

### `sendMessage()` 변경
- 기존 로직 유지
- 수신자 unread_count +1 (user1이면 unread_count_user1, user2면 unread_count_user2)
- 수신자 hidden_at = NULL (숨김 해제)

### `markAsRead()` 변경
- 기존 is_read = true 로직 유지
- 내 unread_count = 0으로 UPDATE

---

## 새 Provider

### `hasUnreadDmsProvider` → `Stream<bool>`
- `conversations` 테이블을 Supabase stream으로 감시
- user1_id = myId OR user2_id = myId 인 대화방 중 내 unread_count > 0인 게 있으면 true
- OR 필터는 stream API에서 미지원이므로 Future 기반 `AsyncValue<bool>`로 구현 후
  Supabase realtime channel로 `messages` INSERT 이벤트 수신 시 invalidate

구현 방식:
```
FutureProvider<bool> hasUnreadDmsProvider
  → conversations 쿼리, myId의 unread_count > 0 여부 반환

+ dmRepository.subscribeUnread() 로 Supabase realtime channel 구독
  → messages INSERT 이벤트 발생 시 ref.invalidate(hasUnreadDmsProvider)
```

---

## UI 변경

### 피드 AppBar DM 아이콘 (`feed_screen.dart`)

`IconButton` → `Consumer` 로 감싸고 `hasUnreadDmsProvider` watch.

```dart
Consumer(builder: (context, ref, _) {
  final hasUnread = ref.watch(hasUnreadDmsProvider).valueOrNull ?? false;
  return Stack(children: [
    IconButton(icon: Icon(LucideIcons.send), onPressed: ...),
    if (hasUnread)
      Positioned(
        right: 8, top: 8,
        child: Container(width: 8, height: 8,
          decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
      ),
  ]);
})
```

### DM 목록 아이템 (`dm_list_screen.dart`)

각 대화방 아이템에 `hasUnread` 표시:
- 아바타 오른쪽 하단에 파란 점 오버레이 (Stack)
- 상대방 이름을 bold → 이미 bold이므로 점으로만 구분

스와이프 삭제:
- `ListView.separated` 의 `itemBuilder` 에서 각 아이템을 `Dismissible` 로 감쌈
- `direction: DismissDirection.endToStart` (오른쪽 → 왼쪽)
- background: 빨간 배경 + 휴지통 아이콘
- `onDismissed`: `dmRepository.hideConversation(conv.id)` 호출
- `confirmDismiss`: 스와이프 임계값 넘으면 바로 삭제 (confirm 다이얼로그 없음)

---

## 파일 변경 목록

| 파일 | 변경 내용 |
|------|-----------|
| `supabase/seeds/` 또는 migration SQL | DB 컬럼 추가 |
| `lib/features/dm/data/dm_repository.dart` | 모델 필드 추가, 메서드 추가/수정, provider 추가 |
| `lib/features/dm/data/dm_repository.g.dart` | 재생성 (build_runner) |
| `lib/features/feed/presentation/screens/feed_screen.dart` | DM 아이콘에 배지 추가 |
| `lib/features/dm/presentation/screens/dm_list_screen.dart` | 아이템 배지 + Dismissible |

---

## 변경하지 않는 것

- DM 채팅 화면 (`dm_chat_screen.dart`) — 기존 그대로
- 라우터, 앱 전체 구조 — 변경 없음
- 다른 피처 — 변경 없음
