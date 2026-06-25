# 알림 기능 (Notifications) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** DM·댓글·팔로우 이벤트에 대해 푸시 알림(앱 종료 시에도)과 앱내 알림함을 제공한다.

**Architecture:** Postgres AFTER INSERT 트리거가 `notifications` row를 만들고 `pg_net`으로 Edge Function을 호출 → Edge Function이 수신자의 `device_tokens`를 조회해 Firebase FCM(HTTP v1)으로 발송. 안드로이드는 FCM 직접, iOS는 FCM→APNs. 앱은 `firebase_messaging`으로 토큰 등록·수신하고, 알림함 화면과 피드 앱바 벨 아이콘(Realtime 배지)을 추가한다.

**Tech Stack:** Supabase(Postgres, pg_net, Edge Functions/Deno), Firebase Cloud Messaging, Flutter(Riverpod, go_router, firebase_core, firebase_messaging)

**Design spec:** `docs/superpowers/specs/2026-06-24-notifications-design.md`

---

## 파일 구조 (생성/수정 대상)

**서버 (Supabase)**
- Create: `supabase/migrations/<ts>_notifications_tables.sql` — notifications/device_tokens 테이블 + RLS + Realtime
- Create: `supabase/migrations/<ts>_notification_triggers.sql` — 헬퍼 + 트리거 3개
- Create: `supabase/functions/send-push/index.ts` — FCM 발송 Edge Function

**Flutter — 데이터/서비스**
- Create: `lib/features/notifications/data/notification_model.dart` — 알림 모델 + fromJson
- Create: `lib/features/notifications/data/notification_repository.dart` — 조회/읽음 + providers (`@riverpod`)
- Create: `lib/core/services/push_service.dart` — FCM 토큰 등록/권한/수신
- Modify: `lib/core/deep_link/deep_link_service.dart` — `/dm` 매핑 추가 + payload→route 헬퍼 노출

**Flutter — UI/통합**
- Create: `lib/features/notifications/presentation/screens/notification_screen.dart` — 알림함 화면
- Modify: `lib/core/router/app_router.dart` — `/notifications` 라우트 + `AppRoutes.notifications`
- Modify: `lib/features/feed/presentation/screens/feed_screen.dart` — 앱바 벨 아이콘
- Modify: `lib/main.dart` — Firebase 초기화 + 백그라운드 핸들러 + 푸시 탭 라우팅

**네이티브**
- Modify: `pubspec.yaml`, `android/build.gradle*`, `android/app/build.gradle*`, `ios/Runner/Info.plist`, `ios/Runner/AppDelegate.swift`, `ios/Runner/Runner.entitlements`

---

## Phase 1 — 데이터베이스 (마이그레이션)

> 마이그레이션 적용 절차(프로젝트 규칙): 파일 작성 → `PGPASSWORD='<PW>' psql "<pooler URL>" -f <파일>` 로 prod 적용. DB 비밀번호는 사용자가 직접 입력.

### Task 1: notifications / device_tokens 테이블

**Files:**
- Create: `supabase/migrations/<ts>_notifications_tables.sql`

- [ ] **Step 1: 마이그레이션 파일 생성**

Run: `/Users/jun/.local/bin/supabase migration new notifications_tables`
Expected: `supabase/migrations/<timestamp>_notifications_tables.sql` 생성됨

- [ ] **Step 2: 테이블 SQL 작성**

생성된 파일에 작성:

```sql
-- 알림함용 알림 레코드
CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,   -- 수신자
    type text NOT NULL CHECK (type IN ('dm', 'comment', 'follow')),
    actor_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,  -- 행위자
    target_id uuid,                       -- post_id(comment) | conversation_id(dm) | null(follow)
    body text NOT NULL DEFAULT '',
    is_read boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
    ON public.notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
    ON public.notifications(user_id) WHERE is_read = false;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 본인 알림만 조회
CREATE POLICY "Users read own notifications"
    ON public.notifications FOR SELECT
    USING (auth.uid() = user_id);

-- 본인 알림만 읽음 처리(UPDATE)
CREATE POLICY "Users update own notifications"
    ON public.notifications FOR UPDATE
    USING (auth.uid() = user_id);
-- INSERT 정책 없음 → 트리거(SECURITY DEFINER)만 삽입 가능

-- 배지 Realtime 구독용
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- 기기 푸시 토큰
CREATE TABLE IF NOT EXISTS public.device_tokens (
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    token text NOT NULL,
    platform text NOT NULL CHECK (platform IN ('android', 'ios')),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON public.device_tokens(user_id);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own device tokens (select)"
    ON public.device_tokens FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users manage own device tokens (insert)"
    ON public.device_tokens FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users manage own device tokens (update)"
    ON public.device_tokens FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users manage own device tokens (delete)"
    ON public.device_tokens FOR DELETE USING (auth.uid() = user_id);
```

- [ ] **Step 3: prod 적용**

Run (사용자가 PW 입력):
```
PGPASSWORD='<DB_PW>' psql "postgresql://postgres.zpcmpfrswlbnqkqrmvxu@aws-1-ap-south-1.pooler.supabase.com:5432/postgres" -f supabase/migrations/<ts>_notifications_tables.sql
```
Expected: `CREATE TABLE`, `CREATE INDEX`, `CREATE POLICY`, `ALTER PUBLICATION` 출력, 에러 없음

- [ ] **Step 4: 검증 쿼리**

Run:
```
PGPASSWORD='<DB_PW>' psql "<pooler URL>" -c "\d public.notifications" -c "\d public.device_tokens"
```
Expected: 두 테이블 구조 출력, notifications가 supabase_realtime publication에 포함

- [ ] **Step 5: 커밋**

```bash
git add supabase/migrations/
git commit -m "feat(db): notifications & device_tokens 테이블 추가"
```

---

### Task 2: 알림 생성 헬퍼 + 트리거 3개

**Files:**
- Create: `supabase/migrations/<ts>_notification_triggers.sql`

전제: Edge Function 호출에 필요한 비밀값을 Vault에 저장(사용자 수동, Step 1). 트리거는 Vault에서 읽어 `pg_net`으로 호출한다.

- [ ] **Step 1: Vault에 시크릿 저장 (사용자 수동, 1회)**

Supabase SQL Editor 또는 psql에서 (값은 사용자가 입력):
```sql
select vault.create_secret('https://zpcmpfrswlbnqkqrmvxu.supabase.co', 'project_url');
select vault.create_secret('<SERVICE_ROLE_KEY>', 'service_role_key');
```
Expected: 각 1행 반환(uuid). 이미 있으면 건너뜀.

- [ ] **Step 2: 마이그레이션 파일 생성**

Run: `/Users/jun/.local/bin/supabase migration new notification_triggers`

- [ ] **Step 3: 헬퍼 + 트리거 SQL 작성**

