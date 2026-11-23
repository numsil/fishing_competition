# 리그 팀전 v2 — 팀 배정 방식 확장 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 팀 배정 주체를 리그 옵션(`호스트 배정` / `참가자 자율 선택`)으로 열고, 팀당 정원과 일괄 배정 UI로 100명·20팀 규모를 감당한다.

**Architecture:** `leagues` 에 컬럼 2개(`team_assign_mode`, `team_capacity`)를 더하고, `league_participants.team_id` 를 쓰는 모든 경로를 `SECURITY DEFINER` RPC 2개(`set_my_league_team`, `assign_league_teams`)로 통일한다. RLS는 건드리지 않는다. 정원·선택 가능 여부 판정은 Dart 순수 함수(`team_capacity.dart`)로 뽑아 SQL 규칙과 1:1로 대응시키고 단위 테스트한다. 점수 집계(`get_league_ranking`, `buildTeamRanking`)와 `posts` 는 수정하지 않는다.

**Tech Stack:** Flutter 3.41.9, Riverpod (`riverpod_annotation` codegen), freezed/json_serializable, go_router, lucide_icons, Supabase (PostgREST + plpgsql SECURITY DEFINER RPC), psql 직접 적용

**Spec:** `docs/superpowers/specs/2026-11-23-league-team-mode-design.md` (v2)

## Global Constraints

- 아키텍처: UI → Provider → Repository → Supabase. UI/Provider에서 직접 쿼리 금지.
- `select('*')` 금지. 필요한 컬럼만 명시.
- 반복문 안에서 쿼리 금지 (N+1). 일괄 배정은 RPC 1회.
- 집계는 RPC로, 클라 fold/reduce 금지 — **단 이미 받아둔 결과를 더하는 것은 예외** (스펙 3.5).
- 공통 위젯 필수: `AppButton`, `AppCard`, `AppTextField`, `UserAvatar`, `AppSnackBar`, `AppTextStyles`. `ElevatedButton`/`TextField`/`Container`+`BoxDecoration` 카드 직접 사용 금지.
- 색상은 `AppColors` 만. `Color(0xFF...)` 하드코딩 금지.
- `AppColors.teamColors` 키 문자열(`red/blue/green/amber/purple/pink`)은 `league_teams.color` 에 저장된 값이므로 **변경 금지**.
- **SQL Editor에서 직접 DDL 실행 금지.** 모든 스키마 변경은 마이그레이션 파일로 관리하고 psql로 적용한다.
- DB 비밀번호는 코드/문서에 절대 하드코딩 금지. 사용자가 직접 입력한다.
- `supabase db push` / `db pull` 금지 (Docker 필요). psql 직접 사용.
- push는 사용자가 명시적으로 요청할 때만. 기본 브랜치는 `develop`.
- `leagues.team_assign_mode` DB DEFAULT는 `'host'`, `leagues.team_capacity` DB DEFAULT는 `0`. **이 값을 바꾸면 기존 리그 전부의 동작이 바뀐다.**
- RPC는 모두 `SECURITY DEFINER` + `SET search_path TO 'public'`. 권한 판별은 `auth.uid()` (`current_user` 는 SECURITY DEFINER 안에서 no-op).
- 기존 테스트 40개가 전부 통과해야 한다 (`flutter test`).

## Review Focus

1. **`leagues` select 목록에 새 컬럼 2개가 빠지면 기능이 조용히 꺼진다.** v1에서 `is_team_mode` 를 5곳에 넣어야 했던 함정이 그대로 재발한다. 5곳 전부(`getLeague`/`getLeagues`/`getMyJoinedLeagues`/`my_league_repository` 2곳)에서 두 컬럼이 돌아오는지 — Task 2가 테스트로 고정한다.
2. **`team_capacity` DB DEFAULT를 `0` 이 아닌 값으로 넣으면 기존 리그 전부에 정원이 생긴다.** 12명 리그가 갑자기 "5/5 정원 마감"이 된다 — Task 1이 prod 실측으로 확인한다.
3. **정원을 낮춰 이미 초과한 팀(`6/5`)에서 사람이 *빠지는* 배정이 `TEAM_FULL` 로 거부되면 호스트가 복구할 수 없다.** 판정은 "초과 팀이 더 나빠지지 않는가" 여야 한다 — Task 3이 Dart 단위 테스트로, Task 1이 SQL 실측으로 고정한다.
4. **`host` 모드에서 참가자 배너가 그려지면 누를 수 없는 버튼을 보여주는 셈이다.** `set_my_league_team` 이 `SELF_PICK_DISABLED` 를 던지므로 배너는 아예 없어야 한다 — Task 7이 테스트로 고정한다.
5. **셔플 되돌리기 중 팀이 삭제되면 스냅샷이 영구히 실패하며 버튼이 남는다.** `TEAM_NOT_IN_LEAGUE` 를 받으면 스냅샷을 폐기해 버튼이 사라져야 한다 — Task 6이 테스트로 고정한다.

---

## File Structure

**신규**

| 파일 | 책임 |
|---|---|
| `supabase/migrations/20261123140000_league_team_assign_mode.sql` | 컬럼 2개, RPC 2개 신설, `shuffle_league_teams` 재생성 |
| `lib/features/league/data/team_capacity.dart` | 정원 판정 순수 함수 전부. SQL 규칙과 1:1 대응. 위젯/Supabase 의존 없음 |
| `lib/features/league/presentation/widgets/team_member_add_sheet.dart` | 팀원 다중 선택 바텀시트 (목업 ②) |
| `lib/features/league/presentation/widgets/league_my_team_banner.dart` | 팀 순위 탭 상단 내 팀 배너 (목업 ④) |
| `lib/features/league/presentation/screens/league_my_team_screen.dart` | 참가자용 내 팀 선택 화면 (목업 ⑤) |
| `test/features/league/team_capacity_test.dart` | 정원 로직 단위 테스트 |
| `test/features/league/team_assign_mode_test.dart` | 모델/배너 노출/스냅샷 폐기 규칙 테스트 |

**수정**

| 파일 | 변경 |
|---|---|
| `lib/features/league/data/league_model.dart` | `teamAssignMode`, `teamCapacity` 필드 2개 |
| `lib/features/league/data/league_team_model.dart` | `TeamAssignment` 클래스 추가 |
| `lib/features/league/data/league_repository.dart` | select 3곳, `createLeague`/`updateLeague`, RPC 메서드 3개 |
| `lib/features/my_league/data/my_league_repository.dart` | select 2곳 |
| `lib/features/league/presentation/screens/league_create_screen.dart` | 배정 방식 세그먼트 + 정원 스테퍼 |
| `lib/features/league/presentation/screens/league_team_manage_screen.dart` | 카드 기본 접힘, 정원 행, 팀 검색, 다중 추가, 셔플 되돌리기 |
| `lib/features/league/presentation/widgets/league_team_ranking_tab.dart` | 배너 1개 삽입 |
| `lib/core/router/app_router.dart` | `/league/my-team/:leagueId` 라우트 |
| `docs/REGRESSION_TEST.md` | v2 회귀 체크리스트 |

---

## Task 1: 마이그레이션 — 컬럼 2개 + RPC 2개 + 셔플 재생성

**Files:**
- Create: `supabase/migrations/20261123140000_league_team_assign_mode.sql`

**Interfaces:**
- Consumes: 기존 `public.is_league_host(uuid)` SECURITY DEFINER 헬퍼, 기존 `public.shuffle_league_teams(uuid) RETURNS void`
- Produces:
  - `leagues.team_assign_mode text NOT NULL DEFAULT 'host'` CHECK IN ('host','self')
  - `leagues.team_capacity int NOT NULL DEFAULT 0` CHECK >= 0
  - `public.set_my_league_team(p_league_id uuid, p_team_id uuid) RETURNS void`
  - `public.assign_league_teams(p_league_id uuid, p_assignments jsonb) RETURNS void`
  - `public.shuffle_league_teams(p_league_id uuid) RETURNS jsonb` (스냅샷 반환)

- [ ] **Step 1: 마이그레이션 파일 작성**

`supabase/migrations/20261123140000_league_team_assign_mode.sql`:

```sql
-- 리그 팀전 v2: 팀 배정 방식(호스트 배정 / 참가자 자율) + 팀당 정원
--
-- 설계: docs/superpowers/specs/2026-11-23-league-team-mode-design.md (v2)
--
-- RLS 를 완화하지 않는다. league_participants 는 status 컬럼으로 리그 참가
-- 승인을 관리하고, Postgres RLS 는 컬럼 단위 제한이 불가능하다. 본인 행
-- UPDATE 를 열면 참가자가 status 를 'pending' → 'approved' 로 바꿔 승인을
-- 스스로 통과할 수 있다. 따라서 참가자의 팀 변경은 team_id 한 컬럼만 쓰는
-- SECURITY DEFINER RPC 로만 가능하게 한다. (스펙 2.5)

-- ── 1. leagues 컬럼 2개 ──────────────────────────────────────
--
-- DEFAULT 는 반드시 'host' / 0 이어야 한다. 기존 리그와 신규 일반 리그가
-- v1 과 동일하게 동작해야 하기 때문이다. team_capacity 를 5 로 두면 기존
-- 12명 리그가 갑자기 "정원 마감" 상태가 된다.

ALTER TABLE public.leagues
  ADD COLUMN IF NOT EXISTS team_assign_mode text NOT NULL DEFAULT 'host';

ALTER TABLE public.leagues
  ADD COLUMN IF NOT EXISTS team_capacity int NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.leagues'::regclass
      AND conname = 'leagues_team_assign_mode_check'
  ) THEN
    ALTER TABLE public.leagues
      ADD CONSTRAINT leagues_team_assign_mode_check
      CHECK (team_assign_mode IN ('host', 'self'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.leagues'::regclass
      AND conname = 'leagues_team_capacity_check'
  ) THEN
    ALTER TABLE public.leagues
      ADD CONSTRAINT leagues_team_capacity_check
      CHECK (team_capacity >= 0);
  END IF;
END $$;

-- ── 2. 참가자 본인용: set_my_league_team ─────────────────────
--
-- team_id 컬럼만 UPDATE 한다. 다른 컬럼은 손대지 않는다.
-- 리그 status 는 검증하지 않는다 — v1 의 "진행 중 팀 이동 허용" 유지.

CREATE OR REPLACE FUNCTION public.set_my_league_team(
  p_league_id uuid,
  p_team_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_uid uuid;
  v_is_team_mode boolean;
  v_mode text;
  v_capacity int;
  v_members int;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT l.is_team_mode, l.team_assign_mode, l.team_capacity
  INTO v_is_team_mode, v_mode, v_capacity
  FROM public.leagues l WHERE l.id = p_league_id;

  IF v_mode IS NULL THEN
    RAISE EXCEPTION 'LEAGUE_NOT_FOUND';
  END IF;

  IF NOT v_is_team_mode OR v_mode <> 'self' THEN
    RAISE EXCEPTION 'SELF_PICK_DISABLED';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.league_participants lp
    WHERE lp.league_id = p_league_id
      AND lp.user_id = v_uid
      AND lp.status = 'approved'
  ) THEN
    RAISE EXCEPTION 'NOT_PARTICIPANT';
  END IF;

  IF p_team_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.league_teams t
      WHERE t.id = p_team_id AND t.league_id = p_league_id
    ) THEN
      RAISE EXCEPTION 'TEAM_NOT_IN_LEAGUE';
    END IF;

    -- 본인은 제외하고 센다. 이미 그 팀이면 자리를 한 칸 차지하고 있으므로
    -- 포함해서 세면 멱등 호출이 TEAM_FULL 로 실패한다.
    IF v_capacity > 0 THEN
      SELECT count(*) INTO v_members
      FROM public.league_participants lp
      WHERE lp.league_id = p_league_id
        AND lp.team_id = p_team_id
        AND lp.status = 'approved'
        AND lp.user_id <> v_uid;

      IF v_members >= v_capacity THEN
        RAISE EXCEPTION 'TEAM_FULL';
      END IF;
    END IF;
  END IF;

  -- p_team_id IS NULL (미배정으로) 은 정원 검증 없이 통과한다.
  UPDATE public.league_participants
  SET team_id = p_team_id
  WHERE league_id = p_league_id AND user_id = v_uid;
END;
$$;

REVOKE ALL ON FUNCTION public.set_my_league_team(uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.set_my_league_team(uuid, uuid) TO authenticated;

-- ── 3. 호스트용 일괄 배정: assign_league_teams ───────────────
--
-- 이 함수 하나가 세 UI 를 처리한다: 다중 추가 / 셔플 되돌리기 / 단건 이동.
-- 정원 검증이 한 곳에만 있어야 하므로 단건 이동도 이 함수를 쓴다.
--
-- 정원 판정은 "적용 후 상태" 기준이다. 한 번에 3명을 넣는 요청이 개별로는
-- 각각 정원 안이어도 합치면 넘을 수 있다. 동시에, 정원을 낮춰 이미 초과한
-- 팀(6/5)에서 사람이 빠지는 배정은 허용해야 한다 → 위반 조건은
-- "적용 후 정원 초과 AND 적용 전보다 줄지 않음".

CREATE OR REPLACE FUNCTION public.assign_league_teams(
  p_league_id uuid,
  p_assignments jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_capacity int;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT l.team_capacity INTO v_capacity
  FROM public.leagues l WHERE l.id = p_league_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'LEAGUE_NOT_FOUND';
  END IF;

  IF NOT public.is_league_host(p_league_id) THEN
    RAISE EXCEPTION 'NOT_LEAGUE_HOST';
  END IF;

  IF p_assignments IS NULL OR jsonb_typeof(p_assignments) <> 'array' THEN
    RAISE EXCEPTION 'TEAM_NOT_IN_LEAGUE';
  END IF;

  IF jsonb_array_length(p_assignments) = 0 THEN
    RETURN;
  END IF;

  CREATE TEMP TABLE _incoming ON COMMIT DROP AS
  SELECT (e->>'user_id')::uuid AS user_id,
         NULLIF(e->>'team_id', '')::uuid AS team_id
  FROM jsonb_array_elements(p_assignments) e;

  -- 모든 user_id 가 그 리그의 승인 참가자인지
  IF EXISTS (
    SELECT 1 FROM _incoming i
    WHERE NOT EXISTS (
      SELECT 1 FROM public.league_participants lp
      WHERE lp.league_id = p_league_id
        AND lp.user_id = i.user_id
        AND lp.status = 'approved'
    )
  ) THEN
    RAISE EXCEPTION 'NOT_PARTICIPANT';
  END IF;

  -- 모든 non-null team_id 가 그 리그의 팀인지
  IF EXISTS (
    SELECT 1 FROM _incoming i
    WHERE i.team_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public.league_teams t
        WHERE t.id = i.team_id AND t.league_id = p_league_id
      )
  ) THEN
    RAISE EXCEPTION 'TEAM_NOT_IN_LEAGUE';
  END IF;

  -- 적용 후 상태로 정원 검증
  IF v_capacity > 0 AND EXISTS (
    WITH before AS (
      SELECT lp.user_id, lp.team_id
      FROM public.league_participants lp
      WHERE lp.league_id = p_league_id AND lp.status = 'approved'
    ),
    after AS (
      SELECT b.user_id,
             CASE WHEN i.user_id IS NOT NULL THEN i.team_id ELSE b.team_id END
               AS team_id
      FROM before b
      LEFT JOIN _incoming i ON i.user_id = b.user_id
    ),
    before_counts AS (
      SELECT team_id, count(*)::int AS n FROM before
      WHERE team_id IS NOT NULL GROUP BY team_id
    ),
    after_counts AS (
      SELECT team_id, count(*)::int AS n FROM after
      WHERE team_id IS NOT NULL GROUP BY team_id
    )
    SELECT 1 FROM after_counts a
    LEFT JOIN before_counts b ON b.team_id = a.team_id
    WHERE a.n > v_capacity
      AND a.n >= COALESCE(b.n, 0)
  ) THEN
    RAISE EXCEPTION 'TEAM_FULL';
  END IF;

  UPDATE public.league_participants lp
  SET team_id = i.team_id
  FROM _incoming i
  WHERE lp.league_id = p_league_id
    AND lp.user_id = i.user_id;

  DROP TABLE _incoming;
END;
$$;

REVOKE ALL ON FUNCTION public.assign_league_teams(uuid, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.assign_league_teams(uuid, jsonb) TO authenticated;

-- ── 4. shuffle_league_teams: 반환 타입 변경 ──────────────────
--
-- RETURNS void → jsonb. 반환 타입이 바뀌므로 CREATE OR REPLACE 가 불가능하다.
-- 되돌리기용 "직전 배정 스냅샷"을 돌려준다. 스냅샷은 DB 에 저장하지 않는다 —
-- 화면 state 에만 두고, 커버 범위는 "방금 셔플이 실수였다" 하나다. (스펙 3.6)

DROP FUNCTION IF EXISTS public.shuffle_league_teams(uuid);

CREATE FUNCTION public.shuffle_league_teams(p_league_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_team_count int;
  v_capacity int;
  v_approved int;
  v_snapshot jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT l.team_capacity INTO v_capacity
  FROM public.leagues l WHERE l.id = p_league_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'LEAGUE_NOT_FOUND';
  END IF;

  IF NOT public.is_league_host(p_league_id) THEN
    RAISE EXCEPTION 'NOT_LEAGUE_HOST';
  END IF;

  SELECT count(*) INTO v_team_count
  FROM public.league_teams WHERE league_id = p_league_id;

  IF v_team_count = 0 THEN
    RAISE EXCEPTION 'NO_TEAMS';
  END IF;

  SELECT count(*) INTO v_approved
  FROM public.league_participants
  WHERE league_id = p_league_id AND status = 'approved';

  -- 라운드로빈은 균등 분배이므로 총량만 맞으면 어떤 팀도 정원을 넘지 않는다.
  IF v_capacity > 0 AND v_approved > v_team_count * v_capacity THEN
    RAISE EXCEPTION 'CAPACITY_TOO_SMALL';
  END IF;

  -- 섞기 전 스냅샷 (미배정은 team_id: null)
  SELECT COALESCE(
    jsonb_agg(jsonb_build_object('user_id', lp.user_id, 'team_id', lp.team_id)),
    '[]'::jsonb
  )
  INTO v_snapshot
  FROM public.league_participants lp
  WHERE lp.league_id = p_league_id AND lp.status = 'approved';

  -- 승인된 참가자를 무작위 순서로 세운 뒤 팀에 라운드로빈 배정 → 균등 분배
  WITH shuffled AS (
    SELECT lp.user_id,
           (row_number() OVER (ORDER BY random()) - 1) AS seq
    FROM public.league_participants lp
    WHERE lp.league_id = p_league_id AND lp.status = 'approved'
  ),
  teams AS (
    SELECT t.id,
           (row_number() OVER (ORDER BY t.sort_order, t.created_at) - 1) AS idx
    FROM public.league_teams t
    WHERE t.league_id = p_league_id
  )
  UPDATE public.league_participants lp
  SET team_id = teams.id
  FROM shuffled, teams
  WHERE lp.league_id = p_league_id
    AND lp.user_id = shuffled.user_id
    AND teams.idx = (shuffled.seq % v_team_count);

  RETURN v_snapshot;
END;
$$;

REVOKE ALL ON FUNCTION public.shuffle_league_teams(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.shuffle_league_teams(uuid) TO authenticated;
```

