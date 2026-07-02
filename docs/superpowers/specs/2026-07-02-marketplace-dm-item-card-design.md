# 중고거래 문의 → DM 매물 카드 설계

작성일: 2026-07-02

## 문제

중고거래 상세 화면의 "문의하기"는 판매자 `user_id` 하나만으로 범용 1:1 대화방을 연다. 같은 판매자에게 어떤 매물로 문의하든 **동일한 대화방**이 재사용되고, `conversations` 테이블·전달 객체(`DmConversation`)·채팅방 UI 어디에도 **매물 정보가 없다**. 그래서 판매자는 상대가 자신의 여러 매물 중 무엇을 문의하는지 알 수 없다.

## 목표

판매자별 단일 대화방 구조는 **그대로 유지**하면서, 문의 시작 시 **어떤 매물에 대한 문의인지 알려주는 매물 카드**를 대화에 남긴다. 같은 판매자에게 다른 매물로 문의하면 같은 방에 새 카드가 추가로 쌓여 판매자가 구분할 수 있다.

## 비목표 (YAGNI)

- 매물별 대화방 분리(당근 방식) — DB 스키마·유니크 제약 대공사 필요, 이번 범위 아님.
- `conversations`/`messages` 테이블에 매물 참조 컬럼 추가 — 아래 마커 방식으로 스키마 변경 없이 해결.
- 판매 상태 변경 알림, 거래 완료 처리 등 부가 기능.

## 핵심 아이디어: 리그 초대 링크 파싱 패턴 재사용

기존 리그 초대 기능은 메시지 본문에 `https://nakstar.app/league/<id>` 마커를 심고, `_MessageBubble._parseContent`가 이를 감지해 본문에서 제거한 뒤 "리그 보기" 버튼으로 렌더링한다 (`dm_chat_screen.dart` line 379-457).

매물 카드도 동일하게 **`https://nakstar.app/market/<itemId>` 마커**를 사용한다.

- **DB 스키마 변경 없음** — 메시지는 그대로 `messages.content` text에 저장.
- 리그가 작은 "리그 보기" 버튼을 렌더하는 것과 달리, 매물은 **가로 카드**(왼쪽 썸네일 + 오른쪽 제목/가격/상태 배지)를 렌더한다. 판매자가 어떤 물건인지 한눈에 봐야 하는 게 기능의 핵심이므로 썸네일이 보이는 넓은 블록으로 표시.

## 데이터 흐름

1. **문의하기 탭** — `marketplace_detail_screen.dart`
   - 기존대로 `getOrCreateConversation(item.userId)`로 판매자와의 대화방 id 확보.
   - `/dm/chat`로 이동하되 route `extra`에 `DmConversation` **+ 문의 대상 매물 정보**(id, 제목, 가격 표시문자열, 대표 썸네일 url)를 함께 전달.

2. **채팅방 진입** — `dm_chat_screen.dart`
   - 전달된 pending 매물이 있으면 **입력창 바로 위에 매물 미리보기 바** 표시: 작은 썸네일 + 제목 + 가격 + 닫기(X) 버튼.
   - 이 시점에는 아직 전송되지 않은 "대기" 상태. X를 누르면 pending 매물이 해제되어 미리보기가 사라진다.

3. **첫 메시지 전송** — pending 매물이 붙어있는 상태에서 전송 버튼을 누르면:
   - ① `sendItemCard(convId, item)` 로 매물 카드 메시지 전송 (`content = https://nakstar.app/market/<id>`).
   - ② 입력창에 텍스트가 있으면 이어서 텍스트 메시지 전송. **텍스트가 비어 있어도 카드 단독 전송을 허용**한다 (미리보기 카드가 붙어있으면 전송 버튼 활성).
   - 전송 후 pending 매물 해제 → 미리보기 바 사라짐.

4. **카드 렌더링** — `_MessageBubble`
   - market 마커를 감지하면 본문에서 제거하고 **매물 카드 위젯**을 렌더.
   - 카드는 `marketplaceItemProvider(itemId)`로 **현재 매물 정보를 실시간 조회**해 표시 (가격, 예약중/판매완료 상태 배지 반영).
   - 카드 탭 → 매물 상세 화면으로 이동.
   - 매물이 삭제된 경우 → "삭제된 매물" 상태로 표시하고 탭 시 안내(스낵바 등), 상세로 이동하지 않음.

## 변경/추가 상세

### 1. `marketplace_repository.dart` — 단일 매물 조회
- `Future<MarketplaceItem?> getItem(String itemId)` 추가. 필요한 컬럼만 select, `users!inner` join으로 판매자 정보 포함(상세 화면과 동일 형태). 삭제/미존재 시 `null`.
- `marketplaceItemProvider(itemId)` (Riverpod, autoDispose family) 추가. 카드가 여러 개여도 매물 id별 1회 조회 후 재사용(프로바이더 캐싱). 짧은 TTL 또는 keepAlive 미사용(autoDispose)로 상태 변경이 반영되게.
- 규칙 준수: 반복문 안 쿼리 금지 → 카드별 개별 provider watch는 id 단위 캐시로 N+1 아님. `select('*')` 금지 → 명시 컬럼.

