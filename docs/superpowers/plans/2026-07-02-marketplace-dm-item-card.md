# 중고거래 문의 → DM 매물 카드 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 중고거래 "문의하기"로 DM을 시작할 때, 어떤 매물에 대한 문의인지 알려주는 매물 카드를 채팅에 남긴다.

**Architecture:** 기존 리그 초대 링크 파싱 패턴을 재사용한다. 메시지 본문에 `https://nakstar.app/market/<itemId>` 마커를 심고, 채팅 버블 렌더러가 이를 감지해 가로 매물 카드(썸네일+제목+가격+상태)로 렌더한다. DB 스키마 변경은 없다. 문의 시작 시 입력창 위에 매물 미리보기 바를 띄우고, 구매자가 첫 전송을 하면 카드 메시지를 보낸다(텍스트 없이 카드 단독 전송 허용).

**Tech Stack:** Flutter, Riverpod(riverpod_annotation 코드젠), Supabase, go_router.

## Global Constraints

- 아키텍처: UI → Provider → Repository → Supabase. UI/Provider에서 직접 쿼리 금지, 모든 데이터 접근은 Repository 경유.
- Supabase: `select('*')` 금지, 필요한 컬럼만 명시. 반복문 안 쿼리 금지(N+1).
- 색상은 `AppColors` 사용(단, 이 기능은 기존 `dm_chat_screen.dart`가 인라인 `Color(0xFF...)`를 쓰는 화면 전용 코드라 해당 파일의 기존 관례를 따른다).
- 이 코드베이스에는 테스트 하네스가 없다. 각 태스크 검증 게이트 = `flutter analyze`(변경 파일에 신규 error/warning 0). 최종 태스크에서 실기기 수동 end-to-end 검증.
- 매물 id는 uuid(36자). 마커 정규식은 `https:\/\/nakstar\.app\/market\/([0-9a-fA-F-]{36})`.
- 기존 기능 절대 유지. 최소 범위 수정. 기존 `sendMessage`/리그 파싱 로직은 건드리지 않고 병렬 추가.

---

### Task 1: 단일 매물 조회 Repository 메서드 + Provider

**Files:**
- Modify: `lib/features/marketplace/data/marketplace_repository.dart` (getItem 메서드 추가 위치: 클래스 내 `deleteItem` 뒤 ~line 259; provider 추가 위치: `marketplaceRepository` provider 뒤 ~line 265)
- Generated: `lib/features/marketplace/data/marketplace_repository.g.dart` (build_runner 자동 갱신)

**Interfaces:**
- Produces:
  - `MarketplaceRepository.getItem(String itemId) → Future<MarketplaceItem?>` — 삭제/미존재 시 `null`, 존재 시 join된 username/avatarUrl 포함 `MarketplaceItem`.
  - `marketplaceItemProvider(String itemId) → FutureProvider<MarketplaceItem?>` (코드젠 생성). Task 3에서 카드 렌더에 사용.

- [ ] **Step 1: `getItem` 메서드 추가**

`marketplace_repository.dart`의 `deleteItem` 메서드 닫는 `}` (line 259) 바로 뒤, 클래스 닫는 `}`(line 260) 앞에 추가:

```dart
  /// 단일 매물 조회 (DM 매물 카드 렌더·상세 진입용). 삭제/미존재 시 null.
  /// getItems와 동일한 컬럼·join 형태를 유지해 카드 탭 시 상세 화면에 그대로 전달 가능.
  Future<MarketplaceItem?> getItem(String itemId) async {
    final data = await _supabase
        .from('marketplace_items')
        .select('id, user_id, title, description, price, image_urls, category, status, trade_type, location, created_at, bumped_at, users(username, avatar_url)')
        .eq('id', itemId)
        .eq('is_deleted', false)
        .maybeSingle();
    if (data == null) return null;
    final item = MarketplaceItem.fromJson(data);
    final u = data['users'];
    return item.copyWith(
      username: (u is Map ? u['username'] : null) ?? 'Unknown',
      userKey: (u is Map ? u['user_key'] : null) ?? '',
      avatarUrl: (u is Map ? u['avatar_url'] : null) ?? '',
    );
  }
```