- [ ] **Step 2: prod 적용 전 현재 상태 스냅샷**

Run (사용자에게 DB 비밀번호를 요청해 `PGPASSWORD` 로 전달. 파일/문서에 쓰지 않는다):

```bash
PGPASSWORD="$DB_PW" psql "postgresql://postgres.zpcmpfrswlbnqkqrmvxu@aws-1-ap-south-1.pooler.supabase.com:5432/postgres" -c "
select count(*) as leagues, count(*) filter (where is_team_mode) as team_leagues from public.leagues;
select count(*) as participants, count(team_id) as assigned from public.league_participants;
select count(*) as teams from public.league_teams;
select pg_get_function_result(oid) as shuffle_returns from pg_proc where proname='shuffle_league_teams';
"
```

Expected: `leagues` 9 / `team_leagues` 1, `participants` 60±, `assigned` 15, `teams` 3, `shuffle_returns` = `void`.
(정확한 수는 다를 수 있다. **적용 후와 비교하기 위한 기준값**이므로 출력을 기록해 둔다)

- [ ] **Step 3: 마이그레이션 적용**

Run:

```bash
PGPASSWORD="$DB_PW" psql "postgresql://postgres.zpcmpfrswlbnqkqrmvxu@aws-1-ap-south-1.pooler.supabase.com:5432/postgres" -v ON_ERROR_STOP=1 -f supabase/migrations/20261123140000_league_team_assign_mode.sql
```

Expected: `ALTER TABLE` ×2, `DO`, `CREATE FUNCTION` ×3, `REVOKE`/`GRANT` ×6, `DROP FUNCTION`. 에러 없음.

- [ ] **Step 4: 기본값 검증 — 기존 리그가 전부 host/0 인지 (Review Focus 2)**

Run:

```bash
PGPASSWORD="$DB_PW" psql "postgresql://postgres.zpcmpfrswlbnqkqrmvxu@aws-1-ap-south-1.pooler.supabase.com:5432/postgres" -c "
select team_assign_mode, team_capacity, count(*) from public.leagues group by 1,2 order by 3 desc;
select count(*) as participants, count(team_id) as assigned from public.league_participants;
select pg_get_function_result(oid) as shuffle_returns from pg_proc where proname='shuffle_league_teams';
"
```

Expected: 한 행만 나온다 — `host | 0 | <Step 2의 leagues 수>`. `assigned` 는 Step 2와 동일(15). `shuffle_returns` = `jsonb`.

**`host|0` 외의 행이 나오거나 `assigned` 가 변했으면 즉시 중단하고 원인을 찾는다.**

- [ ] **Step 5: RPC 동작 검증 — 실패 케이스 (SAVEPOINT 필수)**

트랜잭션 안에 예상 에러가 여러 개 있으면 첫 에러에서 트랜잭션이 중단되어 이후 테스트가 전부 건너뛰어진다. 각 실패 문장을 `SAVEPOINT` 로 감싼다.

Run (`$HOST` = `252a84a6-bbe6-456e-aa75-f6cf4ba2198a` 빌런, `$LEAGUE` = `57aafd9d-286f-4772-aa64-aa04577d7447`):

```bash
PGPASSWORD="$DB_PW" psql "postgresql://postgres.zpcmpfrswlbnqkqrmvxu@aws-1-ap-south-1.pooler.supabase.com:5432/postgres" <<'SQL'
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
  '{"sub":"252a84a6-bbe6-456e-aa75-f6cf4ba2198a","role":"authenticated"}', true);

-- (a) 자율 모드가 아니면 SELF_PICK_DISABLED
SAVEPOINT s1;
DO $$ BEGIN
  PERFORM public.set_my_league_team(
    '57aafd9d-286f-4772-aa64-aa04577d7447',
    (SELECT id FROM public.league_teams
     WHERE league_id='57aafd9d-286f-4772-aa64-aa04577d7447' LIMIT 1));
  RAISE NOTICE 'FAIL: 예외가 나오지 않았다';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK (a) %', SQLERRM; END $$;
ROLLBACK TO SAVEPOINT s1;

-- (b) 자율 모드로 바꾸면 성공
UPDATE public.leagues SET team_assign_mode='self'
WHERE id='57aafd9d-286f-4772-aa64-aa04577d7447';
SELECT public.set_my_league_team(
  '57aafd9d-286f-4772-aa64-aa04577d7447',
  (SELECT id FROM public.league_teams
   WHERE league_id='57aafd9d-286f-4772-aa64-aa04577d7447'
   ORDER BY sort_order LIMIT 1));
SELECT 'OK (b) 내 팀 =' AS r, t.name
FROM public.league_participants lp JOIN public.league_teams t ON t.id=lp.team_id
WHERE lp.league_id='57aafd9d-286f-4772-aa64-aa04577d7447'
  AND lp.user_id='252a84a6-bbe6-456e-aa75-f6cf4ba2198a';

-- (c) 같은 팀 재호출은 멱등 (TEAM_FULL 이 나오면 안 된다)
UPDATE public.leagues SET team_capacity=5
WHERE id='57aafd9d-286f-4772-aa64-aa04577d7447';
SELECT public.set_my_league_team(
  '57aafd9d-286f-4772-aa64-aa04577d7447',
  (SELECT id FROM public.league_teams
   WHERE league_id='57aafd9d-286f-4772-aa64-aa04577d7447'
   ORDER BY sort_order LIMIT 1));
SELECT 'OK (c) 멱등 통과' AS r;

-- (d) 정원이 찬 팀은 TEAM_FULL (A팀은 5명 = capacity 5)
SAVEPOINT s4;
DO $$
DECLARE v_full uuid;
BEGIN
  SELECT t.id INTO v_full FROM public.league_teams t
  WHERE t.league_id='57aafd9d-286f-4772-aa64-aa04577d7447'
    AND t.sort_order=1;  -- B팀 (빌런이 없는 팀, 5명)
  PERFORM public.set_my_league_team('57aafd9d-286f-4772-aa64-aa04577d7447', v_full);
  RAISE NOTICE 'FAIL: TEAM_FULL 이 나오지 않았다';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK (d) %', SQLERRM; END $$;
ROLLBACK TO SAVEPOINT s4;

-- (e) 미배정으로는 정원과 무관하게 항상 성공
SELECT public.set_my_league_team('57aafd9d-286f-4772-aa64-aa04577d7447', NULL);
SELECT 'OK (e) 미배정, team_id =' AS r, team_id
FROM public.league_participants
WHERE league_id='57aafd9d-286f-4772-aa64-aa04577d7447'
  AND user_id='252a84a6-bbe6-456e-aa75-f6cf4ba2198a';

ROLLBACK;
SQL
```

Expected: `OK (a) SELF_PICK_DISABLED`, `OK (b) 내 팀 = A팀`, `OK (c) 멱등 통과`, `OK (d) TEAM_FULL`, `OK (e) 미배정, team_id = (null)`.
`FAIL:` 이 한 줄도 없어야 한다. 마지막 `ROLLBACK` 으로 prod 데이터는 변하지 않는다.

- [ ] **Step 6: 정원 초과 팀에서 사람이 빠지는 배정이 허용되는지 (Review Focus 3)**

Run:

```bash
PGPASSWORD="$DB_PW" psql "postgresql://postgres.zpcmpfrswlbnqkqrmvxu@aws-1-ap-south-1.pooler.supabase.com:5432/postgres" <<'SQL'
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
  '{"sub":"252a84a6-bbe6-456e-aa75-f6cf4ba2198a","role":"authenticated"}', true);

-- A팀 5명인데 정원을 3으로 낮춘다 → 5/3 초과 상태
UPDATE public.leagues SET team_capacity=3
WHERE id='57aafd9d-286f-4772-aa64-aa04577d7447';

-- (f) 초과 팀에서 1명을 빼는 배정은 허용 (5 → 4, 여전히 3 초과지만 줄었다)
SELECT public.assign_league_teams(
  '57aafd9d-286f-4772-aa64-aa04577d7447',
  jsonb_build_array(jsonb_build_object(
    'user_id', '252a84a6-bbe6-456e-aa75-f6cf4ba2198a', 'team_id', NULL)));
SELECT 'OK (f) 초과 팀에서 제외 허용. A팀 =' AS r, count(*)
FROM public.league_participants lp
JOIN public.league_teams t ON t.id = lp.team_id
WHERE t.league_id='57aafd9d-286f-4772-aa64-aa04577d7447' AND t.sort_order=0;

-- (g) 초과 팀에 더 넣는 배정은 거부
SAVEPOINT s7;
DO $$
DECLARE v_a uuid; v_victim uuid;
BEGIN
  SELECT id INTO v_a FROM public.league_teams
  WHERE league_id='57aafd9d-286f-4772-aa64-aa04577d7447' AND sort_order=0;
  SELECT user_id INTO v_victim FROM public.league_participants
  WHERE league_id='57aafd9d-286f-4772-aa64-aa04577d7447'
    AND status='approved' AND team_id IS DISTINCT FROM v_a LIMIT 1;
  PERFORM public.assign_league_teams(
    '57aafd9d-286f-4772-aa64-aa04577d7447',
    jsonb_build_array(jsonb_build_object('user_id', v_victim, 'team_id', v_a)));
  RAISE NOTICE 'FAIL: TEAM_FULL 이 나오지 않았다';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK (g) %', SQLERRM; END $$;
ROLLBACK TO SAVEPOINT s7;

-- (h) 정원보다 작은 팀 수로 셔플하면 CAPACITY_TOO_SMALL (15명, 3팀, 정원 3 → 9 < 15)
SAVEPOINT s8;
DO $$ BEGIN
  PERFORM public.shuffle_league_teams('57aafd9d-286f-4772-aa64-aa04577d7447');
  RAISE NOTICE 'FAIL: CAPACITY_TOO_SMALL 이 나오지 않았다';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK (h) %', SQLERRM; END $$;
ROLLBACK TO SAVEPOINT s8;

-- (i) 정원을 풀면 셔플이 스냅샷을 돌려준다
UPDATE public.leagues SET team_capacity=0
WHERE id='57aafd9d-286f-4772-aa64-aa04577d7447';
SELECT 'OK (i) 스냅샷 길이 =' AS r,
       jsonb_array_length(public.shuffle_league_teams(
         '57aafd9d-286f-4772-aa64-aa04577d7447'));

ROLLBACK;
SQL
```

Expected: `OK (f) ... A팀 = 4`, `OK (g) TEAM_FULL`, `OK (h) CAPACITY_TOO_SMALL`, `OK (i) 스냅샷 길이 = 15`.
`FAIL:` 없어야 한다.

- [ ] **Step 7: 비호스트 차단 검증**

Run:

```bash
PGPASSWORD="$DB_PW" psql "postgresql://postgres.zpcmpfrswlbnqkqrmvxu@aws-1-ap-south-1.pooler.supabase.com:5432/postgres" <<'SQL'
BEGIN;
SET LOCAL ROLE authenticated;
-- 느믄이 (호스트 아님, admin 아님)
SELECT set_config('request.jwt.claims',
  '{"sub":"b544d66d-cb7a-4b54-9bdc-0c8ff02f42d1","role":"authenticated"}', true);

SAVEPOINT s1;
DO $$ BEGIN
  PERFORM public.assign_league_teams('57aafd9d-286f-4772-aa64-aa04577d7447', '[]'::jsonb);
  RAISE NOTICE 'NOTE: 빈 배열은 권한 검사 전 조기 반환이 아니어야 한다';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK (j) %', SQLERRM; END $$;
ROLLBACK TO SAVEPOINT s1;

SAVEPOINT s2;
DO $$ BEGIN
  PERFORM public.shuffle_league_teams('57aafd9d-286f-4772-aa64-aa04577d7447');
  RAISE NOTICE 'FAIL: NOT_LEAGUE_HOST 가 나오지 않았다';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK (k) %', SQLERRM; END $$;
ROLLBACK TO SAVEPOINT s2;

ROLLBACK;
SQL
```

