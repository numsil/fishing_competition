# 알림 기능 설계 (Notifications)

- **작성일**: 2026-06-24
- **브랜치**: `feature/notifications` (develop 기준)
- **상태**: 설계 합의 완료, 구현 계획 작성 예정

---

## 1. 목표

앱에 알림 기능이 없어 사용자가 자신을 향한 상호작용을 놓친다. 다음 3가지 이벤트에 대해
**푸시 알림(앱이 꺼져 있어도 폰에 표시)** 과 **앱내 알림함(목록 확인)** 을 모두 제공한다.

### 알림 대상 이벤트
| 이벤트 | 트리거 | 수신자 | 제외 조건 |
|---|---|---|---|
| 새 DM 메시지 | `messages` INSERT | conversation의 sender가 아닌 상대 | 본인 발신, 차단 관계 |
| 내 글에 댓글 | `post_comments` INSERT | `posts.user_id` (글 주인) | 본인 댓글, 차단 관계 |
| 새 팔로워 | `follows` INSERT | `followee_id` | 차단 관계 |

### 범위 제외 (YAGNI — 추후 가능)
- 알림 종류별 켜기/끄기 설정 (이번엔 OS 권한만)
- 좋아요 알림
- 알림 그룹핑/요약

---

## 2. 아키텍처 개요

```
[이벤트 발생: messages / post_comments / follows INSERT]
        ↓ AFTER INSERT 트리거 (Postgres)
   ┌────────────────────────────────────────┐
   │ 1) notifications 테이블에 row 삽입        │  → 앱내 알림함 + Realtime 배지
   │ 2) pg_net 으로 Edge Function 호출         │  → 푸시 발송
   └────────────────────────────────────────┘
        ↓
   Edge Function: 수신자 device_tokens 조회
        ↓
   Firebase FCM (HTTP v1)
        ├─ 안드로이드 → 폰
        └─ 아이폰 → 애플 APNs → 폰
```

**왜 Firebase가 필요한가**: 잠금화면 푸시 배달은 OS 제조사(구글 FCM / 애플 APNs)만 가능.
Supabase는 이벤트 감지·발송 지시까지만 담당하고, 실제 배달은 FCM이 통합 처리한다.
FCM 발송은 무제한 무료, APNs도 무료. (애플 개발자 계정은 배포용으로 이미 보유)

기존 패턴 준수:
- Realtime 배지 → DM의 `hasUnreadDmsProvider` 패턴 복제
- 스키마 변경 → 마이그레이션 파일로 관리 (대시보드 DDL 금지)
- 탭 이동 → 기존 `deep_link_service` 라우트 매핑 재사용

---

## 3. 서버 (Supabase — 마이그레이션으로 관리)

### 3.1 테이블

**`notifications`**
| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | uuid PK | |
| user_id | uuid FK→users | 수신자 |
| type | text | `dm` \| `comment` \| `follow` |
| actor_id | uuid FK→users | 행위자(보낸 사람) |
| target_id | uuid nullable | post_id(comment) / conversation_id(dm) / null(follow) |
| body | text | 알림 본문 미리보기 |
| is_read | boolean default false | |
| created_at | timestamptz default now() | |

- 인덱스: `(user_id, created_at DESC)`, `(user_id, is_read)`
- RLS: 본인(`auth.uid() = user_id`)만 SELECT/UPDATE(읽음 처리). INSERT는 트리거(SECURITY DEFINER)만.
- Realtime publication 추가 (배지용)

**`device_tokens`**
| 컬럼 | 타입 | 설명 |
|---|---|---|
| user_id | uuid FK→users | |
| token | text | FCM 토큰 |
| platform | text | `android` \| `ios` |
| updated_at | timestamptz | |

- PK: `(user_id, token)` (한 유저가 여러 기기 가능)
- RLS: 본인만 upsert/delete

### 3.2 트리거 함수 (3개, SECURITY DEFINER)
공통 헬퍼: `create_notification(recipient, type, actor, target, body)` →
차단 관계(`user_blocks`) 확인 후 `notifications` insert + `pg_net`으로 Edge Function 호출.