- [ ] **Step 2: `marketplaceItem` provider 추가**

`marketplaceRepository` provider (line 262-265) 바로 뒤에 추가:

```dart
/// 매물 id별 단일 조회. 카드가 여러 개여도 id 단위로 캐싱되어 재사용(N+1 아님).
/// autoDispose(기본): 채팅방을 벗어나면 해제되어 다음 진입 시 최신 상태(가격/상태/삭제) 반영.
@riverpod
Future<MarketplaceItem?> marketplaceItem(
    MarketplaceItemRef ref, String itemId) {
  return ref.watch(marketplaceRepositoryProvider).getItem(itemId);
}
```

- [ ] **Step 3: 코드젠 실행**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 성공, `marketplace_repository.g.dart`에 `marketplaceItemProvider` 생성됨.

- [ ] **Step 4: 분석**

Run: `flutter analyze lib/features/marketplace/data/marketplace_repository.dart`
Expected: No issues (신규 error/warning 없음).

- [ ] **Step 5: 커밋**

```bash
git add lib/features/marketplace/data/marketplace_repository.dart lib/features/marketplace/data/marketplace_repository.g.dart
git commit -m "feat(marketplace): 단일 매물 조회 getItem + marketplaceItemProvider 추가"
```

---

### Task 2: DM 값 객체(DmPendingItem/DmChatArgs) + 매물 카드 전송

**Files:**
- Modify: `lib/features/dm/data/dm_repository.dart` (값 객체 추가: `DmMessage` 클래스 뒤 ~line 64; 마커 헬퍼 + `sendItemCard` 추가: `sendMessage` 뒤 ~line 260)

**Interfaces:**
- Consumes: 없음(원시 타입만).
- Produces:
  - `class DmPendingItem { String itemId; String title; String priceLabel; String? thumbnailUrl; }` — 표시용 원시값 컨테이너. Task 3(미리보기 바), Task 5(문의하기)에서 사용.
  - `class DmChatArgs { DmConversation conversation; DmPendingItem? pendingItem; }` — 라우트 extra. Task 4(라우터), Task 5에서 사용.
  - `String marketItemLink(String itemId)` — 마커 URL 생성. Task 3 파싱과 쌍.
  - `DmRepository.sendItemCard(String conversationId, {required String itemId, required String title}) → Future<DmMessage>` — content엔 마커 URL, 목록 미리보기엔 `📦 title`. 차단 시 `DmBlockedException`. Task 3 전송에서 사용.

- [ ] **Step 1: 값 객체 추가**

`dm_repository.dart`의 `DmMessage` 클래스 닫는 `}` (line 64) 뒤, `class DmRepository` (line 66) 앞에 추가:

```dart
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
```

- [ ] **Step 2: 마커 헬퍼 + `sendItemCard` 추가**

`dm_repository.dart`의 `sendMessage` 메서드 닫는 `}` (line 260) 뒤, `markAsRead` (line 262) 앞에 추가:

```dart
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
```

그리고 파일 최상단 영역, `class DmBlockedException` (line 11) 앞에 top-level 헬퍼 추가:

```dart
/// 매물 카드 딥링크 마커. 메시지 본문에 심고 채팅 버블에서 카드로 렌더한다.
/// 리그 초대 링크(https://nakstar.app/league/<id>)와 동일 계열 포맷.
String marketItemLink(String itemId) => 'https://nakstar.app/market/$itemId';
```

- [ ] **Step 3: 분석**

Run: `flutter analyze lib/features/dm/data/dm_repository.dart`
Expected: No issues. (`_myId` getter, `AuthRepository`, `DmBlockedException`은 파일 내 기존 정의/임포트 사용.)

- [ ] **Step 4: 커밋**

```bash
git add lib/features/dm/data/dm_repository.dart
git commit -m "feat(dm): 매물 카드 전송(sendItemCard) + DmPendingItem/DmChatArgs 값 객체 추가"
```