Expected: `OK (j) NOT_LEAGUE_HOST`, `OK (k) NOT_LEAGUE_HOST`.
(j)가 `NOTE:` 로 나오면 **권한 검사가 빈 배열 조기 반환보다 뒤에 있다는 뜻**이다. 위 SQL은 `is_league_host` 검사를 `jsonb_array_length = 0` 조기 반환보다 **먼저** 두었으므로 `OK (j)` 가 나와야 한다. `NOTE:` 가 나오면 함수의 검사 순서를 고친다.

- [ ] **Step 8: PostgREST embed 검증 (PGRST201 재발 방지)**

과거 FK 추가로 embed 모호성 장애가 있었다. v2는 FK를 추가하지 않지만 `leagues` select 에 컬럼이 2개 늘어난다.

Run (`$ANON` = `SUPABASE_ANON_KEY`, 코드의 select 문자열을 그대로 복사해서 호출):

```bash
BASE="https://zpcmpfrswlbnqkqrmvxu.supabase.co/rest/v1"
for q in \
  "leagues?select=id,status,is_team_mode,team_assign_mode,team_capacity&limit=1" \
  "league_teams?select=id,league_id,name,color,sort_order,league_participants(user_id)&limit=1" \
  "league_participants?select=user_id,team_id&limit=1" \
  "league_participants?select=id,users(username,avatar_url)&limit=1" \
; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/$q" \
    -H "apikey: $ANON" -H "Authorization: Bearer $ANON")
  echo "$code  $q"
done
```

Expected: 네 줄 모두 `200`. `300` 이면 PGRST201 embed 모호성이다.

- [ ] **Step 9: FK 개수 불변 확인**

Run:

```bash
PGPASSWORD="$DB_PW" psql "postgresql://postgres.zpcmpfrswlbnqkqrmvxu@aws-1-ap-south-1.pooler.supabase.com:5432/postgres" -c "
select conname, confdeltype from pg_constraint
where conrelid='public.league_participants'::regclass and contype='f' order by conname;
select count(*) as users_fk_count from pg_constraint
where conrelid='public.league_participants'::regclass and contype='f'
  and confrelid='public.users'::regclass;
"
```

Expected: `users_fk_count` = 1. `league_participants_team_id_fkey` 의 `confdeltype` = `n` (SET NULL).

- [ ] **Step 10: Commit**

```bash
git add supabase/migrations/20261123140000_league_team_assign_mode.sql
git commit -m "feat(league): 팀 배정 방식·정원 컬럼 + RPC 2개 (v2 DB)

- leagues.team_assign_mode ('host'|'self'), leagues.team_capacity (0=무제한)
- set_my_league_team: 참가자 본인, team_id 컬럼만 UPDATE
- assign_league_teams: 호스트 일괄 배정, 정원은 '적용 후 상태' 기준
- shuffle_league_teams: RETURNS jsonb (직전 스냅샷) + CAPACITY_TOO_SMALL

RLS 는 건드리지 않는다 — 본인 행 UPDATE 를 열면 status 셀프 승인이 뚫린다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 2: 모델 / 리포지토리 — 컬럼 2개를 5개 select 전부에 싣는다

**Files:**
- Modify: `lib/features/league/data/league_model.dart`
- Modify: `lib/features/league/data/league_team_model.dart`
- Modify: `lib/features/league/data/league_repository.dart:161` (getLeague select), `:186` (getLeagues select), `:239` (getMyJoinedLeagues select), `:106-151` (createLeague), `:523-571` (updateLeague), `:625-640` (assignParticipantTeam), `:642-647` (shuffleLeagueTeams)
- Modify: `lib/features/my_league/data/my_league_repository.dart:29`, `:37`
- Test: `test/features/league/team_assign_mode_test.dart`

**Interfaces:**
- Consumes: Task 1의 RPC 3개 — `set_my_league_team(p_league_id, p_team_id)`, `assign_league_teams(p_league_id, p_assignments)`, `shuffle_league_teams(p_league_id) RETURNS jsonb`
- Produces:
  - `League.teamAssignMode` (`String`, `@Default('host')`, json key `team_assign_mode`)
  - `League.teamCapacity` (`int`, `@Default(0)`, json key `team_capacity`)
  - `League.isSelfPick` (getter: `isTeamMode && teamAssignMode == 'self'`)
  - `TeamAssignment({required String userId, String? teamId})` + `toJson()` + `TeamAssignment.fromJson(Map)`
  - `LeagueRepository.assignLeagueTeams({required String leagueId, required List<TeamAssignment> assignments})`
  - `LeagueRepository.setMyLeagueTeam({required String leagueId, String? teamId})`
  - `LeagueRepository.shuffleLeagueTeams(String leagueId) → Future<List<TeamAssignment>>`
  - `LeagueRepository.assignParticipantTeam({required String leagueId, required String userId, String? teamId})` (시그니처 유지, 내부가 RPC로 바뀜)
  - `createLeague`/`updateLeague` 에 `teamAssignMode` / `teamCapacity` 파라미터

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test/features/league/team_assign_mode_test.dart` (신규):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fishing_competition/features/league/data/league_model.dart';
import 'package:fishing_competition/features/league/data/league_team_model.dart';

Map<String, dynamic> leagueJson(Map<String, dynamic> extra) => {
      'id': 'L',
      'host_id': 'H',
      'title': '테스트',
      'location': '백곡지',
      'start_time': '2026-11-23T00:00:00Z',
      'end_time': '2026-11-30T00:00:00Z',
      'created_at': '2026-11-22T00:00:00Z',
      ...extra,
    };

void main() {
  group('League 팀 배정 필드', () {
    test('컬럼이 없으면 host / 0 으로 떨어진다 (기존 리그 보호)', () {
      final l = League.fromJson(leagueJson({}));
      expect(l.teamAssignMode, 'host');
      expect(l.teamCapacity, 0);
      expect(l.isTeamMode, isFalse);
      expect(l.isSelfPick, isFalse);
    });

    test('team_assign_mode / team_capacity 를 읽는다', () {
      final l = League.fromJson(leagueJson({
        'is_team_mode': true,
        'team_assign_mode': 'self',
        'team_capacity': 5,
      }));
      expect(l.teamAssignMode, 'self');
      expect(l.teamCapacity, 5);
      expect(l.isSelfPick, isTrue);
    });

    test('팀전이 아니면 self 여도 isSelfPick 은 false', () {
      // 팀전을 끈 뒤 되돌릴 수 있게 team_assign_mode 는 보존된다.
      // 그 값만 보고 배너를 그리면 개인전 리그에 배너가 뜬다.
      final l = League.fromJson(leagueJson({
        'is_team_mode': false,
        'team_assign_mode': 'self',
      }));
      expect(l.isSelfPick, isFalse);
    });
  });

  group('TeamAssignment', () {
    test('미배정은 team_id null 로 직렬화된다', () {
      expect(const TeamAssignment(userId: 'u1').toJson(),
          {'user_id': 'u1', 'team_id': null});
    });

    test('RPC 가 돌려준 스냅샷을 역직렬화한다', () {
      final rows = [
        {'user_id': 'u1', 'team_id': 't1'},
        {'user_id': 'u2', 'team_id': null},
      ];
      final parsed = rows
          .map((r) => TeamAssignment.fromJson(r))
          .toList(growable: false);
      expect(parsed[0].teamId, 't1');
      expect(parsed[1].teamId, isNull);
    });

    test('왕복(toJson → fromJson)에서 값이 유지된다', () {
      const a = TeamAssignment(userId: 'u1', teamId: 't9');
      final b = TeamAssignment.fromJson(a.toJson());
      expect(b.userId, 'u1');
      expect(b.teamId, 't9');
    });
  });
}
```

- [ ] **Step 2: 테스트가 실패하는 것을 확인한다**

Run: `flutter test test/features/league/team_assign_mode_test.dart`
Expected: FAIL — `The getter 'teamAssignMode' isn't defined for the class 'League'` 와 `Undefined name 'TeamAssignment'` 컴파일 에러.

- [ ] **Step 3: `League` 에 필드 2개 + getter 추가**

`lib/features/league/data/league_model.dart` — `isTeamMode` 줄(29) 바로 아래에 추가:

```dart
    @JsonKey(name: 'is_team_mode') @Default(false) bool isTeamMode,
    @JsonKey(name: 'team_assign_mode') @Default('host') String teamAssignMode,
    @JsonKey(name: 'team_capacity') @Default(0) int teamCapacity,
```

그리고 `factory League.fromJson` 아래에 getter 를 더한다 (freezed 클래스에 메서드를 추가하려면 `abstract class` 본문에 쓴다):

```dart
  factory League.fromJson(Map<String, dynamic> json) => _$LeagueFromJson(json);

  /// 참가자가 직접 팀을 고를 수 있는 리그인가.
  ///
  /// 팀전을 끄면 team_assign_mode 는 보존되므로(되돌릴 수 있게),
  /// isTeamMode 를 같이 봐야 개인전 리그에 배너가 뜨지 않는다.
  bool get isSelfPick => isTeamMode && teamAssignMode == 'self';
```

- [ ] **Step 4: `TeamAssignment` 추가**

`lib/features/league/data/league_team_model.dart` 끝에 추가:

```dart
/// 한 사람의 팀 배정 1건. `assign_league_teams` RPC 의 입력 원소이고,
/// `shuffle_league_teams` 가 돌려주는 스냅샷의 원소이기도 하다.
///
/// `teamId == null` 은 "미배정"이다.
class TeamAssignment {
  const TeamAssignment({required this.userId, this.teamId});

  final String userId;
  final String? teamId;

  Map<String, dynamic> toJson() => {'user_id': userId, 'team_id': teamId};

  factory TeamAssignment.fromJson(Map<String, dynamic> json) => TeamAssignment(
        userId: json['user_id'] as String,
        teamId: json['team_id'] as String?,
      );
}
```

- [ ] **Step 5: 코드 생성**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `Succeeded after ...`. `league_model.freezed.dart` / `.g.dart` 에 `teamAssignMode` / `teamCapacity` 가 생긴다.

- [ ] **Step 6: 테스트가 통과하는 것을 확인한다**

Run: `flutter test test/features/league/team_assign_mode_test.dart`
Expected: PASS, 6/6.

- [ ] **Step 7: select 목록 5곳에 컬럼 2개를 넣는다 (Review Focus 1)**

`lib/features/league/data/league_repository.dart:161` (`getLeague`):

```dart
          'allow_gallery, is_team_mode, team_assign_mode, team_capacity, '
          'intro_image_urls, created_at, '
```

`:186` (`getLeagues`) — `is_team_mode,` 뒤에 추가:

```dart
        .select('id, host_id, title, short_description, location, status, start_time, end_time, entry_fee, max_participants, is_public, is_team_mode, team_assign_mode, team_capacity, created_at, league_participants(count), users!host_id(username)')
```

`:239` (`getMyJoinedLeagues`):

```dart
        .select('leagues(id, host_id, title, short_description, location, status, start_time, end_time, entry_fee, max_participants, is_public, is_team_mode, team_assign_mode, team_capacity, created_at)')
```

`lib/features/my_league/data/my_league_repository.dart:29`:

```dart
        .select('id, host_id, title, location, status, start_time, end_time, max_participants, is_public, is_team_mode, team_assign_mode, team_capacity, created_at, league_participants(count)')
```

`:37`:

```dart
        .select('leagues(id, host_id, title, location, status, start_time, end_time, max_participants, is_public, is_team_mode, team_assign_mode, team_capacity, created_at, league_participants(count))')
```

- [ ] **Step 8: 누락이 없는지 grep 으로 확인한다 (Review Focus 1)**

Run:

```bash
grep -rn "is_team_mode" lib/features/league/data/league_repository.dart lib/features/my_league/data/my_league_repository.dart | grep -v "team_assign_mode"
```

Expected: **출력 없음**(exit 1). `is_team_mode` 가 나오는데 `team_assign_mode` 가 같은 줄에 없는 select 가 하나도 없어야 한다.
(`league_repository.dart:149` 의 `'is_team_mode': isTeamMode,` 는 insert 맵이지 select 가 아니다 — Step 9에서 함께 고친다. 이 grep 에 걸리면 Step 9 를 먼저 끝내고 다시 돌린다.)

- [ ] **Step 9: `createLeague` / `updateLeague` 파라미터 추가**

`createLeague` 시그니처에 `isTeamMode` 바로 뒤로:

```dart
    bool isTeamMode = false,
    String teamAssignMode = 'host',
    int teamCapacity = 0,
```

insert 맵의 `'is_team_mode': isTeamMode,` 뒤로:

```dart
      'is_team_mode': isTeamMode,
      'team_assign_mode': teamAssignMode,
      'team_capacity': teamCapacity,
```

`updateLeague` 시그니처에 `bool? isTeamMode,` 뒤로:

```dart
    bool? isTeamMode,
    String? teamAssignMode,
    int? teamCapacity,
```

본문의 `if (isTeamMode != null) ...` 뒤로:

```dart
    if (isTeamMode != null) update['is_team_mode'] = isTeamMode;
    if (teamAssignMode != null) update['team_assign_mode'] = teamAssignMode;
    if (teamCapacity != null) update['team_capacity'] = teamCapacity;
```

- [ ] **Step 10: RPC 메서드 3개로 교체**

`league_repository.dart` 의 `assignParticipantTeam` / `shuffleLeagueTeams` 를 아래로 **대체**한다 (`assignParticipantTeam` 의 시그니처는 그대로 유지해야 기존 호출부가 컴파일된다):

```dart
  /// 호스트 일괄 배정. 다중 추가 / 셔플 되돌리기 / 단건 이동이 모두 이 경로다.
  ///
  /// 정원 검증이 한 곳(RPC)에만 있어야 하므로 league_participants 직접
  /// UPDATE 를 쓰지 않는다.
  Future<void> assignLeagueTeams({
    required String leagueId,
    required List<TeamAssignment> assignments,
  }) async {
    if (assignments.isEmpty) return;
    await _supabase.rpc('assign_league_teams', params: {
      'p_league_id': leagueId,
      'p_assignments': assignments.map((a) => a.toJson()).toList(),
    });
  }

  /// teamId == null 이면 미배정으로 되돌린다. 단건 = 1개 원소 일괄 배정.
  Future<void> assignParticipantTeam({
    required String leagueId,
    required String userId,
    String? teamId,
  }) {
    return assignLeagueTeams(
      leagueId: leagueId,
      assignments: [TeamAssignment(userId: userId, teamId: teamId)],
    );
  }

  /// 참가자 본인의 팀 선택. 자율 선택 리그에서만 통한다.
  /// teamId == null 이면 팀에서 나간다(미배정).
  Future<void> setMyLeagueTeam({
    required String leagueId,
    String? teamId,
  }) async {
    await _supabase.rpc('set_my_league_team', params: {
      'p_league_id': leagueId,
      'p_team_id': teamId,
    });
  }

  /// 셔플하고 **직전** 배정 스냅샷을 돌려준다. 호출자가 이 값을 들고 있다가
  /// `되돌리기` 에서 assignLeagueTeams 로 그대로 되돌린다.
  Future<List<TeamAssignment>> shuffleLeagueTeams(String leagueId) async {
    final rows = await _supabase.rpc(
      'shuffle_league_teams',
      params: {'p_league_id': leagueId},
    );
    if (rows is! List) return const [];
    return rows
        .map((r) => TeamAssignment.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }
```