```sql
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 공통: 알림 row 삽입 + Edge Function 호출(푸시). 차단 관계면 스킵.
CREATE OR REPLACE FUNCTION public.create_notification(
    p_recipient uuid,
    p_type text,
    p_actor uuid,
    p_target uuid,
    p_body text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_url text;
    v_key text;
    v_actor_name text;
    v_title text;
BEGIN
    -- 본인 행위는 알림 없음
    IF p_recipient = p_actor THEN RETURN; END IF;

    -- 차단 관계(양방향)면 알림 없음
    IF EXISTS (
        SELECT 1 FROM public.user_blocks
        WHERE (blocker_id = p_recipient AND blocked_id = p_actor)
           OR (blocker_id = p_actor AND blocked_id = p_recipient)
    ) THEN RETURN; END IF;

    INSERT INTO public.notifications(user_id, type, actor_id, target_id, body)
    VALUES (p_recipient, p_type, p_actor, p_target, p_body);

    -- 푸시 발송 (Vault 시크릿 사용)
    SELECT decrypted_secret INTO v_url FROM vault.decrypted_secrets WHERE name = 'project_url';
    SELECT decrypted_secret INTO v_key FROM vault.decrypted_secrets WHERE name = 'service_role_key';
    IF v_url IS NULL OR v_key IS NULL THEN RETURN; END IF;

    SELECT username INTO v_actor_name FROM public.users WHERE id = p_actor;
    v_title := CASE p_type
        WHEN 'dm' THEN COALESCE(v_actor_name, '낚시친구')
        WHEN 'comment' THEN '새 댓글'
        WHEN 'follow' THEN '새 팔로워'
        ELSE '알림' END;

    PERFORM net.http_post(
        url := v_url || '/functions/v1/send-push',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || v_key
        ),
        body := jsonb_build_object(
            'user_id', p_recipient,
            'title', v_title,
            'body', p_body,
            'data', jsonb_build_object('type', p_type, 'target_id', p_target, 'actor_id', p_actor)
        )
    );
END;
$$;

-- 1) DM: messages INSERT → 상대에게 알림
CREATE OR REPLACE FUNCTION public.on_message_insert() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_recipient uuid;
BEGIN
    SELECT CASE WHEN user1_id = NEW.sender_id THEN user2_id ELSE user1_id END
      INTO v_recipient FROM public.conversations WHERE id = NEW.conversation_id;
    IF v_recipient IS NOT NULL THEN
        PERFORM public.create_notification(
            v_recipient, 'dm', NEW.sender_id, NEW.conversation_id, left(NEW.content, 100));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_message_notify
    AFTER INSERT ON public.messages
    FOR EACH ROW EXECUTE FUNCTION public.on_message_insert();

-- 2) 댓글: post_comments INSERT → 글 주인에게 알림
CREATE OR REPLACE FUNCTION public.on_comment_insert() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_owner uuid;
BEGIN
    SELECT user_id INTO v_owner FROM public.posts WHERE id = NEW.post_id;
    IF v_owner IS NOT NULL THEN
        PERFORM public.create_notification(
            v_owner, 'comment', NEW.user_id, NEW.post_id, left(NEW.content, 100));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_comment_notify
    AFTER INSERT ON public.post_comments
    FOR EACH ROW EXECUTE FUNCTION public.on_comment_insert();

-- 3) 팔로우: follows INSERT → followee에게 알림
CREATE OR REPLACE FUNCTION public.on_follow_insert() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    PERFORM public.create_notification(
        NEW.followee_id, 'follow', NEW.follower_id, NULL, '회원님을 팔로우하기 시작했습니다');
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_follow_notify
    AFTER INSERT ON public.follows
    FOR EACH ROW EXECUTE FUNCTION public.on_follow_insert();
```

- [ ] **Step 4: prod 적용**

Run: `PGPASSWORD='<DB_PW>' psql "<pooler URL>" -f supabase/migrations/<ts>_notification_triggers.sql`
Expected: `CREATE EXTENSION`/`CREATE FUNCTION`/`CREATE TRIGGER` 출력, 에러 없음

- [ ] **Step 5: 검증 — 알림 row 생성 확인 (푸시는 Phase 3 이후 동작)**

테스트 유저 2명으로 팔로우 1건 INSERT 후:
```
PGPASSWORD='<DB_PW>' psql "<pooler URL>" -c "SELECT type, user_id, actor_id, body FROM notifications ORDER BY created_at DESC LIMIT 3;"
```
Expected: follow 알림 row 1건. 본인 팔로우/차단 케이스는 row 없음.

- [ ] **Step 6: 커밋**

```bash
git add supabase/migrations/
git commit -m "feat(db): 알림 생성 트리거(DM/댓글/팔로우) 추가"
```

---

## Phase 2 — Edge Function (FCM 발송)

### Task 3: send-push Edge Function

**Files:**
- Create: `supabase/functions/send-push/index.ts`

전제: FCM 서비스 계정 JSON을 Supabase secret `FCM_SERVICE_ACCOUNT`(전체 JSON 문자열)로 등록(사용자 수동, Phase 3 이후).