---

### Task 3: 채팅방 — 매물 미리보기 바 + 카드 단독 전송 + 매물 카드 렌더

**Files:**
- Modify: `lib/features/dm/presentation/screens/dm_chat_screen.dart`
  - 임포트 추가 (~line 16 이후)
  - `DmChatScreen` 위젯: `pendingItem` 파라미터 추가 (line 17-23)
  - `_DmChatScreenState`: `_pending` 상태 + 미리보기 바 + `_send` 수정 + 전송 버튼 활성 조건 (line 25~326)
  - `_MessageBubble`: market 마커 파싱 + 카드 분기 (line 362~520)
  - 파일 끝: `_MarketItemCard` ConsumerWidget 신규 추가

**Interfaces:**
- Consumes:
  - `DmPendingItem` (Task 2)
  - `DmRepository.sendItemCard(convId, {itemId, title})` (Task 2)
  - `marketplaceItemProvider(itemId)` (Task 1), `MarketplaceItem`, `MarketplaceItemX`(statusLabel/formattedPrice)
- Produces:
  - `DmChatScreen({required DmConversation conversation, DmPendingItem? pendingItem})` — Task 4 라우터에서 사용.

- [ ] **Step 1: 임포트 추가**

`dm_chat_screen.dart` 상단 import 블록(line 8-15 부근)에 추가:

```dart
import '../../../marketplace/data/marketplace_model.dart';
import '../../../marketplace/data/marketplace_repository.dart';
```

- [ ] **Step 2: `DmChatScreen`에 pendingItem 파라미터 추가**

기존 (line 17-23):

```dart
class DmChatScreen extends ConsumerStatefulWidget {
  const DmChatScreen({super.key, required this.conversation});
  final DmConversation conversation;

  @override
  ConsumerState<DmChatScreen> createState() => _DmChatScreenState();
}
```

수정 후:

```dart
class DmChatScreen extends ConsumerStatefulWidget {
  const DmChatScreen({
    super.key,
    required this.conversation,
    this.pendingItem,
  });
  final DmConversation conversation;
  final DmPendingItem? pendingItem;

  @override
  ConsumerState<DmChatScreen> createState() => _DmChatScreenState();
}
```

- [ ] **Step 3: pending 상태 필드 추가**

`_DmChatScreenState` 필드 영역(line 26-34, `_ctrl` 등 옆)에 추가:

```dart
  // 문의하기로 진입 시 전송 대기 중인 매물 카드. 전송하면 null로 해제.
  DmPendingItem? _pending;
```

그리고 `initState`(line 37) 첫 줄 `super.initState();` 바로 뒤에 추가:

```dart
    _pending = widget.pendingItem;
```

- [ ] **Step 4: `_send` 로직을 카드+텍스트 전송으로 수정**

기존 `_send` (line 111-144)를 아래로 교체. 변경점: (a) 전송 가능 조건에 `_pending != null` 포함, (b) pending 있으면 `sendItemCard` 먼저 전송 후 텍스트가 있으면 이어서 전송, (c) 전송 성공 시 `_pending` 해제:

```dart
  Future<void> _send() async {
    final text = _ctrl.text.trim();
    // 텍스트가 있거나, 전송 대기 매물 카드가 있으면 전송 가능(카드 단독 전송 허용).
    if ((text.isEmpty && _pending == null) || _sending) return;

    final pending = _pending;
    setState(() => _sending = true);
    _ctrl.clear();

    try {
      final repo = ref.read(dmRepositoryProvider);

      // 1) 매물 카드 먼저 전송 (카드가 위, 텍스트가 아래에 오도록)
      if (pending != null) {
        final card = await repo.sendItemCard(
          widget.conversation.id,
          itemId: pending.itemId,
          title: pending.title,
        );
        if (mounted) {
          if (!_messages.any((m) => m.id == card.id)) _localSent.add(card);
          setState(() {
            _pending = null;
            _messages = _mergeMessages(_messages, _localSent);
          });
          _scrollToBottom();
        }
      }

      // 2) 텍스트가 있으면 이어서 전송
      if (text.isNotEmpty) {
        final sent = await repo.sendMessage(widget.conversation.id, text);
        if (mounted && !_messages.any((m) => m.id == sent.id)) {
          _localSent.add(sent);
          setState(() {
            _messages = _mergeMessages(_messages, _localSent);
          });
          _scrollToBottom();
        }
      }
    } on DmBlockedException catch (e) {
      if (mounted) {
        AppSnackBar.warning(context, e.toString());
        _ctrl.text = text;
        setState(() => _pending = pending); // 실패 시 미리보기 복구
      }
    } catch (e) {
      if (await handleIfBanned(e)) return;
      if (mounted) {
        AppSnackBar.error(context, '메시지 전송에 실패했습니다');
        _ctrl.text = text;
        setState(() => _pending = pending); // 실패 시 미리보기 복구
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
```