- [ ] **Step 11: 전체 테스트 + 정적 분석**

Run: `flutter analyze lib test 2>&1 | tail -20 && flutter test`
Expected: `analyze` 에 새 에러 없음(기존 info/warning 은 그대로). `flutter test` → `+46: All tests passed!` (40 + 신규 6).

- [ ] **Step 12: Commit**

```bash
git add lib/features/league/data/league_model.dart \
        lib/features/league/data/league_model.freezed.dart \
        lib/features/league/data/league_model.g.dart \
        lib/features/league/data/league_team_model.dart \
        lib/features/league/data/league_repository.dart \
        lib/features/my_league/data/my_league_repository.dart \
        test/features/league/team_assign_mode_test.dart
git commit -m "feat(league): League 에 배정 방식·정원 + 팀 쓰기를 RPC 로 통일

- teamAssignMode / teamCapacity 필드, isSelfPick getter
- select 목록 5곳 전부에 컬럼 2개 추가 (빠지면 기능이 조용히 꺼진다)
- assignLeagueTeams / setMyLeagueTeam / shuffleLeagueTeams(스냅샷 반환)
- assignParticipantTeam 은 시그니처 유지, 내부만 1건 일괄 배정으로

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: 정원 판정 순수 함수 (`team_capacity.dart`)

SQL 의 정원 규칙을 Dart 쪽에서도 한 곳에만 둔다. UI 가 비활성 처리를 직접 계산하면 RPC 규칙과 어긋나고, 어긋남을 테스트할 수 없다.

**Files:**
- Create: `lib/features/league/data/team_capacity.dart`
- Test: `test/features/league/team_capacity_test.dart`

**Interfaces:**
- Consumes: 없음 (순수 함수. `LeagueTeam` 도 쓰지 않는다 — int 만 받는다)
- Produces:
  - `bool isTeamFull({required int capacity, required int memberCount})`
  - `bool isOverCapacity({required int capacity, required int memberCount})`
  - `int remainingSlots({required int capacity, required int memberCount})` — 무제한이면 `-1`
  - `String capacityLabel({required int capacity, required int memberCount})`
  - `bool shuffleFitsCapacity({required int approvedCount, required int teamCount, required int capacity})`
  - `bool assignmentsFitCapacity({required Map<String, String?> before, required Map<String, String?> incoming, required int capacity})`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test/features/league/team_capacity_test.dart` (신규):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fishing_competition/features/league/data/team_capacity.dart';

void main() {
  group('isTeamFull / remainingSlots', () {
    test('정원 0 은 무제한이다', () {
      expect(isTeamFull(capacity: 0, memberCount: 999), isFalse);
      expect(remainingSlots(capacity: 0, memberCount: 999), -1);
    });

    test('정원에 도달하면 꽉 찬 것이다', () {
      expect(isTeamFull(capacity: 5, memberCount: 4), isFalse);
      expect(isTeamFull(capacity: 5, memberCount: 5), isTrue);
      expect(remainingSlots(capacity: 5, memberCount: 3), 2);
      expect(remainingSlots(capacity: 5, memberCount: 5), 0);
    });

    test('정원을 낮춰 초과한 팀은 남은 자리가 음수가 아니라 0 이다', () {
      // 호스트가 정원을 5 → 3 으로 낮춘 경우. "-3자리 남음" 이 떠선 안 된다.
      expect(remainingSlots(capacity: 3, memberCount: 6), 0);
      expect(isTeamFull(capacity: 3, memberCount: 6), isTrue);
      expect(isOverCapacity(capacity: 3, memberCount: 6), isTrue);
      expect(isOverCapacity(capacity: 3, memberCount: 3), isFalse);
      expect(isOverCapacity(capacity: 0, memberCount: 999), isFalse);
    });
  });

  group('capacityLabel', () {
    test('무제한이면 인원만 보여준다', () {
      expect(capacityLabel(capacity: 0, memberCount: 4), '4명');
    });

    test('정원이 있으면 사용/정원으로 보여준다', () {
      expect(capacityLabel(capacity: 5, memberCount: 3), '3 / 5');
      expect(capacityLabel(capacity: 5, memberCount: 6), '6 / 5');
    });
  });

  group('shuffleFitsCapacity', () {
    test('무제한이면 항상 통과', () {
      expect(
          shuffleFitsCapacity(approvedCount: 100, teamCount: 1, capacity: 0),
          isTrue);
    });

    test('총 자리수가 참가자보다 적으면 실패', () {
      // 15명, 3팀, 정원 3 → 9자리 < 15명
      expect(
          shuffleFitsCapacity(approvedCount: 15, teamCount: 3, capacity: 3),
          isFalse);
      expect(
          shuffleFitsCapacity(approvedCount: 15, teamCount: 3, capacity: 5),
          isTrue);
    });

    test('팀이 0개면 실패 (0자리)', () {
      expect(
          shuffleFitsCapacity(approvedCount: 1, teamCount: 0, capacity: 5),
          isFalse);
    });
  });

  group('assignmentsFitCapacity — SQL 의 "적용 후 상태" 규칙과 1:1', () {
    test('무제한이면 항상 통과', () {
      expect(
          assignmentsFitCapacity(
            before: {'a': null, 'b': null, 'c': null},
            incoming: {'a': 't1', 'b': 't1', 'c': 't1'},
            capacity: 0,
          ),
          isTrue);
    });

    test('개별로는 통과해도 합치면 정원을 넘으면 실패', () {
      // t1 에 이미 3명, 정원 5. 3명을 더 넣으면 6명.
      expect(
          assignmentsFitCapacity(
            before: {'x': 't1', 'y': 't1', 'z': 't1', 'a': null, 'b': null, 'c': null},
            incoming: {'a': 't1', 'b': 't1', 'c': 't1'},
            capacity: 5,
          ),
          isFalse);
    });

    test('정원에 딱 맞으면 통과', () {
      expect(
          assignmentsFitCapacity(
            before: {'x': 't1', 'y': 't1', 'z': 't1', 'a': null, 'b': null},
            incoming: {'a': 't1', 'b': 't1'},
            capacity: 5,
          ),
          isTrue);
    });

    test('초과 팀에서 사람이 빠지는 배정은 허용된다', () {
      // 정원을 3으로 낮춰 t1 이 5명(초과). 1명을 빼면 4명 — 여전히 초과지만 줄었다.
      // 이걸 막으면 호스트가 초과 상태를 복구할 수 없다.
      expect(
          assignmentsFitCapacity(
            before: {'a': 't1', 'b': 't1', 'c': 't1', 'd': 't1', 'e': 't1'},
            incoming: {'a': null},
            capacity: 3,
          ),
          isTrue);
    });

    test('초과 팀에 더 넣는 배정은 거부된다', () {
      expect(
          assignmentsFitCapacity(
            before: {'a': 't1', 'b': 't1', 'c': 't1', 'd': 't1', 'z': null},
            incoming: {'z': 't1'},
            capacity: 3,
          ),
          isFalse);
    });

    test('초과 팀을 그대로 두는 배정(다른 팀 건드리기)은 통과', () {
      expect(
          assignmentsFitCapacity(
            before: {'a': 't1', 'b': 't1', 'c': 't1', 'd': 't1', 'z': null},
            incoming: {'z': 't2'},
            capacity: 3,
          ),
          isTrue);
    });

    test('미배정으로 보내는 것은 정원과 무관하게 통과', () {
      expect(
          assignmentsFitCapacity(
            before: {'a': 't1'},
            incoming: {'a': null},
            capacity: 1,
          ),
          isTrue);
    });

    test('incoming 에 없는 사람은 before 값을 유지한다', () {
      // t1 에 정원(2)만큼 있고, 건드리지 않는 배정은 통과해야 한다.
      expect(
          assignmentsFitCapacity(
            before: {'a': 't1', 'b': 't1', 'z': null},
            incoming: {'z': 't2'},
            capacity: 2,
          ),
          isTrue);
    });
  });
}
```

- [ ] **Step 2: 테스트가 실패하는 것을 확인한다**

Run: `flutter test test/features/league/team_capacity_test.dart`
Expected: FAIL — `Error: Error when reading 'lib/features/league/data/team_capacity.dart': No such file or directory`.

- [ ] **Step 3: 구현한다**

`lib/features/league/data/team_capacity.dart` (신규):

```dart
/// 팀 정원 판정. `leagues.team_capacity` 가 `0` 이면 무제한이다.
///
/// 이 파일의 규칙은 마이그레이션
/// `20261123140000_league_team_assign_mode.sql` 의 RPC 검증과 1:1 로
/// 대응한다. 한쪽만 고치면 UI 가 허용한 조작이 서버에서 거부된다.

/// 더 들어갈 수 없는가.
bool isTeamFull({required int capacity, required int memberCount}) =>
    capacity > 0 && memberCount >= capacity;

/// 정원보다 이미 많은가. 호스트가 정원을 낮춘 경우에만 생긴다.
bool isOverCapacity({required int capacity, required int memberCount}) =>
    capacity > 0 && memberCount > capacity;

/// 남은 자리. 무제한이면 `-1`.
///
/// 초과 상태에서 음수를 돌려주면 "-3자리 남음" 같은 문구가 나오므로 0 으로 깎는다.
int remainingSlots({required int capacity, required int memberCount}) {
  if (capacity <= 0) return -1;
  final left = capacity - memberCount;
  return left > 0 ? left : 0;
}

/// 카드·목록에 쓰는 인원 표시.
String capacityLabel({required int capacity, required int memberCount}) =>
    capacity <= 0 ? '$memberCount명' : '$memberCount / $capacity';

/// 라운드로빈 셔플이 정원 안에 들어가는가.
///
/// 균등 분배이므로 총 자리수만 맞으면 어떤 팀도 정원을 넘지 않는다.
bool shuffleFitsCapacity({
  required int approvedCount,
  required int teamCount,
  required int capacity,
}) {
  if (capacity <= 0) return true;
  return approvedCount <= teamCount * capacity;
}

/// 일괄 배정이 정원 규칙을 지키는가 — **적용 후 상태** 기준.
///
/// [before] / [incoming] 모두 `userId → teamId?` 이고 `null` 은 미배정이다.
/// [incoming] 에 없는 사람은 [before] 값을 유지한다 (키가 없는 것과
/// 값이 null 인 것은 다르다 — 후자는 "미배정으로 보내라"는 명시적 지시다).
///
/// 위반 조건은 단순히 "정원 초과"가 아니라
/// **"적용 후 초과 AND 적용 전보다 줄지 않음"** 이다.
/// 호스트가 정원을 낮춰 이미 초과한 팀에서 사람을 빼는 배정을 막으면
/// 초과 상태를 복구할 수단이 없어진다.
bool assignmentsFitCapacity({
  required Map<String, String?> before,
  required Map<String, String?> incoming,
  required int capacity,
}) {
  if (capacity <= 0) return true;

  final beforeCounts = <String, int>{};
  final afterCounts = <String, int>{};

  for (final entry in before.entries) {
    final was = entry.value;
    if (was != null) {
      beforeCounts[was] = (beforeCounts[was] ?? 0) + 1;
    }
    final now = incoming.containsKey(entry.key) ? incoming[entry.key] : was;
    if (now != null) {
      afterCounts[now] = (afterCounts[now] ?? 0) + 1;
    }
  }

  for (final entry in afterCounts.entries) {
    final after = entry.value;
    if (after <= capacity) continue;
    if (after >= (beforeCounts[entry.key] ?? 0)) return false;
  }
  return true;
}
```

- [ ] **Step 4: 테스트가 통과하는 것을 확인한다**

Run: `flutter test test/features/league/team_capacity_test.dart`
Expected: PASS, 16/16.

- [ ] **Step 5: 뮤테이션 테스트 — "줄었으면 통과" 가드가 실제로 테스트에 걸리는지 확인한다**

`assignmentsFitCapacity` 의 아래 줄을

```dart
    if (after >= (beforeCounts[entry.key] ?? 0)) return false;
```

일부러 이렇게 바꾼다:

```dart
    return false;
```

Run: `flutter test test/features/league/team_capacity_test.dart`
Expected: FAIL — `초과 팀에서 사람이 빠지는 배정은 허용된다` 가 깨진다.

**실패하지 않으면 그 테스트가 규칙을 지키지 못하고 있다는 뜻이다.** 원래 줄로 되돌리고 테스트를 고친 뒤 다시 확인한다.

- [ ] **Step 6: 원래 코드로 되돌리고 통과를 재확인한다**

Run: `flutter test test/features/league/team_capacity_test.dart`
Expected: PASS, 16/16.

- [ ] **Step 7: Commit**

```bash
git add lib/features/league/data/team_capacity.dart \
        test/features/league/team_capacity_test.dart
git commit -m "feat(league): 팀 정원 판정 순수 함수 + 단위 테스트

SQL RPC 의 정원 규칙과 1:1 대응. 핵심은 '적용 후 상태' 판정 —
정원을 낮춰 초과한 팀에서 사람이 빠지는 배정은 허용해야 한다.
그 가드는 뮤테이션 테스트로 확인했다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 4: 리그 개설 / 수정 — 배정 방식 세그먼트 + 정원 스테퍼 (목업 ⑥)

**Files:**
- Modify: `lib/features/league/presentation/screens/league_create_screen.dart:53-54` (상태), `:100-110` (수정 모드 로딩), `:185-235` (create/update 호출), `:1113-1125` (팀전 토글 하위 블록)

**Interfaces:**
- Consumes: `createLeague(..., teamAssignMode:, teamCapacity:)`, `updateLeague(..., teamAssignMode:, teamCapacity:)` (Task 2), `capacityLabel` (Task 3)
- Produces: 없음 (화면 최종단)

- [ ] **Step 1: 상태 필드를 추가한다**

`league_create_screen.dart:54` (`bool _isTeamMode = false;`) 아래:

```dart
  bool _isTeamMode = false;
  String _teamAssignMode = 'host';
  int _teamCapacity = 0;

  /// 정원 초기값을 한 번만 5 로 세팅하기 위한 플래그.
  ///
  /// DB DEFAULT 는 0(무제한)이어야 한다 — 기존 리그와 일반 리그가 v1 과
  /// 동일하게 동작해야 하기 때문이다. 하지만 팀전을 켜는 사람은 정원을
  /// 원할 가능성이 높으므로 **처음 켜는 순간** 화면 값만 5 로 둔다.
  /// 껐다 다시 켜면 직전 값을 유지한다.
  bool _teamCapacityTouched = false;
```

- [ ] **Step 2: 수정 모드에서 값을 복원한다**

`:108` (`_isTeamMode = l.isTeamMode;`) 아래:

```dart
    _isTeamMode = l.isTeamMode;
    _teamAssignMode = l.teamAssignMode;
    _teamCapacity = l.teamCapacity;
    // 수정 모드는 항상 DB 값을 그대로 보여준다. 자동 5 세팅이 걸리면
    // 무제한으로 운영 중인 리그가 저장만 눌렀을 때 정원 5 로 바뀐다.
    _teamCapacityTouched = true;
```