- `on_message_insert()` — conversation에서 수신자 산출, sender≠recipient 확인
- `on_comment_insert()` — `posts.user_id` 조회, commenter≠owner 확인
- `on_follow_insert()` — followee를 수신자로

각 테이블에 `AFTER INSERT FOR EACH ROW` 트리거 연결.

> 주의: DM은 기존 `on_dm_sent` RPC(대화 unread 갱신)와 **별개**로 동작.
> on_dm_sent는 그대로 두고, 푸시/알림함은 신규 트리거가 담당.

### 3.3 Edge Function: `send-push`
- 입력: `{ user_id, title, body, data }`
- 처리: `device_tokens` 조회 → FCM HTTP v1 API로 발송 → 무효 토큰(404/410) 정리
- 비밀값: FCM 서비스 계정 키 (Supabase secrets)

---

## 4. 클라이언트 (Flutter)

### 4.1 의존성
- `firebase_core`, `firebase_messaging` 추가
- `main.dart`: `Firebase.initializeApp()` + 알림 권한 요청 + 백그라운드 핸들러 등록

### 4.2 토큰 등록
- 로그인/앱 시작 시 FCM 토큰 획득 → `device_tokens` upsert
- 토큰 갱신(`onTokenRefresh`) 시 재등록
- 로그아웃 시 해당 토큰 삭제

### 4.3 알림 수신 처리
- **포그라운드**: 인앱 표시 안 함(또는 가벼운 스낵바), `notifications` Realtime이 배지 갱신
- **백그라운드/종료**: OS가 푸시 표시, 탭 시 `data` 페이로드의 경로로 이동
- 라우팅: `deep_link_service` 매핑 재사용 + **`/dm` 매핑 추가** (현재 없음)

### 4.4 UI
- **알림함 화면** (신규): `notifications` 목록(페이지네이션/limit), 항목 = 아바타 + 본문 + 시간, 탭 시 이동, 진입 시 읽음 처리
- **피드 앱바 🔔 벨 아이콘** (신규): DM 버튼과 동일 패턴, 안 읽은 알림 있으면 빨간 점
- 배지 provider: `hasUnreadNotificationsProvider` (Realtime StreamProvider, DM 패턴 복제)
- 공통 위젯 규칙 준수: `UserAvatar`, `AppTextStyles`, `AppColors`, `EmptyState` 사용

### 4.5 데이터 접근
- `NotificationRepository` 신규 (UI/Provider 직접 쿼리 금지 규칙 준수)
- 필요한 컬럼만 select, `users!inner` join으로 actor 정보 동시 조회

---

## 5. 사용자(수동) 작업 — 콘솔 클릭 작업, 단계별 안내 제공
1. **Firebase 프로젝트 생성**
   - Android 앱 등록 → `google-services.json` → `android/app/`에 배치
   - iOS 앱 등록 → `GoogleService-Info.plist` → `ios/Runner/`에 배치
2. **애플 APNs 인증키(.p8)** 발급 (Apple Developer) → Firebase Cloud Messaging에 등록
3. **앱 ID에 Push Notifications capability** 활성화 (Apple Developer)
4. **FCM 서비스 계정 키** → Supabase secrets에 등록 (Edge Function용)

---

## 6. 네이티브 설정 (코드 — 제가 처리)
- Android: `build.gradle`에 google-services 플러그인, FCM 의존성
- iOS: Push Notifications capability, `UIBackgroundModes: remote-notification`,
  `AppDelegate`에 APNs 등록

---

## 7. 엣지 케이스
- 본인 행위(자기 글에 자기 댓글 등) → 알림 생성 안 함
- 차단 관계 → 알림 생성 안 함
- 다중 기기 → 모든 토큰에 발송, 무효 토큰 정리
- 알림 권한 거부 → 앱내 알림함은 정상 동작(푸시만 미발송)
- 빠른 연속 이벤트 → 각각 별도 알림 (이번 범위에선 그룹핑 없음)

---

## 8. 테스트 관점
- 트리거: 각 이벤트 INSERT 시 notifications row 생성/제외 조건 검증
- Edge Function: 토큰 유무·무효 토큰 처리
- 클라이언트: 토큰 등록, 포그라운드/백그라운드/종료 상태 탭 라우팅, 배지 갱신, 읽음 처리