- [ ] **Step 5: 미리보기 바를 입력창 위에 삽입**

`build`의 `body: Column`(line 187-194)에서 입력창 위에 미리보기 바를 넣는다. 기존:

```dart
      body: Column(
        children: [
          Divider(height: 0.5, thickness: 0.5, color: divColor),
          Expanded(child: _buildMessageList(context.isDark, context.accentColor, myId)),
          Divider(height: 0.5, thickness: 0.5, color: divColor),
          _buildInput(context.isDark, context.accentColor, divColor),
        ],
      ),
```

수정 후:

```dart
      body: Column(
        children: [
          Divider(height: 0.5, thickness: 0.5, color: divColor),
          Expanded(child: _buildMessageList(context.isDark, context.accentColor, myId)),
          Divider(height: 0.5, thickness: 0.5, color: divColor),
          if (_pending != null) _buildPendingBar(context.isDark, divColor),
          _buildInput(context.isDark, context.accentColor, divColor),
        ],
      ),
```

- [ ] **Step 6: `_buildPendingBar` 위젯 메서드 추가**

`_buildInput` 메서드(line 248) 앞에 추가:

```dart
  Widget _buildPendingBar(bool isDark, Color divColor) {
    final p = _pending!;
    final sub = isDark ? const Color(0xFF999999) : const Color(0xFF888888);
    final thumbBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      color: isDark ? const Color(0xFF141414) : const Color(0xFFFAFAFA),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 40,
              height: 40,
              child: (p.thumbnailUrl != null && p.thumbnailUrl!.isNotEmpty)
                  ? Image.network(
                      p.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: thumbBg,
                        child: const Icon(LucideIcons.image,
                            size: 18, color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: thumbBg,
                      child: const Icon(LucideIcons.image,
                          size: 18, color: Colors.grey),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.priceLabel,
                  style: TextStyle(fontSize: 12, color: sub),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.x, size: 18, color: sub),
            onPressed: () => setState(() => _pending = null),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 7: 전송 버튼 활성 조건에 pending 반영**

`_buildInput`의 `ValueListenableBuilder`(line 292-321) 내부 `hasText` 판정을 pending까지 고려하도록 수정. 기존:

```dart
              builder: (_, val, __) {
                final hasText = val.text.trim().isNotEmpty;
                return GestureDetector(
                  onTap: hasText && !_sending ? _send : null,
```

수정 후 (`canSend`로 판정, 버튼 색/아이콘도 `canSend` 기준):

```dart
              builder: (_, val, __) {
                final canSend =
                    val.text.trim().isNotEmpty || _pending != null;
                return GestureDetector(
                  onTap: canSend && !_sending ? _send : null,
```

그리고 같은 builder 내부의 나머지 `hasText`를 모두 `canSend`로 교체:
- `color: hasText ? accent : (...)` → `color: canSend ? accent : (...)`
- `color: hasText ? (isDark ? Colors.black : Colors.white) : (...)` → `color: canSend ? (isDark ? Colors.black : Colors.white) : (...)`

> 주의: `ValueListenableBuilder`는 `_ctrl` 변경만 구독하므로, `_pending` 해제(X 탭·전송) 시 버튼 갱신은 `setState`가 전체 `build`를 다시 돌려 반영된다(별도 처리 불필요).

- [ ] **Step 8: `_MessageBubble`에 market 마커 정규식 추가**

`_MessageBubble`의 `_leagueLinkRe`(line 381-383) 바로 뒤에 추가:

```dart
  // 매물 카드 마커: https://nakstar.app/market/<uuid>
  static final _marketLinkRe = RegExp(
    r'https:\/\/nakstar\.app\/market\/([0-9a-fA-F-]{36})',
  );
```

- [ ] **Step 9: `_MessageBubble.build`에 매물 카드 분기 추가**

`build` 메서드(line 393) 시작부, `final timeStr = ...`(line 395-396) 계산 직후에 매물 카드 분기를 넣는다. market 마커가 있으면 accent 버블 대신 매물 카드를 렌더하고 조기 반환한다:

```dart
    final marketId = _marketLinkRe.firstMatch(msg.content)?.group(1);
    if (marketId != null) {
      final subColor =
          isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) const SizedBox(width: 38), // 아바타 폭만큼 들여쓰기 정렬
            if (isMe) ...[
              Text(timeStr, style: TextStyle(fontSize: 10, color: subColor)),
              const SizedBox(width: 4),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.68,
              ),
              child: _MarketItemCard(itemId: marketId, isDark: isDark),
            ),
            if (!isMe) ...[
              const SizedBox(width: 4),
              Text(timeStr, style: TextStyle(fontSize: 10, color: subColor)),
            ],
          ],
        ),
      );
    }