- [ ] **Step 3: create / update 호출에 값을 넘긴다**

`:193` 과 `:229` 의 `isTeamMode: _isTeamMode,` 뒤에 각각:

```dart
            isTeamMode: _isTeamMode,
            teamAssignMode: _teamAssignMode,
            teamCapacity: _teamCapacity,
```

- [ ] **Step 4: 팀전 토글의 `onChanged` 에서 첫 활성화 시 정원 초기값을 둔다**

`:1111` 을 아래로 바꾼다:

```dart
                      onChanged: _isEnded
                          ? null
                          : (v) => setState(() {
                                _isTeamMode = v;
                                if (v && !_teamCapacityTouched) {
                                  _teamCapacity = 5;
                                  _teamCapacityTouched = true;
                                }
                              }),
```

- [ ] **Step 5: 토글 하위에 세그먼트 + 스테퍼를 넣는다**

`:1113` 의 `if (_isTeamMode) ...[` 블록 안, 기존 안내 `Padding` **위**에 아래를 삽입한다. 안내 문구는 배정 방식에 따라 바뀌므로 기존 문구도 함께 고친다.

```dart
                    if (_isTeamMode) ...[
                      Divider(height: 1, color: divColor),

                      // 팀 선택 방식
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('팀 선택 방식', style: AppTextStyles.heading4),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(
                                child: _AssignModeChip(
                                  label: '호스트가\n배정',
                                  selected: _teamAssignMode == 'host',
                                  onTap: _isEnded
                                      ? null
                                      : () => setState(
                                          () => _teamAssignMode = 'host'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _AssignModeChip(
                                  label: '참가자가\n선택',
                                  selected: _teamAssignMode == 'self',
                                  onTap: _isEnded
                                      ? null
                                      : () => setState(
                                          () => _teamAssignMode = 'self'),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),

                      // 팀당 정원
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('팀당 정원', style: AppTextStyles.heading4),
                                const SizedBox(height: 3),
                                Text('0이면 무제한',
                                    style: AppTextStyles.bodySmall
                                        .copyWith(color: sub)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: (_isEnded || _teamCapacity <= 0)
                                ? null
                                : () => setState(() {
                                      _teamCapacity--;
                                      _teamCapacityTouched = true;
                                    }),
                            icon: const Icon(LucideIcons.minus, size: 18),
                            tooltip: '정원 줄이기',
                          ),
                          SizedBox(
                            width: 56,
                            child: Text(
                              _teamCapacity == 0 ? '무제한' : '$_teamCapacity명',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.heading4,
                            ),
                          ),
                          IconButton(
                            onPressed: (_isEnded || _teamCapacity >= 50)
                                ? null
                                : () => setState(() {
                                      _teamCapacity++;
                                      _teamCapacityTouched = true;
                                    }),
                            icon: const Icon(LucideIcons.plus, size: 18),
                            tooltip: '정원 늘리기',
                          ),
                        ]),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.info_outline_rounded,
                              size: 15, color: context.accentColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _teamAssignMode == 'self'
                                  ? '참가자가 직접 팀을 고릅니다. 호스트도 계속 배정할 수 있습니다.\n'
                                      '점수 규칙은 위에서 고른 그대로입니다.'
                                  : '호스트만 팀을 바꿀 수 있습니다. 자동 셔플로 한 번에 배정할 수 있습니다.\n'
                                      '점수 규칙은 위에서 고른 그대로입니다.',
                              style: AppTextStyles.bodySmall
                                  .copyWith(height: 1.6, color: sub),
                            ),
                          ),
                        ]),
                      ),
                    ],
```

그리고 파일 맨 끝에 칩 위젯을 추가한다 (이 화면 전용이므로 `core/widgets` 로 올리지 않는다):

```dart
/// 팀 선택 방식 2지 선택 칩. 이 화면에서만 쓰이므로 여기 둔다.
class _AssignModeChip extends StatelessWidget {
  const _AssignModeChip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    final sub = context.isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final divColor =
        context.isDark ? AppColors.darkDivider : AppColors.lightDivider;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.1) : null,
            border: Border.all(color: selected ? accent : divColor),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.heading4.copyWith(
              height: 1.35,
              color: selected ? accent : sub,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: import 를 확인한다**

`league_create_screen.dart` 상단에 `AppTextStyles` 와 `AppColors` import 가 없으면 추가한다:

Run: `grep -n "app_text_styles\|app_colors\|lucide_icons" lib/features/league/presentation/screens/league_create_screen.dart | head`
없는 것만 추가:

```dart
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
```

- [ ] **Step 7: 컴파일 + 전체 테스트**

Run: `flutter analyze lib/features/league/presentation/screens/league_create_screen.dart && flutter test`
Expected: analyze 에러 0건, `+62: All tests passed!` (40 + Task 2의 6 + Task 3의 16).

- [ ] **Step 8: Commit**

```bash
git add lib/features/league/presentation/screens/league_create_screen.dart
git commit -m "feat(league): 리그 개설에 팀 선택 방식·팀당 정원 추가

팀전 토글 하위에 중첩. 정원 DB DEFAULT 는 0(무제한)을 유지하고
화면에서 처음 켤 때만 5 로 둔다 — 기존 리그에 정원이 생기면 안 된다.
수정 모드는 항상 DB 값을 그대로 보여준다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 5: 팀 관리 — 카드 기본 접힘 + 정원 행 + 팀 검색 (목업 ①)

v1 의 `LeagueTeamManageScreen` 은 `ConsumerWidget` 이다. 접힘 상태와 셔플 스냅샷을 들고 있어야 하므로 `ConsumerStatefulWidget` 으로 바꾼다.

**Files:**
- Modify: `lib/features/league/presentation/screens/league_team_manage_screen.dart` (전반)

**Interfaces:**
- Consumes: `capacityLabel` / `isTeamFull` / `isOverCapacity` / `remainingSlots` (Task 3), `League.teamCapacity` (Task 2), `leagueDetailProvider(leagueId)`, `updateLeague(id:, teamCapacity:)` (Task 2)
- Produces:
  - `LeagueTeamManageScreen` (`ConsumerStatefulWidget`, 생성자 동일: `{super.key, required this.leagueId}`)
  - `_TeamCard` 에 `expanded` (bool) / `onToggle` (VoidCallback) / `capacity` (int) / `onAddMembers` (VoidCallback) 파라미터 추가. 초과·꽉찬 여부는 `_TeamCard` 가 `capacity` 로 직접 계산한다 (Task 3 함수 사용)

- [ ] **Step 1: `StatefulWidget` 으로 바꾸고 접힘 상태를 둔다**

클래스 선언부를 교체한다:

```dart
class LeagueTeamManageScreen extends ConsumerStatefulWidget {
  const LeagueTeamManageScreen({super.key, required this.leagueId});

  final String leagueId;

  @override
  ConsumerState<LeagueTeamManageScreen> createState() =>
      _LeagueTeamManageScreenState();
}

class _LeagueTeamManageScreenState
    extends ConsumerState<LeagueTeamManageScreen> {
  /// 펼친 팀 id. 20팀에서 전부 펼치면 화면이 성립하지 않으므로
  /// 기본은 전부 접힘이다. (팀 순위 탭의 기본 펼침 규칙과는 별개다 —
  /// 그쪽은 점수를 보는 화면이고 여기는 배정하는 화면이다)
  final _expanded = <String>{};

  String get leagueId => widget.leagueId;
  ...
}
```

기존 메서드들에서 `WidgetRef ref` 파라미터를 제거하고 `State` 의 `ref` 를 쓴다. `_refreshTeams(ref)` → `_refreshTeams()` 등.

- [ ] **Step 2: 리그를 watch 해 정원을 읽는다**

`build` 안에서 `teamsAsync` / `rankingAsync` 와 함께:

```dart
    final leagueAsync = ref.watch(leagueDetailProvider(leagueId));
    final capacity = leagueAsync.valueOrNull?.teamCapacity ?? 0;
```

> provider 이름은 `leagueDetailProvider(String id)` 다 (`league_repository.dart:749`, 확인함). `leagueProvider` 는 **존재하지 않는다.** 리그 상세 화면이 이미 쓰는 provider 라 추가 쿼리는 0회다.

- [ ] **Step 3: 요약 바 바로 아래에 정원 행을 넣는다 (스펙 4.2(7))**

`자동 셔플` Row 와 미배정 블록 **사이**에 삽입한다. 정원이 팀 카드의 표시와 다중 추가의 남은 자리를 모두 지배하므로 팀 목록 전에 보여야 한다.

```dart
                  // 정원이 팀 카드 표시와 다중 추가의 '남은 자리'를 모두
                  // 지배하므로 팀 목록 앞에 둔다. 화면 하단에 두면
                  // 20팀을 스크롤해야 닿는다.
                  AppCard(
                    variant: AppCardVariant.surface,
                    radius: 12,
                    borderColor: divColor,
                    padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('팀당 정원', style: AppTextStyles.heading4),
                            const SizedBox(height: 2),
                            Text(capacity == 0 ? '무제한' : '$capacity명',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: sub)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: capacity <= 0
                            ? null
                            : () => _setCapacity(capacity - 1),
                        icon: const Icon(LucideIcons.minus, size: 18),
                        tooltip: '정원 줄이기',
                      ),
                      IconButton(
                        onPressed: capacity >= 50
                            ? null
                            : () => _setCapacity(capacity + 1),
                        icon: const Icon(LucideIcons.plus, size: 18),
                        tooltip: '정원 늘리기',
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
```

그리고 메서드를 추가한다:

```dart
  /// 정원을 현재 인원보다 작게 줄여도 멤버를 강제로 빼지 않는다.
  /// 그 팀은 "6 / 5" 로 표시되고 신규 진입만 막힌다. (스펙 2.3)
  Future<void> _setCapacity(int next) async {
    try {
      await ref
          .read(leagueRepositoryProvider)
          .updateLeague(id: leagueId, teamCapacity: next);
      ref.invalidate(leagueDetailProvider(leagueId));
    } catch (e) {
      if (mounted) AppSnackBar.error(context, _message(e));
    }
  }
```

- [ ] **Step 4: 팀 카드를 접힘/펼침으로 바꾼다**

`_TeamCard` 호출부를 교체한다:

```dart
                  for (final t in teams) ...[
                    _TeamCard(
                      team: t,
                      members: [
                        for (final uid in t.memberUserIds)
                          if (byUserId[uid] != null) byUserId[uid]!,
                      ],
                      expanded: _expanded.contains(t.id),
                      onToggle: () => setState(() {
                        if (!_expanded.remove(t.id)) _expanded.add(t.id);
                      }),
                      capacity: capacity,
                      isDark: isDark,
                      divColor: divColor,
                      sub: sub,
                      onRename: () => _editTeam(t),
                      onRecolor: () => _editTeamColor(t),
                      onDelete: () => _deleteTeam(t),
                      onTapMember: (uid) => _pickTeam(teams, uid, t.id),
                      onAddMembers: () => _addMembers(t, teams, participants),
                    ),
                    const SizedBox(height: 12),
                  ],
```

`_TeamCard` 의 헤더 Row 를 `InkWell(onTap: onToggle, ...)` 로 감싸고, 인원 표시를 `capacityLabel` 로 바꾸고, 펼쳤을 때만 멤버 줄과 `팀원 추가` 버튼을 그린다:

```dart
class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
    required this.members,
    required this.expanded,
    required this.onToggle,
    required this.capacity,
    required this.isDark,
    required this.divColor,
    required this.sub,
    required this.onRename,
    required this.onRecolor,
    required this.onDelete,
    required this.onTapMember,
    required this.onAddMembers,
  });

  final LeagueTeam team;
  final List<LeagueRankEntry> members;
  final bool expanded;
  final VoidCallback onToggle;
  final int capacity;
  final bool isDark;
  final Color divColor;
  final Color sub;
  final VoidCallback onRename;
  final VoidCallback onRecolor;
  final VoidCallback onDelete;
  final void Function(String userId) onTapMember;
  final VoidCallback onAddMembers;

  @override
  Widget build(BuildContext context) {
    final over = isOverCapacity(capacity: capacity, memberCount: members.length);
    final left = remainingSlots(capacity: capacity, memberCount: members.length);
    final full = isTeamFull(capacity: capacity, memberCount: members.length);

    return AppCard(
      variant: AppCardVariant.surface,
      radius: 14,
      borderColor: divColor,
      padding: EdgeInsets.zero,
      child: Column(children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            child: Row(children: [
              Semantics(
                label: '${team.name} 색 변경',
                button: true,
                child: InkWell(
                  onTap: onRecolor,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                          color: AppColors.teamColor(team.color),
                          shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Row(children: [
                  Flexible(
                    child: Text(team.name,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.heading4),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    capacityLabel(
                        capacity: capacity, memberCount: members.length),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: over ? AppColors.warning : sub,
                      fontWeight: over ? FontWeight.w700 : null,
                    ),
                  ),
                ]),
              ),
              IconButton(
                onPressed: onRename,
                icon: const Icon(LucideIcons.pencil, size: 17),
                tooltip: '${team.name} 이름 변경',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(LucideIcons.trash2,
                    size: 17, color: AppColors.error),
                tooltip: '${team.name} 삭제',
              ),
              Icon(expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 18, color: sub),
              const SizedBox(width: 6),
            ]),
          ),
        ),
        if (expanded) ...[
          Divider(height: 1, color: divColor),
          for (final m in members)
            _MemberRow(
              username: m.username,
              avatarUrl: m.avatarUrl,
              trailingLabel: team.name,
              trailingColor: sub,
              isDark: isDark,
              onTap: () => onTapMember(m.userId),
            ),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(children: [
                Text('아직 팀원이 없습니다',
                    style: AppTextStyles.bodySmall.copyWith(color: sub)),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: AppButton(
              label: full
                  ? '정원이 찼습니다'
                  : (left < 0 ? '팀원 추가' : '팀원 추가 · $left자리 남음'),
              icon: LucideIcons.userPlus,
              variant: AppButtonVariant.outline,
              size: AppButtonSize.sm,
              onPressed: full ? null : onAddMembers,
            ),
          ),
        ],
      ]),
    );
  }
}
```

- [ ] **Step 5: 팀 선택 바텀시트에 검색을 넣는다 (스펙 4.2(5))**

`_pickTeam` 의 바텀시트를 `StatefulBuilder` 로 감싸 검색 필터를 넣는다. 팀이 8개를 넘으면 스크롤만으로는 못 찾는다.

```dart
  Future<void> _pickTeam(
    List<LeagueTeam> teams,
    String userId,
    String? currentTeamId,
  ) async {
    final ctrl = TextEditingController();
    final picked = await showModalBottomSheet<_TeamPick>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              final q = ctrl.text.trim();
              final shown = q.isEmpty
                  ? teams
                  : teams
                      .where((t) =>
                          t.name.toLowerCase().contains(q.toLowerCase()))
                      .toList(growable: false);
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('팀 선택', style: AppTextStyles.heading4),
                ),
                if (teams.length >= 8)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: AppTextField(
                      controller: ctrl,
                      hint: '팀 이름으로 찾기',
                      onChanged: (_) => setSheetState(() {}),
                    ),
                  ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final t in shown)
                        ListTile(
                          leading: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                                color: AppColors.teamColor(t.color),
                                shape: BoxShape.circle),
                          ),
                          title: Text(t.name),
                          trailing: t.id == currentTeamId
                              ? const Icon(LucideIcons.check, size: 18)
                              : null,
                          onTap: () => Navigator.pop(ctx, _TeamPick(t.id)),
                        ),
                      if (shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text('검색 결과가 없습니다',
                                style: AppTextStyles.bodySmall),
                          ),
                        ),
                      if (currentTeamId != null)
                        ListTile(
                          leading: const Icon(LucideIcons.userMinus, size: 18),
                          title: const Text('미배정으로'),
                          onTap: () =>
                              Navigator.pop(ctx, const _TeamPick(null)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ]);
            },
          ),
        ),
      ),
    );
    ctrl.dispose();
    if (picked == null || !mounted) return;
    if (picked.teamId == currentTeamId) return;
    try {
      await ref.read(leagueRepositoryProvider).assignParticipantTeam(
            leagueId: leagueId,
            userId: userId,
            teamId: picked.teamId,
          );
      _refreshTeams();
    } catch (e) {
      if (mounted) AppSnackBar.error(context, _message(e));
    }
  }
```