### 2. `dm_repository.dart` — 매물 카드 전송
- `Future<DmMessage> sendItemCard(String conversationId, {required String itemId, required String title})` 추가.
  - `messages`에 `content = 'https://nakstar.app/market/<itemId>'` insert.
  - `on_dm_sent` 호출 시 `p_content`는 마커 URL이 아니라 **친화 미리보기 텍스트**(예: `'📦 {title}'`)를 넘긴다. 대화 목록(`dm_list_screen`)이 `conv.lastMessage`를 그대로 표시하므로, 카드가 마지막 메시지일 때 목록에 raw URL이 뜨지 않게 한다.
- 기존 `sendMessage`는 변경하지 않는다. 순서상 카드 → 텍스트 순으로 각각 호출한다(카드가 위에, 텍스트가 아래에 오도록).

### 3. `dm_chat_screen.dart`
- route extra에서 pending 매물 수신 → 상태로 보관.
- 입력창 위 **매물 미리보기 바** 위젯 추가 (pending 있을 때만). 닫기 버튼으로 해제.
- 전송 핸들러 수정: pending 매물이 있으면 `sendItemCard` 먼저, 그다음 텍스트가 있으면 `sendMessage`. 전송 후 pending 해제. 전송 버튼 활성 조건 = `text.isNotEmpty || pendingItem != null`.
- `_MessageBubble`:
  - market 마커 정규식 `https:\/\/nakstar\.app\/market\/([0-9a-fA-F-]{36})` 추가.
  - `_parseContent`를 확장하거나 별도 파싱으로 marketId 추출 + 본문에서 제거.
  - marketId가 있으면 리그 버튼 대신 **매물 카드 위젯**(`marketplaceItemProvider(marketId)` watch)을 렌더. 로딩/삭제/정상 3상태 처리.
  - 카드는 공통 위젯 규칙 준수: 색상 `AppColors`, 텍스트 `AppTextStyles`, 카드 컨테이너는 상황에 맞게(채팅 버블 내부 특수 위젯이므로 화면 전용 위젯으로 취급 가능). 썸네일은 기존 프로젝트의 이미지 위젯 패턴(CachedNetworkImage 등) 재사용.

### 4. `marketplace_detail_screen.dart`
- 문의하기 `onPressed`에서 `context.push('/dm/chat', extra: ...)` 시 pending 매물 정보(id, title, formattedPrice, 대표 이미지 url)를 함께 전달하도록 extra 구조 변경.

### 5. `app_router.dart`
- `/dm/chat` 라우트의 extra를 `DmConversation` 단독에서 **`DmConversation` + optional pending 매물**을 담는 구조로 확장. 기존 다른 진입점(대화 목록에서의 진입)은 pending 없이 전달 → 하위 호환.

## 엣지 케이스

- **텍스트 없이 카드만 전송**: 허용. 미리보기 카드가 붙어있으면 전송 버튼 활성, 카드 단독 전송됨. 실수 방지는 미리보기 X 버튼으로 취소 가능.
- **같은 판매자에게 다른 매물 재문의**: 같은 방에 새 카드가 추가로 쌓임 → 판매자 구분 가능(의도된 동작).
- **삭제/판매완료/예약중 매물**: 카드가 `marketplaceItemProvider`로 실시간 반영. 삭제 시 "삭제된 매물" 카드, 탭 시 안내만.
- **차단 사용자**: 기존 `sendMessage`의 차단 체크(`DmBlockedException`)와 동일하게 `sendItemCard`에도 차단 체크 적용(또는 전송 시퀀스 앞단에서 1회 체크). 카드 전송이 차단을 우회하지 않도록 주의.
- **악의적 마커 직접 타이핑**: 리그 초대와 동일 리스크(낮음). 동일하게 허용하되, 존재하지 않는 id면 "삭제된 매물"로 렌더되어 무해.
- **대화 목록 미리보기**: 카드 메시지의 `last_message`는 친화 텍스트(`📦 {title}`)로 저장되어 raw URL 노출 없음.

## 테스트 관점

- 문의하기 → 채팅방 진입 시 미리보기 바 노출 확인.
- 카드 단독 전송 / 카드+텍스트 전송 두 경로 모두 카드 메시지가 정상 렌더되는지.
- 판매자 계정에서 서로 다른 매물 2건 문의 시 카드 2개가 구분되어 보이는지.
- 매물 상태 변경(예약중/판매완료/삭제) 후 카드가 실시간 반영되는지.
- 대화 목록에서 카드가 마지막 메시지일 때 미리보기가 `📦 {제목}`으로 뜨는지 (raw URL 아님).
- 차단 사용자에게 카드 전송이 막히는지.

## 영향 없는 것

- `conversations`/`messages` DB 스키마: 변경 없음 (마이그레이션 불필요).
- 리그 초대 링크 파싱: 기존 로직 유지, market 파싱을 병렬 추가.
- 대화 목록에서의 채팅방 진입: pending 없이 동작(하위 호환).