```

> 이 분기는 기존 텍스트/리그 버블 렌더(line 397 이후)를 전혀 건드리지 않고 앞에서 조기 반환한다.

- [ ] **Step 10: `_MarketItemCard` 위젯 추가**

파일 맨 끝(`_DateDivider` 클래스 뒤, line 521 이후)에 추가:

```dart
/// 채팅 버블용 매물 카드. marketplaceItemProvider로 현재 매물 상태를 실시간 조회한다.
/// 로딩/삭제(null)/정상 3상태. 탭 시 매물 상세로 이동(삭제 시 안내).
class _MarketItemCard extends ConsumerWidget {
  const _MarketItemCard({required this.itemId, required this.isDark});
  final String itemId;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketplaceItemProvider(itemId));
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
    final sub = isDark ? const Color(0xFF999999) : const Color(0xFF888888);
    final thumbBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);

    Widget shell({required Widget child, VoidCallback? onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: child,
        ),
      );
    }

    return async.when(
      loading: () => shell(
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: thumbBg,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 10),
              Text('매물 불러오는 중…',
                  style: TextStyle(fontSize: 13, color: sub)),
            ],
          ),
        ),
      ),
      error: (_, __) => shell(
        child: _deletedRow(sub, thumbBg),
        onTap: null,
      ),
      data: (item) {
        if (item == null) {
          return shell(child: _deletedRow(sub, thumbBg), onTap: () {
            AppSnackBar.info(context, '삭제된 매물이에요');
          });
        }
        return shell(
          onTap: () => context.push('/marketplace/${item.id}', extra: item),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: item.imageUrls.isNotEmpty
                      ? Image.network(
                          item.imageUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: thumbBg,
                            child: const Icon(LucideIcons.image,
                                size: 20, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: thumbBg,
                          child: const Icon(LucideIcons.image,
                              size: 20, color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: sub,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.formattedPrice,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 16, color: sub),
            ],
          ),
        );
      },
    );
  }

  Widget _deletedRow(Color sub, Color thumbBg) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: thumbBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LucideIcons.imageOff, size: 20, color: sub),
          ),
          const SizedBox(width: 10),
          Text('삭제된 매물',
              style: TextStyle(fontSize: 13, color: sub)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 11: 분석**

Run: `flutter analyze lib/features/dm/presentation/screens/dm_chat_screen.dart`
Expected: No issues. (`ref`는 `_MarketItemCard`가 `ConsumerWidget`이라 `build`에서 제공됨. `context.push`는 go_router 임포트 기존 존재.)

- [ ] **Step 12: 커밋**

```bash
git add lib/features/dm/presentation/screens/dm_chat_screen.dart
git commit -m "feat(dm): 채팅방 매물 미리보기 바 + 카드 단독 전송 + 매물 카드 렌더"
```

---

### Task 4: 라우터 — /dm/chat extra에 DmChatArgs 지원

**Files:**
- Modify: `lib/core/router/app_router.dart` (dmChat 라우트 builder, line 179-185)

**Interfaces:**
- Consumes: `DmChatArgs`, `DmConversation` (dm_repository), `DmChatScreen({conversation, pendingItem})` (Task 3).
- Produces: 없음.

- [ ] **Step 1: dmChat 라우트 builder를 DmChatArgs 겸용으로 수정**

기존 (line 179-185):

```dart
      GoRoute(
        path: AppRoutes.dmChat,
        pageBuilder: (context, state) {
          final conv = state.extra as DmConversation;
          return MaterialPage(child: DmChatScreen(conversation: conv));
        },
      ),
```

수정 후 (하위 호환: 기존 3개 진입점은 `DmConversation`을 그대로 넘김):

```dart
      GoRoute(
        path: AppRoutes.dmChat,
        pageBuilder: (context, state) {
          final extra = state.extra;
          if (extra is DmChatArgs) {
            return MaterialPage(
              child: DmChatScreen(
                conversation: extra.conversation,
                pendingItem: extra.pendingItem,
              ),
            );
          }
          final conv = extra as DmConversation;
          return MaterialPage(child: DmChatScreen(conversation: conv));
        },
      ),
```

> `DmChatArgs`/`DmConversation`은 이미 import된 `dm_repository.dart`에서 제공된다(라우터가 기존에 `DmConversation`을 참조하므로 import 존재). 확인만 하고 없으면 추가.

- [ ] **Step 2: 분석**

Run: `flutter analyze lib/core/router/app_router.dart`
Expected: No issues.

- [ ] **Step 3: 커밋**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat(router): /dm/chat extra에 DmChatArgs(문의 매물) 지원"
```

---

### Task 5: 문의하기 → 매물 전달 + 실기기 end-to-end 검증

**Files:**
- Modify: `lib/features/marketplace/presentation/screens/marketplace_detail_screen.dart` (문의하기 onPressed, line 300-333)

**Interfaces:**
- Consumes: `DmChatArgs`, `DmPendingItem`, `DmConversation` (dm_repository), `getOrCreateConversation` (기존).
- Produces: 없음(최종 소비자).

- [ ] **Step 1: 문의하기 push에 매물 정보(DmChatArgs) 전달**

`marketplace_detail_screen.dart`의 문의하기 `onPressed` 내부(line 305-320 부근), `context.push('/dm/chat', extra: DmConversation(...))` 부분을 `DmChatArgs`로 감싸 매물 미리보기를 전달한다. 기존:

```dart
          final conversationId = await ref
              .read(dmRepositoryProvider)
              .getOrCreateConversation(item.userId);
          if (context.mounted) {
            context.push(
              '/dm/chat',
              extra: DmConversation(
                id: conversationId,
                otherUserId: item.userId,
                otherUsername: item.username,
                otherAvatarUrl: item.avatarUrl,
                lastMessageAt: DateTime.now(),
                hasUnread: false,
              ),
            );
          }
```

수정 후:

```dart
          final conversationId = await ref
              .read(dmRepositoryProvider)
              .getOrCreateConversation(item.userId);
          if (context.mounted) {
            context.push(
              '/dm/chat',
              extra: DmChatArgs(
                conversation: DmConversation(
                  id: conversationId,
                  otherUserId: item.userId,
                  otherUsername: item.username,
                  otherAvatarUrl: item.avatarUrl,
                  lastMessageAt: DateTime.now(),
                  hasUnread: false,
                ),
                pendingItem: DmPendingItem(
                  itemId: item.id,
                  title: item.title,
                  priceLabel: item.formattedPrice,
                  thumbnailUrl:
                      item.imageUrls.isNotEmpty ? item.imageUrls.first : null,
                ),
              ),
            );
          }
```

> `DmChatArgs`/`DmPendingItem`은 이미 import된 `dm_repository.dart`(line 15)에서 제공된다. `formattedPrice`는 `MarketplaceItemX` 확장(같은 파일 marketplace_model)으로 제공되며 상세 화면에서 이미 사용 중.

- [ ] **Step 2: 분석**

Run: `flutter analyze lib/features/marketplace/presentation/screens/marketplace_detail_screen.dart`
Expected: No issues.

- [ ] **Step 3: 전체 분석**

Run: `flutter analyze`
Expected: 이 기능으로 인한 신규 error/warning 없음.

- [ ] **Step 4: 실기기 수동 end-to-end 검증**

앱을 실행(`flutter run`)하고 두 계정(구매자/판매자)으로 확인:

1. 구매자: 매물 상세 → "문의하기" 탭 → 채팅방 진입 시 **입력창 위에 매물 미리보기 바**(썸네일+제목+가격+X) 노출.
2. 미리보기 X 탭 → 미리보기 사라지고 전송 버튼 비활성(텍스트 없을 때).
3. 다시 문의하기로 진입 → 텍스트 없이 전송 버튼 탭 → **매물 카드만 전송**됨. 카드에 썸네일/상태/제목/가격 표시.
4. 문의하기 진입 → 텍스트 입력 후 전송 → **카드(위) + 텍스트(아래)** 순서로 전송.
5. 판매자 계정: 해당 대화방에서 **어떤 매물 문의인지 카드로 식별** 가능.
6. 서로 다른 매물 2건으로 문의 → 같은 방에 **카드 2개가 구분**되어 쌓임.
7. 카드 탭 → 해당 매물 상세로 이동.
8. 판매자가 매물 상태를 예약중/판매완료로 변경 후, 채팅방 재진입 → 카드 상태 배지 갱신 반영.
9. 매물 삭제 후 채팅방 재진입 → 카드가 **"삭제된 매물"**로 표시, 탭 시 안내.
10. 대화 목록(DmListScreen)에서 카드가 마지막 메시지인 대화의 미리보기가 **`📦 제목`**으로 표시(raw URL 아님).
11. 차단한 사용자에게 문의하기 → 카드 전송이 막히고 "차단" 안내.

- [ ] **Step 5: 커밋**

```bash
git add lib/features/marketplace/presentation/screens/marketplace_detail_screen.dart
git commit -m "feat(marketplace): 문의하기 시 매물 카드 미리보기 전달(DmChatArgs)"
```

---

## Self-Review (작성자 체크 완료)

**Spec coverage:**
- 리그 패턴 재사용/마커 → Task 2(marketItemLink), Task 3(파싱·렌더). ✅
- 문의하기 매물 전달 → Task 5. ✅
- 미리보기 바(전송 전 대기) → Task 3 Step 5-6. ✅
- 카드 단독 전송 허용 → Task 3 Step 4,7. ✅
- 카드 실시간 상태/탭 상세 이동/삭제 처리 → Task 1(provider) + Task 3 Step 10. ✅
- 목록 미리보기 친화 텍스트(📦) → Task 2 Step 2. ✅
- 차단 체크 → Task 2 Step 2. ✅
- DB 스키마 변경 없음 → 마이그레이션 태스크 없음. ✅
- 하위 호환(기존 3개 dmChat 진입점) → Task 4 겸용 builder. ✅

**Placeholder scan:** "TODO/TBD/적절히 처리" 없음. 모든 코드 스텝에 실제 코드 포함. ✅

**Type consistency:** `DmPendingItem`/`DmChatArgs`/`marketItemLink`/`sendItemCard`/`marketplaceItemProvider`/`getItem` 시그니처가 Task 1-5 전반에서 일치. `_marketLinkRe` 캡처 그룹 = itemId, `marketItemLink`가 생성하는 URL과 정규식이 쌍으로 일치. ✅