- [ ] **Step 6: 에러 문구를 스펙 4.6 에 맞춘다**

`_message` 를 교체한다:

```dart
  String _message(Object e) {
    final s = e.toString();
    if (s.contains('TEAM_FULL')) return '방금 정원이 찼습니다. 다른 팀을 골라주세요.';
    if (s.contains('CAPACITY_TOO_SMALL')) {
      return '정원이 너무 작습니다. 팀을 늘리거나 정원을 올려주세요.';
    }
    if (s.contains('SELF_PICK_DISABLED')) return '이 리그는 호스트가 팀을 배정합니다.';
    if (s.contains('NOT_LEAGUE_HOST')) return '호스트만 팀을 배정할 수 있습니다.';
    if (s.contains('TEAM_NOT_IN_LEAGUE')) {
      return '팀 정보가 바뀌었습니다. 새로고침 해주세요.';
    }
    if (s.contains('NOT_PARTICIPANT')) return '이 리그의 참가자가 아닙니다.';
    if (s.contains('NO_TEAMS')) return '먼저 팀을 만들어주세요.';
    if (s.contains('AUTH_REQUIRED') || s.contains('LEAGUE_NOT_FOUND')) {
      return '다시 시도해주세요.';
    }
    if (s.contains('league_teams_league_id_name_key')) {
      return '이미 같은 이름의 팀이 있습니다.';
    }
    if (s.contains('league_teams_name_not_blank')) return '팀 이름을 입력해주세요.';
    return '처리에 실패했습니다: $e';
  }
```

- [ ] **Step 7: 임시 `_addMembers` 스텁 (Task 6에서 채운다)**

Task 5 를 독립적으로 컴파일·테스트 가능하게 하기 위해 스텁을 둔다. Task 6 이 이것을 실제 시트 호출로 교체한다.

```dart
  /// Task 6 에서 다중 선택 시트로 교체된다.
  Future<void> _addMembers(
    LeagueTeam team,
    List<LeagueTeam> teams,
    List<LeagueRankEntry> participants,
  ) async {
    AppSnackBar.info(context, '준비 중입니다.');
  }
```

> `AppSnackBar` 는 `success` / `error` / `warning` / `info` 를 갖고 있다 (확인함).

- [ ] **Step 8: import 추가**

```dart
import '../../../../core/theme/app_text_styles.dart';
import '../../data/team_capacity.dart';
```

- [ ] **Step 9: 컴파일 + 전체 테스트**

Run: `flutter analyze lib/features/league/presentation/screens/league_team_manage_screen.dart && flutter test`
Expected: analyze 에러 0건, `+62: All tests passed!` (Task 5 는 테스트를 더하지 않는다).

- [ ] **Step 10: Commit**

```bash
git add lib/features/league/presentation/screens/league_team_manage_screen.dart
git commit -m "feat(league): 팀 관리 — 카드 기본 접힘, 정원 행, 팀 검색

20팀에서 모든 카드가 펼쳐져 있으면 화면이 성립하지 않는다.
팀 순위 탭의 기본 펼침 규칙은 바꾸지 않았다 (그쪽은 점수를 보는 화면).
에러 문구를 스펙 4.6 매핑으로 교체.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 6: 팀 관리 — 다중 선택 추가 + 셔플 되돌리기 (목업 ②③)

**Files:**
- Create: `lib/features/league/presentation/widgets/team_member_add_sheet.dart`
- Modify: `lib/features/league/presentation/screens/league_team_manage_screen.dart` (`_addMembers`, `_shuffle`, 요약 바)
- Test: `test/features/league/team_assign_mode_test.dart` (그룹 추가)

**Interfaces:**
- Consumes: `assignLeagueTeams` / `shuffleLeagueTeams` → `List<TeamAssignment>` (Task 2), `remainingSlots` / `assignmentsFitCapacity` (Task 3)
- Produces:
  - `Future<List<String>?> showTeamMemberAddSheet({required BuildContext context, required LeagueTeam team, required List<LeagueRankEntry> candidates, required Map<String, String> teamNameByUserId, required int remaining, required bool isDark})` — 고른 userId 목록, 취소면 `null`
  - `bool shouldDropSnapshot(Object error)` — 되돌리기 실패 시 스냅샷을 폐기해야 하는가 (`@visibleForTesting`)

- [ ] **Step 1: 실패하는 테스트를 쓴다 (Review Focus 5)**

`test/features/league/team_assign_mode_test.dart` 끝에 그룹을 추가한다:

```dart
  group('shouldDropSnapshot — 되돌리기 실패 처리', () {
    test('팀이 삭제됐으면 스냅샷을 폐기한다', () {
      // 스냅샷이 가리키는 팀이 사라졌으면 그 스냅샷은 영구히 실패한다.
      // 폐기하지 않으면 '되돌리기' 버튼이 남아 계속 같은 에러를 띄운다.
      expect(
          shouldDropSnapshot(
              Exception('PostgrestException(message: TEAM_NOT_IN_LEAGUE)')),
          isTrue);
    });

    test('참가자가 탈퇴했으면 스냅샷을 폐기한다', () {
      expect(
          shouldDropSnapshot(
              Exception('PostgrestException(message: NOT_PARTICIPANT)')),
          isTrue);
    });

    test('일시적 실패는 스냅샷을 유지해 재시도할 수 있게 한다', () {
      expect(shouldDropSnapshot(Exception('SocketException: failed')), isFalse);
      expect(
          shouldDropSnapshot(
              Exception('PostgrestException(message: TEAM_FULL)')),
          isFalse);
    });
  });
```

import 를 파일 상단에 추가한다:

```dart
import 'package:fishing_competition/features/league/presentation/screens/league_team_manage_screen.dart';
```

- [ ] **Step 2: 테스트가 실패하는 것을 확인한다**

Run: `flutter test test/features/league/team_assign_mode_test.dart`
Expected: FAIL — `Undefined name 'shouldDropSnapshot'`.

- [ ] **Step 3: `shouldDropSnapshot` 을 구현한다**

`league_team_manage_screen.dart` 의 최상위(클래스 밖)에 추가한다:

```dart
/// 셔플 되돌리기가 실패했을 때 스냅샷을 버려야 하는가.
///
/// 스냅샷이 가리키는 팀이 삭제됐거나 참가자가 탈퇴했으면 그 스냅샷으로는
/// 다시는 성공할 수 없다. 버리지 않으면 `되돌리기` 버튼이 남아 사용자가
/// 같은 에러를 반복해서 본다. 일시적 실패(네트워크, 경합)는 유지한다.
@visibleForTesting
bool shouldDropSnapshot(Object error) {
  final s = error.toString();
  return s.contains('TEAM_NOT_IN_LEAGUE') || s.contains('NOT_PARTICIPANT');
}
```

- [ ] **Step 4: 테스트가 통과하는 것을 확인한다**

Run: `flutter test test/features/league/team_assign_mode_test.dart`
Expected: PASS, 9/9 (Task 2의 6 + 신규 3).

- [ ] **Step 5: 다중 선택 시트를 만든다**

`lib/features/league/presentation/widgets/team_member_add_sheet.dart` (신규):

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/league_repository.dart';
import '../../data/league_team_model.dart';

/// 팀에 여러 명을 한 번에 넣는 바텀시트.
///
/// 1명당 2탭이면 100명·20팀에서 200탭이 된다. 방향을 뒤집어 팀 1개당
/// 1번으로 만드는 것이 이 시트의 목적이다 — 확인 시 RPC 1회.
///
/// 고른 userId 목록을 돌려주고, 취소면 null 이다.
Future<List<String>?> showTeamMemberAddSheet({
  required BuildContext context,
  required LeagueTeam team,
  required List<LeagueRankEntry> candidates,
  required Map<String, String> teamNameByUserId,
  required int remaining,
  required bool isDark,
}) {
  final selected = <String>{};
  final ctrl = TextEditingController();
  final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
  final divColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;
  final teamColor = AppColors.teamColor(team.color);

  // remaining < 0 이면 무제한이다.
  final unlimited = remaining < 0;

  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            final q = ctrl.text.trim().toLowerCase();
            final shown = q.isEmpty
                ? candidates
                : candidates
                    .where((c) => c.username.toLowerCase().contains(q))
                    .toList(growable: false);
            final atLimit = !unlimited && selected.length >= remaining;

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.8,
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: Row(children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: teamColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${team.name}에 추가',
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.heading3),
                    ),
                    Text(
                      unlimited ? '정원 무제한' : '$remaining자리 남음',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: teamColor, fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  child: AppTextField(
                    controller: ctrl,
                    hint: '이름으로 찾기',
                    onChanged: (_) => setSheetState(() {}),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                  child: Row(children: [
                    Expanded(
                      child: Text('후보 ${candidates.length}명',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: sub, fontWeight: FontWeight.w700)),
                    ),
                    if (unlimited || remaining > 0)
                      TextButton(
                        onPressed: () => setSheetState(() {
                          selected
                            ..clear()
                            ..addAll(unlimited
                                ? shown.map((c) => c.userId)
                                : shown.take(remaining).map((c) => c.userId));
                        }),
                        child: const Text('전체 선택'),
                      ),
                  ]),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                    itemCount: shown.length,
                    itemBuilder: (_, i) {
                      final c = shown[i];
                      final checked = selected.contains(c.userId);
                      // 남은 자리를 넘는 줄은 비활성. 이미 고른 줄은 해제 가능.
                      final blocked = !checked && atLimit;
                      final currentTeam = teamNameByUserId[c.userId];
                      return Opacity(
                        opacity: blocked ? 0.55 : 1,
                        child: CheckboxListTile(
                          value: checked,
                          onChanged: blocked
                              ? null
                              : (v) => setSheetState(() {
                                    if (v == true) {
                                      selected.add(c.userId);
                                    } else {
                                      selected.remove(c.userId);
                                    }
                                  }),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Row(children: [
                            UserAvatar(
                                username: c.username,
                                avatarUrl: c.avatarUrl,
                                radius: 15,
                                isDark: isDark),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(c.username,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.body),
                            ),
                            if (blocked)
                              Text('자리 없음',
                                  style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w700))
                            else if (currentTeam != null)
                              Text(currentTeam,
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: sub))
                            else
                              Text('미배정',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: sub)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('검색 결과가 없습니다',
                        style: AppTextStyles.bodySmall.copyWith(color: sub)),
                  ),
                Divider(height: 1, color: divColor),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  child: Column(children: [
                    AppButton(
                      label: selected.isEmpty
                          ? '추가할 사람을 고르세요'
                          : '${selected.length}명 추가',
                      icon: LucideIcons.userPlus,
                      onPressed: selected.isEmpty
                          ? null
                          : () => Navigator.pop(ctx, selected.toList()),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      unlimited
                          ? '검색하면 다른 팀 소속도 나옵니다. 고르면 그 팀에서 옮겨집니다.'
                          : '정원을 넘기면 더 고를 수 없습니다. 검색하면 다른 팀 소속도 나옵니다.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: sub, height: 1.5),
                    ),
                  ]),
                ),
              ]),
            );
          },
        ),
      ),
    ),
  ).whenComplete(ctrl.dispose);
}
```

> `AppTextStyles` 의 실제 멤버는 `heading1`~`heading4`, `bodyBold`, `body`, `bodySmall`, `caption`, `captionBold`, `captionSmall`, `badge` 다 (확인함). `titleSmall` / `labelLarge` 같은 Material 이름은 **없다.**

- [ ] **Step 6: `_addMembers` 스텁을 실제 호출로 교체한다**

`league_team_manage_screen.dart`:

```dart
  /// 팀에 여러 명을 한 번에 넣는다. 확인 시 RPC 1회.
  ///
  /// 후보는 미배정자 + (검색으로 찾을 수 있게) 다른 팀 소속 전원이다.
  /// 이 팀의 현재 멤버는 제외한다 (이미 들어 있다).
  Future<void> _addMembers(
    LeagueTeam team,
    List<LeagueTeam> teams,
    List<LeagueRankEntry> participants,
    int capacity,
  ) async {
    final nameByUserId = <String, String>{};
    for (final t in teams) {
      for (final uid in t.memberUserIds) {
        nameByUserId[uid] = t.name;
      }
    }
    final mine = team.memberUserIds.toSet();
    final candidates = participants
        .where((p) => !mine.contains(p.userId))
        .toList(growable: false);

    final picked = await showTeamMemberAddSheet(
      context: context,
      team: team,
      candidates: candidates,
      teamNameByUserId: nameByUserId,
      remaining:
          remainingSlots(capacity: capacity, memberCount: mine.length),
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    try {
      await ref.read(leagueRepositoryProvider).assignLeagueTeams(
            leagueId: leagueId,
            assignments: [
              for (final uid in picked)
                TeamAssignment(userId: uid, teamId: team.id),
            ],
          );
      _refreshTeams();
      if (mounted) {
        AppSnackBar.success(context, '${picked.length}명을 ${team.name}에 넣었습니다.');
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, _message(e));
    }
  }
```

호출부도 `capacity` 를 넘기도록 고친다:

```dart
                      onAddMembers: () =>
                          _addMembers(t, teams, participants, capacity),
```

import 를 추가한다:

```dart
import '../widgets/team_member_add_sheet.dart';
```

- [ ] **Step 7: 셔플 되돌리기를 붙인다**

`_LeagueTeamManageScreenState` 에 스냅샷 필드를 추가한다:

```dart
  /// 직전 셔플의 **이전** 배정. 화면을 나가면 사라진다 — DB 에 저장하지
  /// 않는다. 커버 범위는 "방금 셔플이 실수였다" 하나다. (스펙 3.6)
  List<TeamAssignment>? _undoSnapshot;
```

`_shuffle` 을 교체한다:

```dart
  Future<void> _shuffle() async {
    final ok = await showConfirmDialog(
      context,
      title: '자동 셔플',
      content: '승인된 참가자를 팀에 균등하게 다시 배정합니다.\n\n'
          '현재 배정은 모두 덮어씌워집니다. 되돌리기로 복구할 수 있습니다.',
      confirmText: '셔플',
    );
    if (!ok || !mounted) return;
    try {
      final snapshot =
          await ref.read(leagueRepositoryProvider).shuffleLeagueTeams(leagueId);
      setState(() => _undoSnapshot = snapshot);
      _refreshTeams();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${snapshot.length}명을 다시 배정했습니다'),
        action: SnackBarAction(label: '되돌리기', onPressed: _undoShuffle),
        duration: const Duration(seconds: 6),
      ));
    } catch (e) {
      if (mounted) AppSnackBar.error(context, _message(e));
    }
  }

  /// 스냅샷을 그대로 되돌린다. 스냅샷이 가리키는 팀이 삭제됐거나 참가자가
  /// 탈퇴했으면 다시는 성공할 수 없으므로 폐기해 버튼을 없앤다.
  Future<void> _undoShuffle() async {
    final snapshot = _undoSnapshot;
    if (snapshot == null) return;
    try {
      await ref.read(leagueRepositoryProvider).assignLeagueTeams(
            leagueId: leagueId,
            assignments: snapshot,
          );
      if (mounted) setState(() => _undoSnapshot = null);
      _refreshTeams();
      if (mounted) AppSnackBar.success(context, '셔플 전으로 되돌렸습니다.');
    } catch (e) {
      if (shouldDropSnapshot(e) && mounted) {
        setState(() => _undoSnapshot = null);
      }
      if (mounted) AppSnackBar.error(context, _message(e));
    }
  }
```

요약 바의 버튼 Row 를 교체해 `되돌리기` 를 스냅샷이 있을 때만 보여준다:

```dart
                    if (_undoSnapshot != null) ...[
                      AppButton(
                        label: '되돌리기',
                        icon: LucideIcons.undo2,
                        variant: AppButtonVariant.outline,
                        size: AppButtonSize.sm,
                        fullWidth: false,
                        onPressed: _undoShuffle,
                      ),
                      const SizedBox(width: 8),
                    ],
                    AppButton(
                      label: '자동 셔플',
                      icon: LucideIcons.shuffle,
                      variant: AppButtonVariant.outline,
                      size: AppButtonSize.sm,
                      fullWidth: false,
                      onPressed: teams.isEmpty ? null : _shuffle,
                    ),
```

> `LucideIcons.undo2` 는 존재한다 (확인함).

- [ ] **Step 8: 컴파일 + 전체 테스트**

Run: `flutter analyze lib/features/league test/features/league && flutter test`
Expected: analyze 에러 0건, `+65: All tests passed!` (62 + 신규 3).

- [ ] **Step 9: Commit**

```bash
git add lib/features/league/presentation/widgets/team_member_add_sheet.dart \
        lib/features/league/presentation/screens/league_team_manage_screen.dart \
        test/features/league/team_assign_mode_test.dart
git commit -m "feat(league): 팀원 다중 선택 추가 + 셔플 되돌리기

1명당 2탭(100명이면 200탭)을 팀 1개당 1번으로 바꾼다 — 확인 시 RPC 1회.
셔플은 직전 스냅샷을 돌려주고 스낵바·요약바에서 되돌릴 수 있다.
팀이 삭제돼 되돌리기가 영구히 실패하면 스냅샷을 폐기해 버튼을 없앤다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 7: 참가자 — 내 팀 배너 + 내 팀 선택 화면 (목업 ④⑤)

**Files:**
- Create: `lib/features/league/presentation/widgets/league_my_team_banner.dart`
- Create: `lib/features/league/presentation/screens/league_my_team_screen.dart`
- Modify: `lib/features/league/presentation/widgets/league_team_ranking_tab.dart:81-105`
- Modify: `lib/core/router/app_router.dart:249-256` (라우트), `:344` (경로 상수)
- Test: `test/features/league/team_assign_mode_test.dart` (그룹 추가)

**Interfaces:**
- Consumes: `League.isSelfPick` (Task 2), `setMyLeagueTeam` (Task 2), `isTeamFull` / `capacityLabel` / `remainingSlots` (Task 3), `leagueTeamsProvider`, `leagueRankingProvider`, `currentUserProvider`
- Produces:
  - `bool shouldShowMyTeamBanner({required bool isSelfPick, required bool isApprovedParticipant})` (`@visibleForTesting`)
  - `LeagueMyTeamBanner` 위젯
  - `LeagueMyTeamScreen({required String leagueId})`
  - `AppRoutes.leagueMyTeam = '/league/my-team'`

- [ ] **Step 1: 실패하는 테스트를 쓴다 (Review Focus 4)**

`test/features/league/team_assign_mode_test.dart` 끝에 추가:

```dart
  group('shouldShowMyTeamBanner — 배너 노출 규칙', () {
    test('자율 선택 + 승인 참가자일 때만 보인다', () {
      expect(
          shouldShowMyTeamBanner(
              isSelfPick: true, isApprovedParticipant: true),
          isTrue);
    });

    test('호스트 배정 리그에는 아예 그리지 않는다', () {
      // 누를 수 없는 버튼을 보여주는 셈이다. RPC 도 SELF_PICK_DISABLED 를 던진다.
      expect(
          shouldShowMyTeamBanner(
              isSelfPick: false, isApprovedParticipant: true),
          isFalse);
    });

    test('참가자가 아니면(관전·미승인) 그리지 않는다', () {
      expect(
          shouldShowMyTeamBanner(
              isSelfPick: true, isApprovedParticipant: false),
          isFalse);
      expect(
          shouldShowMyTeamBanner(
              isSelfPick: false, isApprovedParticipant: false),
          isFalse);
    });
  });
```

상단에 import 추가:

```dart
import 'package:fishing_competition/features/league/presentation/widgets/league_my_team_banner.dart';
```

- [ ] **Step 2: 테스트가 실패하는 것을 확인한다**

Run: `flutter test test/features/league/team_assign_mode_test.dart`
Expected: FAIL — `Error when reading '.../league_my_team_banner.dart': No such file or directory`.

- [ ] **Step 3: 배너를 만든다**

`lib/features/league/presentation/widgets/league_my_team_banner.dart` (신규):

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/league_team_model.dart';

/// 팀 순위 탭 상단의 "내 팀" 배너를 그려야 하는가.
///
/// 호스트 배정 리그에 그리면 누를 수 없는 버튼을 보여주는 셈이다
/// (set_my_league_team 이 SELF_PICK_DISABLED 를 던진다).
@visibleForTesting
bool shouldShowMyTeamBanner({
  required bool isSelfPick,
  required bool isApprovedParticipant,
}) =>
    isSelfPick && isApprovedParticipant;

/// 자율 선택 리그에서 본인의 팀 상태를 보여주는 배너.
///
/// 미배정이면 "팀에 들어가야 점수가 반영된다"고 알리고 선택 화면으로 보낸다.
/// 배정돼 있으면 한 줄로 내 팀과 `변경` 만 보여준다.
class LeagueMyTeamBanner extends StatelessWidget {
  const LeagueMyTeamBanner({
    super.key,
    required this.leagueId,
    required this.myTeam,
    required this.hasAnyTeam,
  });

  final String leagueId;

  /// 본인이 속한 팀. null 이면 미배정.
  final LeagueTeam? myTeam;

  /// 리그에 팀이 하나라도 있는가. 없으면 고를 수 있는 게 없다.
  final bool hasAnyTeam;

  void _open(BuildContext context) =>
      context.push('/league/my-team/$leagueId');

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    final sub = context.isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final divColor =
        context.isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final team = myTeam;

    if (team != null) {
      return AppCard(
        variant: AppCardVariant.surface,
        radius: 14,
        borderColor: divColor,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: AppColors.teamColor(team.color), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('내 팀: ${team.name}',
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.heading4),
          ),
          TextButton(
            onPressed: () => _open(context),
            child: const Text('변경'),
          ),
        ]),
      );
    }

    return AppCard(
      variant: AppCardVariant.tinted,
      tintColor: accent,
      tintAlpha: 0.08,
      borderColor: accent,
      radius: 14,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(LucideIcons.users, size: 17, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('아직 팀을 선택하지 않았습니다',
                    style: AppTextStyles.heading4),
                const SizedBox(height: 4),
                Text(
                  hasAnyTeam
                      ? '팀에 들어가야 내 조과가 팀 점수에 반영됩니다. 리그 중에도 바꿀 수 있습니다.'
                      : '호스트가 팀을 만들면 선택할 수 있습니다.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: sub, height: 1.5),
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 12),
        AppButton(
          label: '내 팀 선택',
          onPressed: hasAnyTeam ? () => _open(context) : null,
        ),
      ]),
    );
  }
}
```

- [ ] **Step 4: 테스트가 통과하는 것을 확인한다**

Run: `flutter test test/features/league/team_assign_mode_test.dart`
Expected: PASS, 12/12 (6 + 3 + 신규 3).

- [ ] **Step 5: 팀 순위 탭에 배너를 끼운다**

`league_team_ranking_tab.dart` — `rows` 계산 뒤, `ListView.builder` 를 감싸도록 고친다. 팀이 0개면 기존 안내 화면(52-69행)이 먼저 반환되는데, **자율 모드에서는 안내 대신 배너를 보여야** 하므로 그 분기보다 앞에서 배너를 구성한다.

`build` 안, `if (teams.isEmpty)` **앞**에:

```dart
    final myUserId = ref.watch(currentUserProvider)?.id;
    final isApproved =
        myUserId != null && ranking.any((e) => e.userId == myUserId);
    final showBanner = shouldShowMyTeamBanner(
      isSelfPick: league.isSelfPick,
      isApprovedParticipant: isApproved,
    );
    LeagueTeam? myTeam;
    if (showBanner && myUserId != null) {
      for (final t in teams) {
        if (t.memberUserIds.contains(myUserId)) {
          myTeam = t;
          break;
        }
      }
    }
    final banner = showBanner
        ? LeagueMyTeamBanner(
            leagueId: league.id,
            myTeam: myTeam,
            hasAnyTeam: teams.isNotEmpty,
          )
        : null;
```

`if (teams.isEmpty)` 블록을 아래로 바꾼다 — 배너가 있으면 안내 위에 함께 보여준다:

```dart
    if (teams.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          if (banner != null) banner,
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(LucideIcons.users, size: 48, color: sub),
              const SizedBox(height: 12),
              Text('아직 팀이 없습니다',
                  style: AppTextStyles.body.copyWith(color: sub)),
              const SizedBox(height: 6),
              Text(
                '호스트가 리그 관리 > 팀 관리에서 팀을 만들면\n팀 순위가 표시됩니다.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall
                    .copyWith(color: sub, height: 1.5),
              ),
            ]),
          ),
        ],
      );
    }
```

`ListView.builder` 를 배너 1줄을 앞에 끼우도록 바꾼다:

```dart
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: rows.length + (banner != null ? 1 : 0),
        itemBuilder: (_, i) {
          if (banner != null) {
            if (i == 0) return banner;
            i -= 1;
          }
          final row = rows[i];
          return _TeamRankCard(
            rank: row.isUnassigned ? 0 : i + 1,
            ...
```

import 를 추가한다:

```dart
import '../../../../core/theme/app_text_styles.dart';
import '../../data/league_team_model.dart';
import 'league_my_team_banner.dart';
```

> `currentUserProvider` 는 `features/auth/data/auth_repository.dart` 에 있다 (확인함). 이 파일에는 `import '../../../auth/data/auth_repository.dart';` 를 추가한다.

- [ ] **Step 6: 내 팀 선택 화면을 만든다**

`lib/features/league/presentation/screens/league_my_team_screen.dart` (신규):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/league_repository.dart';
import '../../data/league_team_model.dart';
import '../../data/team_capacity.dart';

/// 참가자가 자기 팀을 고르는 화면. 자율 선택 리그에서만 진입한다.
///
/// 호스트도 참가자라면 똑같이 쓸 수 있다 — 자기 팀을 고르는 것이고,
/// 남을 배정하는 건 팀 관리 화면이다.
class LeagueMyTeamScreen extends ConsumerStatefulWidget {
  const LeagueMyTeamScreen({super.key, required this.leagueId});

  final String leagueId;

  @override
  ConsumerState<LeagueMyTeamScreen> createState() =>
      _LeagueMyTeamScreenState();
}

class _LeagueMyTeamScreenState extends ConsumerState<LeagueMyTeamScreen> {
  final _search = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pick(String? teamId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(leagueRepositoryProvider).setMyLeagueTeam(
            leagueId: widget.leagueId,
            teamId: teamId,
          );
      ref.invalidate(leagueTeamsProvider(widget.leagueId));
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      // 목록이 바뀌어 꽉 찬 팀을 눌렀을 수 있으니 다시 받는다.
      ref.invalidate(leagueTeamsProvider(widget.leagueId));
      if (mounted) AppSnackBar.error(context, _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object e) {
    final s = e.toString();
    // UI 가 꽉 찬 팀을 미리 비활성화하므로, 이 에러가 실제로 뜨는 경우는
    // 다른 사람이 먼저 들어간 경합뿐이다.
    if (s.contains('TEAM_FULL')) return '방금 정원이 찼습니다. 다른 팀을 골라주세요.';
    if (s.contains('SELF_PICK_DISABLED')) return '이 리그는 호스트가 팀을 배정합니다.';
    if (s.contains('NOT_PARTICIPANT')) return '이 리그의 참가자가 아닙니다.';
    if (s.contains('TEAM_NOT_IN_LEAGUE')) {
      return '팀 정보가 바뀌었습니다. 새로고침 해주세요.';
    }
    return '처리에 실패했습니다: $e';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accent = context.accentColor;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final divColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    final leagueAsync = ref.watch(leagueDetailProvider(widget.leagueId));
    final teamsAsync = ref.watch(leagueTeamsProvider(widget.leagueId));
    final rankingAsync = ref.watch(leagueRankingProvider(widget.leagueId));
    final myUserId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('내 팀 선택')),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('팀 정보를 불러오지 못했습니다: $e')),
        data: (teams) {
          final capacity = leagueAsync.valueOrNull?.teamCapacity ?? 0;
          final ranking = rankingAsync.valueOrNull ?? const <LeagueRankEntry>[];
          final nameByUserId = {
            for (final e in ranking) e.userId: e,
          };

          LeagueTeam? myTeam;
          if (myUserId != null) {
            for (final t in teams) {
              if (t.memberUserIds.contains(myUserId)) {
                myTeam = t;
                break;
              }
            }
          }

          final q = _search.text.trim().toLowerCase();
          final shown = q.isEmpty
              ? teams
              : teams
                  .where((t) => t.name.toLowerCase().contains(q))
                  .toList(growable: false);

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(
                '고르면 바로 반영됩니다. 리그 중에도 바꿀 수 있고, 등록한 조과는 따라옵니다.',
                style:
                    AppTextStyles.bodySmall.copyWith(color: sub, height: 1.55),
              ),
            ),
            if (teams.length >= 8)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: AppTextField(
                  controller: _search,
                  hint: '팀 이름으로 찾기',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                itemCount: shown.length,
                itemBuilder: (_, i) {
                  final t = shown[i];
                  final count = t.memberUserIds.length;
                  final isMine = t.id == myTeam?.id;
                  // 내 팀은 내가 이미 한 자리를 차지하고 있으므로 꽉 차 보여도
                  // 비활성으로 두면 안 된다 (멱등 호출이고 RPC 도 통과한다).
                  final full = !isMine &&
                      isTeamFull(capacity: capacity, memberCount: count);
                  final left =
                      remainingSlots(capacity: capacity, memberCount: count);

                  return Opacity(
                    opacity: full ? 0.45 : 1,
                    child: AppCard(
                      variant: AppCardVariant.surface,
                      radius: 14,
                      borderColor: isMine ? accent : divColor,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        onTap: (full || _busy || isMine) ? null : () => _pick(t.id),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                  color: AppColors.teamColor(t.color),
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.heading4),
                                  const SizedBox(height: 3),
                                  Text(
                                    _subtitle(
                                      isMine: isMine,
                                      full: full,
                                      count: count,
                                      capacity: capacity,
                                      left: left,
                                    ),
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: isMine
                                          ? accent
                                          : (full ? AppColors.warning : sub),
                                      fontWeight: (isMine || full)
                                          ? FontWeight.w700
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _Avatars(
                              userIds: t.memberUserIds,
                              entries: nameByUserId,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 4),
                            if (isMine)
                              Icon(LucideIcons.check, size: 20, color: accent)
                            else if (full)
                              Icon(LucideIcons.lock, size: 17, color: sub)
                            else
                              Icon(LucideIcons.chevronRight,
                                  size: 18, color: sub),
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (myTeam != null)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(children: [
                    AppButton(
                      label: '팀에서 나가기',
                      variant: AppButtonVariant.outline,
                      onPressed: _busy ? null : () => _pick(null),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '나가면 미배정이 되고 내 조과는 팀 점수에서 빠집니다',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: sub, height: 1.5),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }

  String _subtitle({
    required bool isMine,
    required bool full,
    required int count,
    required int capacity,
    required int left,
  }) {
    final label = capacityLabel(capacity: capacity, memberCount: count);
    if (isMine) return '현재 내 팀 · $label';
    if (full) return '$label · 정원 마감';
    if (count == 0) return '$label · 아직 비어 있음';
    if (left < 0) return label;
    return '$label · $left자리 남음';
  }
}

/// 팀 멤버 아바타 최대 3개 + 나머지 수.
class _Avatars extends StatelessWidget {
  const _Avatars({
    required this.userIds,
    required this.entries,
    required this.isDark,
  });

  final List<String> userIds;
  final Map<String, LeagueRankEntry> entries;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final known = [
      for (final uid in userIds)
        if (entries[uid] != null) entries[uid]!,
    ];
    if (known.isEmpty) return const SizedBox.shrink();
    final head = known.take(3).toList(growable: false);
    final rest = known.length - head.length;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < head.length; i++)
        Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 0),
          child: UserAvatar(
              username: head[i].username,
              avatarUrl: head[i].avatarUrl,
              radius: 12,
              isDark: isDark),
        ),
      if (rest > 0)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('+$rest',
              style: AppTextStyles.bodySmall.copyWith(color: sub)),
        ),
    ]);
  }
}
```

> `leagueDetailProvider` / `leagueTeamsProvider` / `leagueRankingProvider` 는 `league_repository.dart` 에 있다. `currentUserProvider` 는 `features/auth/data/auth_repository.dart` 에 있으므로 `import '../../../auth/data/auth_repository.dart';` 를 추가한다.

- [ ] **Step 7: 라우트를 추가한다**

`lib/core/router/app_router.dart` — 팀 관리 라우트(249-256) **뒤**, 참가자 상세 라우트 **앞**에:

```dart
      // 내 팀 선택 (참가자, 자율 선택 리그): ShellRoute 밖 → 하단 탭 없음
      GoRoute(
        path: '/league/my-team/:leagueId',
        builder: (context, state) => LeagueMyTeamScreen(
          leagueId: state.pathParameters['leagueId']!,
        ),
      ),