- [ ] **Step 1: 함수 디렉토리/파일 생성**

Run: `/Users/jun/.local/bin/supabase functions new send-push`
Expected: `supabase/functions/send-push/index.ts` 생성

- [ ] **Step 2: index.ts 작성**

```ts
// 수신자의 device_tokens 로 FCM HTTP v1 푸시 발송. 무효 토큰 정리.
import { createClient } from "jsr:@supabase/supabase-js@2";

interface Payload {
  user_id: string;
  title: string;
  body: string;
  data?: Record<string, unknown>;
}

// 서비스계정으로 OAuth 액세스 토큰 발급 (FCM HTTP v1 인증)
async function getAccessToken(sa: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const enc = (o: unknown) =>
    btoa(JSON.stringify(o)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const unsigned = `${enc({ alg: "RS256", typ: "JWT" })}.${enc(claim)}`;

  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8", der.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned));
  const jwt = `${unsigned}.${btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_")}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  return (await res.json()).access_token;
}

Deno.serve(async (req) => {
  try {
    const { user_id, title, body, data }: Payload = await req.json();
    const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: tokens } = await supabase
      .from("device_tokens").select("token").eq("user_id", user_id);
    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    const accessToken = await getAccessToken(sa);
    const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
    const strData: Record<string, string> = {};
    for (const [k, v] of Object.entries(data ?? {})) strData[k] = String(v ?? "");

    let sent = 0;
    for (const { token } of tokens) {
      const r = await fetch(url, {
        method: "POST",
        headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          message: { token, notification: { title, body }, data: strData },
        }),
      });
      if (r.ok) sent++;
      else if (r.status === 404 || r.status === 400) {
        await supabase.from("device_tokens").delete().eq("token", token); // 무효 토큰 정리
      }
    }
    return new Response(JSON.stringify({ sent }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
```

- [ ] **Step 3: 배포 (Phase 3에서 FCM 서비스계정 secret 등록 후 실행)**

Run:
```
/Users/jun/.local/bin/supabase secrets set FCM_SERVICE_ACCOUNT="$(cat <서비스계정.json>)"
/Users/jun/.local/bin/supabase functions deploy send-push
```
Expected: 배포 성공 메시지

- [ ] **Step 4: 커밋**

```bash
git add supabase/functions/send-push/
git commit -m "feat(edge): send-push FCM 발송 함수 추가"
```

---

## Phase 3 — Firebase 콘솔/네이티브 (사용자 수동 + 코드)

> ⚠️ 이 Phase의 콘솔 작업은 사용자가 직접 수행. 막히면 단계별 화면 안내 요청.

### 사용자 수동 체크리스트 (코드 아님)
- [ ] Firebase 콘솔에서 프로젝트 생성
- [ ] Android 앱 등록(패키지명 일치) → `google-services.json` 다운로드 → `android/app/`에 배치
- [ ] iOS 앱 등록(Bundle ID 일치) → `GoogleService-Info.plist` 다운로드 → `ios/Runner/`에 배치
- [ ] Apple Developer에서 APNs 인증키(.p8) 발급 → Firebase > 프로젝트 설정 > Cloud Messaging > APNs 인증키 업로드
- [ ] Apple Developer에서 App ID에 Push Notifications capability 활성화
- [ ] Firebase > 프로젝트 설정 > 서비스 계정 > 새 비공개 키 생성 → JSON 다운로드 (Task 3 Step 3에서 사용)

### Task 4: Flutter 의존성 + Android 네이티브 설정

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/build.gradle` (또는 `android/settings.gradle`)
- Modify: `android/app/build.gradle`

- [ ] **Step 1: pubspec 의존성 추가**

`pubspec.yaml` dependencies에 추가 (app_links 아래 등 적당한 위치):
```yaml
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.3
```

- [ ] **Step 2: 패키지 설치**

Run: `flutter pub get`
Expected: 의존성 해결 성공

- [ ] **Step 3: Android google-services 플러그인 적용**

`android/settings.gradle`의 plugins 블록에 추가(버전은 환경에 맞게):
```gradle
    id "com.google.gms.google-services" version "4.4.2" apply false
```
`android/app/build.gradle`의 plugins 블록 최하단에 추가:
```gradle
    id "com.google.gms.google-services"
```

- [ ] **Step 4: 빌드 확인**

Run: `flutter build apk --debug`
Expected: 빌드 성공 (google-services.json 없으면 실패 → 사용자 체크리스트 선완료 필요)

- [ ] **Step 5: 커밋**

```bash
git add pubspec.yaml pubspec.lock android/
git commit -m "chore(android): firebase_messaging 의존성 및 google-services 설정"
```

### Task 5: iOS 네이티브 설정

**Files:**
- Modify: `ios/Runner/Info.plist`
- Modify: `ios/Runner/AppDelegate.swift`
- Create/Modify: `ios/Runner/Runner.entitlements`

- [ ] **Step 1: Info.plist 백그라운드 모드 추가**

`ios/Runner/Info.plist` `<dict>` 안에 추가:
```xml
	<key>UIBackgroundModes</key>
	<array>
		<string>remote-notification</string>
	</array>
```

- [ ] **Step 2: entitlements에 푸시 권한 추가**

`ios/Runner/Runner.entitlements`에 추가(파일 없으면 생성 후 Xcode에서 타겟에 연결):
```xml
	<key>aps-environment</key>
	<string>production</string>
```

- [ ] **Step 3: AppDelegate에서 APNs 등록**

`ios/Runner/AppDelegate.swift`의 `application(_:didFinishLaunchingWithOptions:)` 안 `GeneratedPluginRegistrant` 호출 뒤에 추가:
```swift
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    application.registerForRemoteNotifications()
```

- [ ] **Step 4: iOS 빌드 확인**

Run: `flutter build ios --debug --no-codesign`
Expected: 빌드 성공

- [ ] **Step 5: 커밋**

```bash
git add ios/
git commit -m "chore(ios): 푸시 알림 capability 및 APNs 등록 설정"
```

---

## Phase 4 — Flutter 앱 코드

### Task 6: 딥링크 매핑 확장 (`/dm`) + payload→route 헬퍼 (TDD)

**Files:**
- Modify: `lib/core/deep_link/deep_link_service.dart`
- Test: `test/core/deep_link/notification_route_test.dart`

알림 탭 시 페이로드(`type`, `target_id`)를 라우트로 변환하는 순수 함수를 추가하고 테스트한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/core/deep_link/notification_route_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fishing_competition/core/deep_link/deep_link_service.dart';

void main() {
  group('routeFromNotification', () {
    const uuid = '11111111-1111-1111-1111-111111111111';

    test('comment → /post/{id}', () {
      expect(routeFromNotification('comment', uuid), '/post/$uuid');
    });
    test('dm → /dm', () {
      expect(routeFromNotification('dm', uuid), '/dm');
    });
    test('follow → /user/{actor}', () {
      expect(routeFromNotification('follow', uuid, actorId: uuid), '/user/$uuid');
    });
    test('unknown → null', () {
      expect(routeFromNotification('bogus', uuid), isNull);
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/core/deep_link/notification_route_test.dart`
Expected: FAIL — `routeFromNotification` 미정의

- [ ] **Step 3: 헬퍼 구현 + `/dm` 매핑 추가**

`lib/core/deep_link/deep_link_service.dart` 파일 최상단(클래스 밖)에 추가:
```dart
/// 푸시 알림 payload(type/target_id)를 앱 내부 라우트로 변환. 실패 시 null.
String? routeFromNotification(String type, String? targetId, {String? actorId}) {
  switch (type) {
    case 'comment':
      return targetId != null ? '/post/$targetId' : null;
    case 'dm':
      return '/dm';
    case 'follow':
      return actorId != null ? '/user/$actorId' : null;
    default:
      return null;
  }
}
```
그리고 `_mapToRoute`의 `switch (segments.first)`에 case 추가(`user` case 위):
```dart
      case 'dm':
        return '/dm';
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/core/deep_link/notification_route_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/core/deep_link/deep_link_service.dart test/core/deep_link/
git commit -m "feat(deep-link): 알림 payload→route 변환 및 /dm 매핑"
```

### Task 7: 알림 모델 + fromJson (TDD)

**Files:**
- Create: `lib/features/notifications/data/notification_model.dart`
- Test: `test/features/notifications/notification_model_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/features/notifications/notification_model_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fishing_competition/features/notifications/data/notification_model.dart';

void main() {
  test('AppNotification.fromJson parses joined actor', () {
    final json = {
      'id': 'n1',
      'type': 'comment',
      'actor_id': 'a1',
      'target_id': 'p1',
      'body': '좋은 사진이네요',
      'is_read': false,
      'created_at': '2026-06-24T00:00:00Z',
      'actor': {'username': 'angler', 'avatar_url': null},
    };
    final n = AppNotification.fromJson(json);
    expect(n.id, 'n1');
    expect(n.type, 'comment');
    expect(n.actorUsername, 'angler');
    expect(n.targetId, 'p1');
    expect(n.isRead, false);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/features/notifications/notification_model_test.dart`
Expected: FAIL — `AppNotification` 미정의

- [ ] **Step 3: 모델 구현**

`lib/features/notifications/data/notification_model.dart`:
```dart
class AppNotification {
  final String id;
  final String type; // dm | comment | follow
  final String actorId;
  final String? targetId;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String actorUsername;
  final String? actorAvatarUrl;

  AppNotification({
    required this.id,
    required this.type,
    required this.actorId,
    required this.targetId,
    required this.body,
    required this.isRead,
    required this.createdAt,
    required this.actorUsername,
    required this.actorAvatarUrl,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      actorId: json['actor_id'] as String,
      targetId: json['target_id'] as String?,
      body: json['body'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      actorUsername: actor?['username'] as String? ?? '알 수 없음',
      actorAvatarUrl: actor?['avatar_url'] as String?,
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/features/notifications/notification_model_test.dart`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add lib/features/notifications/data/notification_model.dart test/features/notifications/
git commit -m "feat(notifications): AppNotification 모델 추가"
```

### Task 8: NotificationRepository + providers

**Files:**
- Create: `lib/features/notifications/data/notification_repository.dart`

DM의 `hasUnreadDms` / `dmConversations` 패턴을 그대로 따른다(Realtime StreamProvider).

- [ ] **Step 1: 리포지토리 + provider 작성**

`lib/features/notifications/data/notification_repository.dart`:
```dart
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
    return (data as List)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
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
```

- [ ] **Step 2: 코드 생성**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `notification_repository.g.dart` 생성, 에러 없음

- [ ] **Step 3: 분석 통과 확인**

Run: `flutter analyze lib/features/notifications/`
Expected: No issues

- [ ] **Step 4: 커밋**

```bash
git add lib/features/notifications/data/
git commit -m "feat(notifications): NotificationRepository 및 providers 추가"
```

### Task 9: 알림함 화면 + 라우트

**Files:**
- Create: `lib/features/notifications/presentation/screens/notification_screen.dart`
- Modify: `lib/core/router/app_router.dart`

dm_list_screen 패턴(Scaffold + AppBar + when + UserAvatar)을 따른다.

- [ ] **Step 1: 화면 작성**

`lib/features/notifications/presentation/screens/notification_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/deep_link/deep_link_service.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/notification_repository.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    // 진입 시 전체 읽음 처리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationRepositoryProvider).markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.isDark ? AppColors.darkBg : Colors.white;
    final sub = context.isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft,
              color: context.isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text('알림',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.isDark ? Colors.white : Colors.black)),
        centerTitle: true,
      ),
      body: ref.watch(notificationListProvider).when(
            skipLoadingOnReload: true,
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.bell,
                          size: 56,
                          color: context.isDark
                              ? const Color(0xFF333333)
                              : const Color(0xFFCCCCCC)),
                      const SizedBox(height: 16),
                      Text('아직 알림이 없습니다',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.isDark ? Colors.white : Colors.black)),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(notificationListProvider),
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final n = items[i];
                    return InkWell(
                      onTap: () {
                        final route = routeFromNotification(n.type, n.targetId,
                            actorId: n.actorId);
                        if (route != null) context.push(route);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            UserAvatar(
                              username: n.actorUsername,
                              avatarUrl: n.actorAvatarUrl,
                              radius: 24,
                              isDark: context.isDark,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_label(n.type, n.actorUsername),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text(n.body,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13, color: sub)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_formatTime(n.createdAt),
                                style: TextStyle(fontSize: 11, color: sub)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('알림을 불러오지 못했습니다', style: TextStyle(color: sub))),
          ),
    );
  }

  String _label(String type, String actor) {
    switch (type) {
      case 'dm':
        return '$actor님의 메시지';
      case 'comment':
        return '$actor님이 댓글을 남겼습니다';
      case 'follow':
        return '$actor님이 팔로우했습니다';
      default:
        return '알림';
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }
}
```

- [ ] **Step 2: 라우트 등록**

`lib/core/router/app_router.dart` 상단 import에 추가:
```dart
import '../../features/notifications/presentation/screens/notification_screen.dart';
```
`ShellRoute` **밖**의 최상위 routes(예: dm 라우트 근처)에 GoRoute 추가:
```dart
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationScreen(),
      ),
```
`AppRoutes` 클래스에 상수 추가:
```dart
  static const String notifications = '/notifications';
```

- [ ] **Step 3: 분석 통과 확인**

Run: `flutter analyze lib/features/notifications/ lib/core/router/`
Expected: No issues

- [ ] **Step 4: 커밋**

```bash
git add lib/features/notifications/presentation/ lib/core/router/app_router.dart
git commit -m "feat(notifications): 알림함 화면 및 라우트 추가"
```

### Task 10: 피드 앱바 벨 아이콘

**Files:**
- Modify: `lib/features/feed/presentation/screens/feed_screen.dart`

DM 버튼 Consumer 패턴을 복제해 벨 아이콘을 DM 아이콘 **앞**에 추가.

- [ ] **Step 1: import 추가**

`feed_screen.dart` 상단 import 영역에 추가:
```dart
import '../../../notifications/data/notification_repository.dart';
```

- [ ] **Step 2: 벨 아이콘 위젯 삽입**

`actions: [` 의 DM `Consumer(...)` 블록 **바로 앞**에 추가:
```dart
        Consumer(
          builder: (context, ref, _) {
            final hasUnread =
                ref.watch(hasUnreadNotificationsProvider).valueOrNull ?? false;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () => context.push(AppRoutes.notifications),
                  icon: Icon(LucideIcons.bell,
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

- [ ] **Step 3: 분석 + 실행 확인**

Run: `flutter analyze lib/features/feed/presentation/screens/feed_screen.dart`
Expected: No issues. 앱 실행 시 피드 앱바에 벨 아이콘 표시, 탭하면 알림함 이동.

- [ ] **Step 4: 커밋**

```bash
git add lib/features/feed/presentation/screens/feed_screen.dart
git commit -m "feat(feed): 앱바 알림 벨 아이콘 추가"
```

### Task 11: PushService (FCM 토큰/권한/수신) + main.dart 통합

**Files:**
- Create: `lib/core/services/push_service.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: PushService 작성**

`lib/core/services/push_service.dart`:
```dart
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

  Future<void> start() async {
    final messaging = FirebaseMessaging.instance;

    // 권한 요청 (iOS 필수, Android 13+ 권장)
    await messaging.requestPermission();

    await _registerToken(messaging);
    messaging.onTokenRefresh.listen((t) => _saveToken(t));

    // 종료 상태에서 알림 탭으로 앱이 열린 경우
    final initial = await messaging.getInitialMessage();
    if (initial != null) _handleTap(initial);

    // 백그라운드(앱 살아있음)에서 알림 탭
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
  }

  Future<void> _registerToken(FirebaseMessaging messaging) async {
    try {
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
```

- [ ] **Step 2: main.dart에 Firebase 초기화 + 백그라운드 핸들러**

`lib/main.dart` import에 추가:
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/services/push_service.dart';
```
`main()` 함수 안, `Supabase.initialize(...)` 호출 뒤에 추가:
```dart
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase 초기화 실패: $e');
  }
```
파일 최상위(클래스 밖)에 백그라운드 핸들러 추가:
```dart
@pragma('vm:entry-point')
Future<void> _firebaseBgHandler(RemoteMessage message) async {
  // 백그라운드 수신: OS가 알림 표시. 추가 처리 불필요.
}
```
`main()`의 `WidgetsFlutterBinding.ensureInitialized();` 뒤에 등록:
```dart
  FirebaseMessaging.onBackgroundMessage(_firebaseBgHandler);
```

- [ ] **Step 3: PushService를 라우터에 바인딩**

`_FishingCompetitionAppState`에 필드 추가:
```dart
  PushService? _pushService;
```
`build`의 딥링크 재바인딩 블록 안(`_deepLinkService = ...` 다음 줄)에 추가:
```dart
      _pushService = PushService(router)..start();
```

- [ ] **Step 4: 분석 + 빌드 확인**

Run: `flutter analyze lib/core/services/push_service.dart lib/main.dart`
Expected: No issues
Run: `flutter build apk --debug`
Expected: 빌드 성공

- [ ] **Step 5: 커밋**

```bash
git add lib/core/services/push_service.dart lib/main.dart
git commit -m "feat(push): FCM 토큰 등록 및 알림 탭 라우팅(PushService)"
```

---

## Phase 5 — 통합 검증 (실기기)

### Task 12: End-to-End 수동 검증

- [ ] **Step 1: 토큰 등록 확인**
실기기에서 로그인 후:
```
PGPASSWORD='<DB_PW>' psql "<pooler URL>" -c "SELECT user_id, platform FROM device_tokens ORDER BY updated_at DESC LIMIT 5;"
```
Expected: 내 user_id + platform row 존재

- [ ] **Step 2: 댓글 알림 (앱 포그라운드)**
다른 계정으로 내 글에 댓글 → 피드 벨 아이콘 빨간 점 표시 + 알림함에 항목.

- [ ] **Step 3: 푸시 (앱 종료)**
앱 완전 종료 → 다른 계정이 DM 발송 → 잠금화면 푸시 수신 → 탭 시 DM 화면 이동.

- [ ] **Step 4: 팔로우 알림**
다른 계정이 나를 팔로우 → 알림 수신, 탭 시 그 사람 프로필(`/user/{id}`) 이동.

- [ ] **Step 5: 제외 케이스 확인**
- 내 글에 내가 댓글 → 알림 없음
- 차단한 사용자의 행위 → 알림 없음

- [ ] **Step 6: 읽음 처리**
알림함 진입 후 뒤로가기 → 벨 빨간 점 사라짐.

---

## Self-Review 결과 (작성자 점검)
- 스펙 커버리지: 3 이벤트(DM/댓글/팔로우)·테이블 2개·트리거·Edge Function·토큰등록·알림함·벨 배지·탭 라우팅·차단/본인 제외 모두 태스크에 매핑됨 ✅
- 타입 일관성: `routeFromNotification`(Task6) ↔ NotificationScreen/PushService 사용 시그니처 일치, `AppNotification` 필드 ↔ repository select 컬럼 일치, provider명(`hasUnreadNotificationsProvider`, `notificationListProvider`) 사용처 일치 ✅
- 외부 의존: Firebase 콘솔/APNs/서비스계정은 Phase 3 사용자 체크리스트로 분리, 코드 태스크가 이를 전제로 함 ✅
- 미구현(범위 외): 알림 on/off 설정, 좋아요 알림 — 설계대로 제외
```