```

`:344` 의 `leagueTeams` 상수 아래:

```dart
  static const String leagueMyTeam = '/league/my-team';
```

import 를 추가한다:

```dart
import '../../features/league/presentation/screens/league_my_team_screen.dart';
```

> `league_team_manage_screen.dart` 의 import 가 어떤 상대 경로로 쓰였는지 확인해 같은 형태로 쓴다.

- [ ] **Step 8: 컴파일 + 전체 테스트**

Run: `flutter analyze lib test 2>&1 | grep -E "error" | head -20; flutter test`
Expected: `error` 줄 없음, `+68: All tests passed!` (65 + 신규 3).

- [ ] **Step 9: 일반 리그에서 추가 쿼리가 0회인지 확인한다**

`leagueTeamsProvider` / `currentUserProvider` 를 쓰는 곳이 전부 팀전·자율 모드 가드 안에 있어야 한다. 일반 리그가 팀 쿼리를 날리면 안 된다.

Run:

```bash
grep -rn "leagueTeamsProvider" lib/features/league/presentation/
```

Expected: 네 곳 — `league_team_ranking_tab.dart`(팀 탭 자체가 `isTeamMode` 일 때만 그려짐), `league_ranking_tab.dart`(`if (league.isTeamMode)` 가드 안), `league_team_manage_screen.dart`(호스트 전용 화면), `league_my_team_screen.dart`(배너에서만 진입). 가드 밖에서 쓰이는 곳이 있으면 고친다.

- [ ] **Step 10: Commit**

```bash
git add lib/features/league/presentation/widgets/league_my_team_banner.dart \
        lib/features/league/presentation/screens/league_my_team_screen.dart \
        lib/features/league/presentation/widgets/league_team_ranking_tab.dart \
        lib/core/router/app_router.dart \
        test/features/league/team_assign_mode_test.dart
git commit -m "feat(league): 참가자 내 팀 배너 + 내 팀 선택 화면

배너는 자율 선택 + 승인 참가자일 때만 그린다 — 호스트 배정 리그에
그리면 누를 수 없는 버튼을 보여주는 셈이다.
내 팀은 이미 한 자리를 차지하므로 꽉 차 보여도 비활성하지 않는다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 8: 회귀 체크리스트 + 최종 검증

**Files:**
- Modify: `docs/REGRESSION_TEST.md`

**Interfaces:**
- Consumes: Task 1-7 전부
- Produces: 없음 (문서)

- [ ] **Step 1: 전체 테스트와 정적 분석을 돌린다**

Run: `flutter analyze lib test 2>&1 | tail -5; flutter test`
Expected: analyze `error` 0건, `+68: All tests passed!`.

- [ ] **Step 2: prod 데이터 불변식을 확인한다**

Run:

```bash
PGPASSWORD="$DB_PW" psql "postgresql://postgres.zpcmpfrswlbnqkqrmvxu@aws-1-ap-south-1.pooler.supabase.com:5432/postgres" -c "
-- 기존 리그가 전부 host / 0 인가 (테스트 리그 제외)
select team_assign_mode, team_capacity, count(*) from public.leagues group by 1,2;
-- 배정 수가 변하지 않았는가
select count(*) as participants, count(team_id) as assigned from public.league_participants;
-- 조과가 변하지 않았는가
select count(*) as posts, count(league_id) as league_posts from public.posts where coalesce(is_deleted,false)=false;
-- 고아 조과 (리그가 사라진 조과)
select count(*) as orphan_posts from public.posts p
  where p.league_id is not null
    and not exists (select 1 from public.leagues l where l.id = p.league_id);
-- 팀이 다른 리그의 참가자를 갖고 있지 않은가
select count(*) as cross_league from public.league_participants lp
  join public.league_teams t on t.id = lp.team_id
  where t.league_id <> lp.league_id;
"
```

Expected: `host|0` 행만 (자율 모드로 바꾼 테스트 리그가 있으면 `self` 행 1개 허용), `assigned` = 15, `orphan_posts` = 0, `cross_league` = 0.

- [ ] **Step 3: 회귀 체크리스트를 추가한다**

`docs/REGRESSION_TEST.md` 의 팀전 섹션 끝에 추가한다:

```markdown
### 팀전 v2 — 팀 배정 방식 (2026-11-23)

#### 기존 기능 비회귀 (팀전을 쓰지 않는 리그)

- [ ] 일반 리그 상세: 탭 개수·순서가 이전과 같다 (팀 순위 탭 없음)
- [ ] 일반 리그 개인 순위 탭: 팀 배지가 없고 하단 조과 등록 버튼이 있다
- [ ] 일반 리그 개설 화면: 팀전 토글이 꺼져 있고 하위 설정(배정 방식·정원)이 보이지 않는다
- [ ] 일반 리그 목록 / 내 리그: 이전과 동일하게 뜬다
- [ ] 기존 리그를 수정 저장했을 때 `team_capacity` 가 0 그대로다 (정원이 생기지 않는다)

#### 팀전 — 호스트 배정 모드 (v1 동작 유지)

- [ ] 팀 순위 탭에 **내 팀 배너가 보이지 않는다** (누를 수 없는 버튼을 보여주면 안 된다)
- [ ] 팀 관리: 팀 카드가 **기본으로 접혀** 있고 한 줄에 색·이름·인원이 보인다
- [ ] 팀 카드를 탭하면 펼쳐지고 멤버 줄 + `팀원 추가` 버튼이 나온다
- [ ] 정원 0(무제한)이면 카드에 `N명` 으로 표시된다
- [ ] 멤버 줄 탭 → 팀 선택 시트 → 다른 팀으로 이동된다
- [ ] 팀이 8개 이상이면 팀 선택 시트에 검색창이 나오고 필터가 된다
- [ ] 팀 이름 변경 / 색 변경 / 삭제가 v1 과 동일하게 동작한다
- [ ] 팀 삭제 시 멤버가 미배정으로 돌아가고 조과가 유지된다

#### 팀전 — 정원

- [ ] 팀 관리 상단의 `팀당 정원` 스테퍼로 정원을 바꿀 수 있다
- [ ] 정원을 5로 두면 카드에 `3 / 5` 로 표시된다
- [ ] 정원이 찬 팀의 `팀원 추가` 버튼이 `정원이 찼습니다` 로 비활성된다
- [ ] 정원을 **현재 인원보다 작게** 줄이면 `6 / 5` 로 경고색 표시되고 멤버는 빠지지 않는다
- [ ] 그 초과 상태에서 멤버를 **빼는** 배정이 성공한다 (복구 가능해야 한다)
- [ ] 그 초과 상태에서 멤버를 **더 넣는** 배정이 `방금 정원이 찼습니다` 로 거부된다

#### 팀전 — 팀원 다중 추가

- [ ] 펼친 팀의 `팀원 추가 · N자리 남음` → 체크박스 시트가 뜬다
- [ ] 검색으로 이름 필터가 되고, 다른 팀 소속도 결과에 나오며 현재 소속이 표시된다
- [ ] 남은 자리를 넘는 줄이 `자리 없음` 으로 비활성된다
- [ ] `전체 선택` 이 남은 자리만큼만 고른다
- [ ] 확인 시 고른 인원이 **한 번에** 그 팀으로 들어간다
- [ ] 아무도 안 고르면 하단 버튼이 비활성이다

#### 팀전 — 셔플 되돌리기

- [ ] `자동 셔플` 성공 시 스낵바에 `되돌리기` 액션이 있다
- [ ] 스낵바가 사라진 뒤에도 요약 바에 `되돌리기` 버튼이 남는다
- [ ] `되돌리기` 를 누르면 셔플 **직전** 배정으로 정확히 복구되고 버튼이 사라진다
- [ ] 정원이 작아 전원을 못 담는 상태(참가자 > 팀 수 × 정원)에서 셔플이 `정원이 너무 작습니다` 로 거부된다
- [ ] 되돌리기 전에 팀을 삭제하면 되돌리기가 실패하고 **버튼이 사라진다** (반복 실패 방지)
- [ ] 화면을 나갔다 다시 들어오면 `되돌리기` 버튼이 없다 (스냅샷은 화면 state)

#### 팀전 — 참가자 자율 선택

- [ ] 개설 화면에서 `참가자가 선택` 을 고르면 안내 문구가 바뀐다
- [ ] 자율 모드 리그의 팀 순위 탭 최상단에 배너가 뜬다 (미배정이면 큰 카드, 배정됐으면 한 줄)
- [ ] `내 팀 선택` → 팀 목록에 `3 / 5 · 2자리 남음` 과 멤버 아바타가 보인다
- [ ] 정원이 찬 팀은 흐리게 + 자물쇠 + `정원 마감` 이고 탭이 안 된다
- [ ] **현재 내 팀은 정원이 차 있어도 흐려지지 않는다** (내가 한 자리를 차지하고 있다)
- [ ] 팀을 고르면 즉시 반영되고 이전 화면으로 돌아가며 순위가 갱신된다
- [ ] `팀에서 나가기` → 미배정이 되고, 배너가 미배정 상태로 바뀐다
- [ ] 미배정이면 `팀에서 나가기` 버튼이 보이지 않는다
- [ ] 자율 모드인데 팀이 0개면 배너가 `호스트가 팀을 만들면...` 이고 버튼이 비활성이다
- [ ] 자율 모드에서도 **호스트는 팀 관리로 계속 배정·셔플할 수 있다**
- [ ] `self` → `host` 로 바꾸면 기존 배정이 유지되고 배너만 사라진다

#### DB 불변식 (psql)

```sql
-- 기존 리그는 전부 host / 0 이어야 한다
select team_assign_mode, team_capacity, count(*) from public.leagues group by 1,2;

-- 팀이 다른 리그의 참가자를 갖고 있으면 안 된다
select count(*) from public.league_participants lp
  join public.league_teams t on t.id = lp.team_id
  where t.league_id <> lp.league_id;   -- 0 이어야 한다

-- 고아 조과가 없어야 한다
select count(*) from public.posts p
  where p.league_id is not null
    and not exists (select 1 from public.leagues l where l.id = p.league_id);  -- 0

-- 참가자 본인은 team_id 를 직접 UPDATE 할 수 없어야 한다 (RLS 호스트 전용)
select polname, polcmd from pg_policy
  where polrelid='public.league_participants'::regclass and polcmd='w';
  -- 'League hosts can update participants.' 하나만 나와야 한다
```
```

- [ ] **Step 4: Commit**

```bash
git add docs/REGRESSION_TEST.md
git commit -m "docs(league): 팀전 v2 회귀 체크리스트

비회귀 5항목, 호스트 배정 8, 정원 6, 다중 추가 6,
셔플 되돌리기 6, 자율 선택 11, DB 불변식 4개 쿼리.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## 실행 메모

- **Task 1 은 prod DB 를 직접 바꾼다.** Step 2 의 스냅샷 출력을 반드시 기록한 뒤 적용하고, Step 4 에서 `host|0` 외의 행이 나오면 즉시 중단한다.
- DB 비밀번호는 사용자에게 받아 `PGPASSWORD` 환경변수로만 쓴다. 파일·커밋·문서에 남기지 않는다.
- Task 5 의 `_addMembers` 는 의도적인 스텁이다. Task 6 Step 6 이 교체한다. Task 5 만 끝낸 상태로 중단하면 `팀원 추가` 가 "준비 중입니다"를 띄운다.
- 계획이 쓰는 심볼은 전부 실존을 확인했다: `AppTextStyles`(`heading3`/`heading4`/`body`/`bodySmall`/`caption`), `AppButtonVariant.outline`, `AppButtonSize.sm`, `AppCard`(`margin`/`tintColor`/`tintAlpha`/`radius`/`borderColor`), `AppTextField`(`controller`/`hint`/`onChanged`), `AppSnackBar`(`success`/`error`/`warning`/`info`), `LucideIcons`(`undo2`/`userPlus`/`lock`/`chevronUp`/`chevronDown`/`minus`/`plus`/`shuffle`/`users`/`check`/`userMinus`), `leagueDetailProvider`/`leagueTeamsProvider`/`leagueRankingProvider`/`currentUserProvider`.
- `AppTextStyles` 는 Material 이름(`titleSmall`, `labelLarge`, `bodyMedium`)을 **쓰지 않는다.** 새 멤버를 추가하지 말고 위 이름만 쓴다.
- push 는 사용자가 명시적으로 요청할 때만. 기본 브랜치는 `develop`.
