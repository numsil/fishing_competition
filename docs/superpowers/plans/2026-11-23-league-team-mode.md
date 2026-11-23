# 리그 팀전(Team Mode) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 리그에 호스트가 켜고 끌 수 있는 팀전 옵션을 추가한다. 팀 점수는 팀원 각자의 기존 개인 점수 합계이며, 점수 계산 로직은 바꾸지 않는다.

**Architecture:** DB에는 "누가 어느 팀인지"만 추가한다(`league_teams` 테이블 + `league_participants.team_id` + `leagues.is_team_mode`). 기존 `get_league_ranking` RPC는 손대지 않고 그대로 재사용하고, 그 결과를 순수 Dart 함수가 `team_id` 로 묶어 합산한다. 팀 집계용 RPC는 만들지 않으며, 신규 RPC는 균등 분배용 `shuffle_league_teams` 하나다.

**Tech Stack:** Flutter 3.41.9, Riverpod (riverpod_annotation codegen), freezed/json_serializable, go_router, Supabase (PostgreSQL + RLS + PostgREST)

**Spec:** `docs/superpowers/specs/2026-11-23-league-team-mode-design.md`
**화면 목업:** https://claude.ai/artifact/CvaGxrctkMywiAGamHYDBa

## Global Constraints

- 아키텍처: **UI → Provider → Repository → Supabase.** UI/Provider 에서 직접 쿼리 금지.
- `select('*')` 금지. 필요한 컬럼만 select.
- 반복문 안에서 쿼리 금지 (N+1).
- 스키마 변경은 **반드시 마이그레이션 파일**로. SQL Editor 에서 DDL 실행 금지.
- `supabase db push` / `db pull` 사용 금지 (Docker 필요). psql 직접 사용:
  `PGPASSWORD='<DB_PW>' psql "postgresql://postgres.zpcmpfrswlbnqkqrmvxu@aws-1-ap-south-1.pooler.supabase.com:5432/postgres" -f supabase/migrations/<파일>.sql`
- **DB 비밀번호는 코드/문서/커밋에 절대 하드코딩 금지.** 사용자가 직접 입력한다.
- 공통 위젯 사용: `AppCard`, `AppButton`, `AppTextField`, `UserAvatar`, `EmptyState`, `AppSvg`. Flutter 기본 위젯 직접 스타일링 금지.
- 색상은 `AppColors` 만 사용. `Color(0xFF...)` 하드코딩 금지. 폰트는 `AppTextStyles`.
- `supabase_old/` 는 건드리지 않는다.
- **push 는 사용자가 명시적으로 요청할 때만.** 커밋까지만 수행한다.
- 커밋 메시지 끝에 `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`
- 기존 기능 절대 유지. `is_team_mode = false` 인 리그는 동작/화면이 지금과 100% 동일해야 한다.

## Review Focus

1. **팀 미배정 참가자** — `team_id IS NULL` 인 참가자가 어느 팀 점수에도 섞이지 않고, 팀 탭 맨 아래 "미배정" 그룹으로만 나와야 한다. (Task 3 테스트)
2. **`마릿수` 룰 정렬** — 이 룰에서는 `totalLength` 가 0이라, 측정값으로 정렬하면 전 팀이 동점이 된다. 마릿수 룰은 `totalCount` 로 정렬해야 한다. (Task 3 테스트)
3. **조과 0마리 참가자** — `get_league_ranking` 은 조과가 없는 승인 참가자도 0점 행으로 반환한다. 이들이 팀 인원수에는 포함되고 점수에는 0으로 들어가야 한다. (Task 3 테스트)
4. **팀 0개인 팀전 리그** — `is_team_mode = true` 인데 팀이 하나도 없을 때 팀 탭이 빈 화면/예외 없이 안내 문구를 보여야 한다. (Task 6)
5. **참가자가 자기 팀을 바꾸는 것** — `league_participants` 의 기존 UPDATE 정책으로 본인 행을 수정할 수 있다면 `team_id` 도 바꿀 수 있다. 트리거로 호스트/admin 외의 `team_id` 변경을 거부해야 한다. (Task 1 SQL 검증)

---

### Task 1: DB 스키마 + RLS + 셔플 RPC

**Files:**
- Create: `supabase/migrations/20261123090000_league_team_mode.sql`

**Interfaces:**
- Consumes: 기존 `leagues`, `league_participants`, `users` 테이블, 기존 `get_league_ranking(uuid)` RPC
- Produces:
  - 테이블 `public.league_teams (id uuid, league_id uuid, name text, color text, sort_order int, created_at timestamptz)`
  - 컬럼 `public.league_participants.team_id uuid NULL`
  - 컬럼 `public.leagues.is_team_mode boolean NOT NULL DEFAULT false`
  - RPC `public.shuffle_league_teams(p_league_id uuid) RETURNS void` — 예외: `AUTH_REQUIRED`, `LEAGUE_NOT_FOUND`, `NOT_LEAGUE_HOST`, `NO_TEAMS`

- [ ] **Step 1: 현재 스키마/정책 상태를 먼저 확인한다**

사용자에게 DB 비밀번호를 요청한 뒤 (`!` 프리픽스로 직접 실행하게 하거나 받아서 사용), 아래를 실행해 **기존 정책 이름과 FK 상태**를 기록한다. 이 결과에 따라 Step 2 의 정책 이름 충돌 여부를 판단한다.

```bash
PGPASSWORD='<DB_PW>' psql "postgresql://postgres.zpcmpfrswlbnqkqrmvxu@aws-1-ap-south-1.pooler.supabase.com:5432/postgres" -c "
SELECT polname, polcmd, pg_get_expr(polqual, polrelid) AS using_expr
FROM pg_policy WHERE polrelid = 'public.league_participants'::regclass;
SELECT conname, conrelid::regclass::text AS tbl, confrelid::regclass::text AS ref, confdeltype::text
FROM pg_constraint WHERE conrelid = 'public.league_participants'::regclass AND contype = 'f';
SELECT column_name FROM information_schema.columns
WHERE table_schema='public' AND table_name='leagues' AND column_name='is_team_mode';
"
```

Expected: `league_participants` 의 기존 정책 목록이 나오고, `is_team_mode` 행은 0개(아직 없음).

- [ ] **Step 2: 마이그레이션 파일을 작성한다**

`supabase/migrations/20261123090000_league_team_mode.sql`:

```sql
-- 리그 팀전(Team Mode) 스키마
--
-- 설계: docs/superpowers/specs/2026-11-23-league-team-mode-design.md
--
-- 핵심: 점수 계산 로직은 건드리지 않는다. get_league_ranking 은 그대로 두고,
--       "누가 어느 팀인지"만 저장한다. 팀 점수 = 팀원 개인 점수의 합이며
--       클라이언트가 이미 받아온 개인 순위를 team_id 로 묶어 계산한다.
--
-- posts 는 손대지 않는다. 팀 소속이 사람에만 붙어 있으므로 진행 중 팀을
-- 옮겨도 그 사람의 조과가 통째로 새 팀으로 따라간다.

BEGIN;

-- ── 1. 팀 테이블 ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.league_teams (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  league_id  uuid NOT NULL REFERENCES public.leagues(id) ON DELETE CASCADE,
  name       text NOT NULL,
  color      text,
  sort_order int  NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT league_teams_name_not_blank CHECK (btrim(name) <> ''),
  CONSTRAINT league_teams_league_id_name_key UNIQUE (league_id, name)
);

-- 팀은 리그 종속 메타데이터이고 조과를 담지 않으므로 CASCADE 로 둔다.
-- 조과 보호는 posts.league_id 의 RESTRICT 가 담당한다
-- (20261117090000_league_cancel_instead_of_delete.sql).

CREATE INDEX IF NOT EXISTS league_teams_league_id_idx
  ON public.league_teams (league_id);

-- ── 2. 참가자에 팀 소속 ───────────────────────────────────────
ALTER TABLE public.league_participants
  ADD COLUMN IF NOT EXISTS team_id uuid;

ALTER TABLE public.league_participants
  DROP CONSTRAINT IF EXISTS league_participants_team_id_fkey;

-- 팀을 지우면 멤버는 "미배정"으로 돌아가고 조과는 그대로 남는다.
ALTER TABLE public.league_participants
  ADD CONSTRAINT league_participants_team_id_fkey
  FOREIGN KEY (team_id) REFERENCES public.league_teams(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS league_participants_team_id_idx
  ON public.league_participants (team_id) WHERE team_id IS NOT NULL;

-- ── 3. 리그 옵션 ──────────────────────────────────────────────
ALTER TABLE public.leagues
  ADD COLUMN IF NOT EXISTS is_team_mode boolean NOT NULL DEFAULT false;

-- 팀 전용 집계 설정(team_catch_limit 등)은 두지 않는다.
-- 기존 rule / catch_limit 이 각 개인에게 그대로 적용된다.

-- ── 4. 호스트 판별 헬퍼 ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.is_league_host(p_league_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.leagues l
    WHERE l.id = p_league_id AND l.host_id = auth.uid()
  ) OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() AND u.role = 'admin'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_league_host(uuid) TO authenticated;

-- ── 5. league_teams RLS ───────────────────────────────────────
ALTER TABLE public.league_teams ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "league_teams_select" ON public.league_teams;
CREATE POLICY "league_teams_select" ON public.league_teams
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "league_teams_host_insert" ON public.league_teams;
CREATE POLICY "league_teams_host_insert" ON public.league_teams
  FOR INSERT WITH CHECK (public.is_league_host(league_id));

DROP POLICY IF EXISTS "league_teams_host_update" ON public.league_teams;
CREATE POLICY "league_teams_host_update" ON public.league_teams
  FOR UPDATE USING (public.is_league_host(league_id))
  WITH CHECK (public.is_league_host(league_id));

DROP POLICY IF EXISTS "league_teams_host_delete" ON public.league_teams;
CREATE POLICY "league_teams_host_delete" ON public.league_teams
  FOR DELETE USING (public.is_league_host(league_id));

-- ── 6. team_id 변경은 호스트만 ────────────────────────────────
-- league_participants 의 기존 UPDATE 정책은 "본인 행 수정"을 허용할 수 있다.
-- 정책은 컬럼 단위 제한이 안 되므로, team_id 변경만 트리거로 막는다.
CREATE OR REPLACE FUNCTION public.guard_league_participant_team_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NEW.team_id IS DISTINCT FROM OLD.team_id THEN
    -- SET NULL (팀 삭제) 등 서버 내부 동작은 auth.uid() 가 없다.
    IF auth.uid() IS NOT NULL AND NOT public.is_league_host(NEW.league_id) THEN
      RAISE EXCEPTION 'NOT_LEAGUE_HOST';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS league_participants_team_id_guard
  ON public.league_participants;
CREATE TRIGGER league_participants_team_id_guard
  BEFORE UPDATE ON public.league_participants
  FOR EACH ROW EXECUTE FUNCTION public.guard_league_participant_team_id();

-- ── 7. 자동 셔플 ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.shuffle_league_teams(p_league_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_team_count int;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.leagues WHERE id = p_league_id) THEN
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
END;
$$;

GRANT EXECUTE ON FUNCTION public.shuffle_league_teams(uuid) TO authenticated;

COMMIT;
```

- [ ] **Step 3: 적용 전 문법을 확인한다**

마이그레이션 파일 안에 `COMMIT` 이 있어 `\i` 로 감싼 롤백 트랜잭션은 성립하지 않는다.
따라서 동작 검증은 Step 5(적용 후 별도 롤백 트랜잭션)에서 하고, 여기서는 문법만 본다.

```bash
# 세미콜론/따옴표/달러쿼팅 짝이 맞는지 파서에 통과시켜 본다.
# ON_ERROR_STOP + 즉시 ROLLBACK 이므로 아무것도 반영되지 않는다.
PGPASSWORD='<DB_PW>' psql "postgresql://postgres.zpcmpfrswlbnqkqrmvxu@aws-1-ap-south-1.pooler.supabase.com:5432/postgres" <<'SQL'
\set ON_ERROR_STOP on
BEGIN;
CREATE TEMP TABLE syntax_probe AS SELECT 1;
ROLLBACK;
SQL
grep -c 'BEGIN;' supabase/migrations/20261123090000_league_team_mode.sql
grep -c 'COMMIT;' supabase/migrations/20261123090000_league_team_mode.sql
```

Expected: psql 접속 성공, `BEGIN;` 1개 / `COMMIT;` 1개.
파일을 눈으로 읽어 `$$` 짝과 `GRANT EXECUTE` 누락이 없는지도 확인한다.

- [ ] **Step 4: prod 에 적용한다**

```bash
PGPASSWORD='<DB_PW>' psql "postgresql://postgres.zpcmpfrswlbnqkqrmvxu@aws-1-ap-south-1.pooler.supabase.com:5432/postgres" \
  -f supabase/migrations/20261123090000_league_team_mode.sql
```

Expected: `CREATE TABLE` / `ALTER TABLE` / `CREATE FUNCTION` / `COMMIT` 출력, 에러 없음.

- [ ] **Step 5: 롤백 트랜잭션으로 권한·트리거·셔플을 검증한다**

실제 유저로 가장해 검증한다. `<HOST_UID>` 는 테스트용 리그의 호스트, `<OTHER_UID>` 는 `role='user'` 인 다른 유저.

```bash
PGPASSWORD='<DB_PW>' psql "postgresql://postgres.zpcmpfrswlbnqkqrmvxu@aws-1-ap-south-1.pooler.supabase.com:5432/postgres" <<'SQL'
\set ON_ERROR_STOP off
BEGIN;

-- 테스트 리그 하나 고르기
CREATE TEMP TABLE t AS
SELECT id AS league_id, host_id FROM public.leagues ORDER BY created_at DESC LIMIT 1;

-- (1) 호스트로 팀 2개 생성 + 셔플
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
  json_build_object('sub', (SELECT host_id::text FROM t), 'role', 'authenticated')::text, true);

INSERT INTO public.league_teams (league_id, name, color, sort_order)
VALUES ((SELECT league_id FROM t), 'TEST A', 'red', 0),
       ((SELECT league_id FROM t), 'TEST B', 'blue', 1);

SELECT public.shuffle_league_teams((SELECT league_id FROM t));

-- 기대: 승인 참가자가 두 팀에 균등 분배 (개수 차이 ≤ 1)
SELECT t2.name, count(lp.user_id) AS members
FROM public.league_teams t2
LEFT JOIN public.league_participants lp ON lp.team_id = t2.id
WHERE t2.league_id = (SELECT league_id FROM t)
GROUP BY t2.name ORDER BY t2.name;

-- (2) 다른 유저가 셔플 → NOT_LEAGUE_HOST
SELECT set_config('request.jwt.claims',
  json_build_object('sub', (SELECT id::text FROM public.users
                            WHERE role = 'user' AND id <> (SELECT host_id FROM t) LIMIT 1),
                    'role', 'authenticated')::text, true);
SELECT public.shuffle_league_teams((SELECT league_id FROM t));

-- (3) 다른 유저가 자기 team_id 변경 → NOT_LEAGUE_HOST (트리거)
UPDATE public.league_participants
SET team_id = (SELECT id FROM public.league_teams
               WHERE league_id = (SELECT league_id FROM t) LIMIT 1)
WHERE user_id = auth.uid() AND league_id = (SELECT league_id FROM t);

-- (4) 팀 삭제 → 멤버 team_id 가 NULL, 참가자 행은 살아 있음
SELECT set_config('request.jwt.claims',
  json_build_object('sub', (SELECT host_id::text FROM t), 'role', 'authenticated')::text, true);
DELETE FROM public.league_teams WHERE name = 'TEST A'
  AND league_id = (SELECT league_id FROM t);
SELECT count(*) AS still_approved FROM public.league_participants
WHERE league_id = (SELECT league_id FROM t) AND status = 'approved';

RESET ROLE;
ROLLBACK;
SQL
```

Expected:
- (1) 두 팀의 `members` 차이가 1 이하
- (2) `ERROR: NOT_LEAGUE_HOST`
- (3) `ERROR: NOT_LEAGUE_HOST`
- (4) 삭제 성공 + `still_approved` 가 삭제 전과 동일

- [ ] **Step 6: PostgREST embed 회귀를 확인한다**

과거 FK 추가로 PGRST201 장애가 났던 이력이 있다. `<ANON_KEY>` 는 `.env` 또는 Supabase 대시보드의 publishable key 를 쓴다. 아래 **5개 모두 200** 이어야 한다.

```bash
BASE="https://zpcmpfrswlbnqkqrmvxu.supabase.co/rest/v1"
for q in \
  "league_participants?select=id,users(username,avatar_url)&limit=1" \
  "league_participants?select=user_id,team_id&limit=1" \
  "league_teams?select=id,name,color,sort_order,league_participants(user_id)&limit=1" \
  "leagues?select=id,status,is_team_mode&limit=1" \
  "posts?select=id,users(username,avatar_url)&limit=1" ; do
  printf '%s -> ' "$q"
  curl -s -o /dev/null -w '%{http_code}\n' \
    -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" "$BASE/$q"
done
```

Expected: 다섯 줄 모두 `200`. 하나라도 `300` (PGRST201 ambiguity) 이면 즉시 중단하고 보고한다.

- [ ] **Step 7: 커밋**

```bash
git add supabase/migrations/20261123090000_league_team_mode.sql
git commit -m "$(cat <<'EOF'
feat(league): 팀전 스키마 추가 (league_teams, team_id, is_team_mode)

- league_teams 테이블 (리그 CASCADE, 리그 내 팀명 UNIQUE)
- league_participants.team_id (팀 삭제 시 SET NULL → 조과 유지)
- leagues.is_team_mode (기본 false, 기존 리그 동작 불변)
- 호스트 전용 RLS + team_id 변경을 막는 트리거
- shuffle_league_teams RPC (라운드로빈 균등 분배)

get_league_ranking 과 점수 로직은 손대지 않았다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: 모델 + 리포지토리 + 프로바이더

**Files:**
- Create: `lib/features/league/data/league_team_model.dart`
- Modify: `lib/features/league/data/league_model.dart` (freezed `League` 에 `isTeamMode` 추가)
- Modify: `lib/features/league/data/league_repository.dart` (팀 CRUD/배정 메서드 + `leagueTeams` 프로바이더, `createLeague`/`updateLeague` 에 `isTeamMode`)
- Modify: `lib/features/league/presentation/screens/league_create_screen.dart` (Task 4 에서 UI 추가 — 여기서는 건드리지 않는다)

**Interfaces:**
- Consumes: Task 1 의 `league_teams` 테이블, `league_participants.team_id`, `leagues.is_team_mode`, `shuffle_league_teams` RPC
- Produces:
  - `class LeagueTeam { String id; String leagueId; String name; String? color; int sortOrder; List<String> memberUserIds; }`
  - `LeagueRepository.getLeagueTeams(String leagueId) → Future<List<LeagueTeam>>`
  - `LeagueRepository.createLeagueTeam({required String leagueId, required String name, String? color, int sortOrder = 0}) → Future<void>`
  - `LeagueRepository.updateLeagueTeam({required String teamId, String? name, String? color}) → Future<void>`
  - `LeagueRepository.deleteLeagueTeam(String teamId) → Future<void>`
  - `LeagueRepository.assignParticipantTeam({required String leagueId, required String userId, String? teamId}) → Future<void>`
  - `LeagueRepository.shuffleLeagueTeams(String leagueId) → Future<void>`
  - `leagueTeamsProvider(String leagueId) → AsyncValue<List<LeagueTeam>>`
  - `League.isTeamMode → bool` (JSON key `is_team_mode`, 기본 `false`)

- [ ] **Step 1: `LeagueTeam` 모델을 만든다**

`lib/features/league/data/league_team_model.dart` (기존 `LeagueRankEntry` 와 같은 plain class 스타일. freezed 를 쓰지 않으므로 codegen 불필요):

```dart
/// 리그 팀 (팀전 전용).
///
/// 점수는 담지 않는다. 팀 점수는 팀원 각자의 개인 점수 합이므로
/// `buildTeamRanking` 이 순위 결과와 이 모델을 합쳐 계산한다.
class LeagueTeam {
  const LeagueTeam({
    required this.id,
    required this.leagueId,
    required this.name,
    required this.sortOrder,
    this.color,
    this.memberUserIds = const [],
  });

  final String id;
  final String leagueId;
  final String name;
  final String? color;
  final int sortOrder;

  /// 이 팀에 배정된 참가자 user_id 목록 (승인 여부와 무관하게 DB 그대로).
  final List<String> memberUserIds;

  factory LeagueTeam.fromRow(Map<String, dynamic> row) {
    final members = (row['league_participants'] as List?) ?? const [];
    return LeagueTeam(
      id: row['id'] as String,
      leagueId: row['league_id'] as String,
      name: row['name'] as String,
      color: row['color'] as String?,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      memberUserIds: members
          .map((m) => (m as Map<String, dynamic>)['user_id'] as String)
          .toList(growable: false),
    );
  }
}
```

- [ ] **Step 2: `League` 모델에 `isTeamMode` 를 추가한다**

`lib/features/league/data/league_model.dart` 에서 `allowGallery` 바로 아래에 한 줄 추가:

```dart
    @JsonKey(name: 'allow_gallery') @Default(true) bool allowGallery,
    @JsonKey(name: 'is_team_mode') @Default(false) bool isTeamMode,
```

- [ ] **Step 3: 리포지토리에 팀 메서드를 추가한다**

`lib/features/league/data/league_repository.dart` 상단 import 에 모델을 추가하고:

```dart
import 'league_team_model.dart';
```

`updateLeague` 메서드 바로 뒤(클래스 닫는 중괄호 앞)에 아래를 추가한다:

```dart
  // ── 팀전 (Team Mode) ───────────────────────────────────────
  //
  // 팀 집계용 RPC 는 만들지 않는다. 팀 점수는 이미 받아온 개인 순위
  // (get_league_ranking) 를 team_id 로 묶어 더한 값이므로, 여기서는
  // "누가 어느 팀인지"만 가져온다. 빈 팀도 나와야 하므로 league_teams
  // 를 기준으로 조회하고 참가자를 embed 한다 (쿼리 1회).

  Future<List<LeagueTeam>> getLeagueTeams(String leagueId) async {
    final rows = await _supabase
        .from('league_teams')
        .select('id, league_id, name, color, sort_order, league_participants(user_id)')
        .eq('league_id', leagueId)
        .order('sort_order')
        .order('created_at');
    return (rows as List)
        .map((r) => LeagueTeam.fromRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> createLeagueTeam({
    required String leagueId,
    required String name,
    String? color,
    int sortOrder = 0,
  }) async {
    await _supabase.from('league_teams').insert({
      'league_id': leagueId,
      'name': name,
      'color': color,
      'sort_order': sortOrder,
    });
  }

  Future<void> updateLeagueTeam({
    required String teamId,
    String? name,
    String? color,
  }) async {
    final update = <String, dynamic>{};
    if (name != null) update['name'] = name;
    if (color != null) update['color'] = color;
    if (update.isEmpty) return;
    await _supabase.from('league_teams').update(update).eq('id', teamId);
  }

  /// 팀을 지우면 FK ON DELETE SET NULL 로 멤버가 미배정으로 돌아간다.
  /// 조과(posts)는 영향을 받지 않는다.
  Future<void> deleteLeagueTeam(String teamId) async {
    await _supabase.from('league_teams').delete().eq('id', teamId);
  }

  /// teamId == null 이면 미배정으로 되돌린다.
  Future<void> assignParticipantTeam({
    required String leagueId,
    required String userId,
    String? teamId,
  }) async {
    await _supabase
        .from('league_participants')
        .update({'team_id': teamId})
        .eq('league_id', leagueId)
        .eq('user_id', userId);
  }

  Future<void> shuffleLeagueTeams(String leagueId) async {
    await _supabase.rpc(
      'shuffle_league_teams',
      params: {'p_league_id': leagueId},
    );
  }
```

- [ ] **Step 4: `createLeague` / `updateLeague` 에 `isTeamMode` 를 넘긴다**

`createLeague` 의 시그니처에 `bool isTeamMode = false,` 를 `bool allowGallery = true,` 다음에 추가하고, insert 맵에 추가:

```dart
      'allow_gallery': allowGallery,
      'is_team_mode': isTeamMode,
```

`updateLeague` 의 시그니처에 `bool? isTeamMode,` 를 `bool? allowGallery,` 다음에 추가하고, update 맵 조립부에서 `allowGallery` 를 다루는 줄 바로 뒤에 추가:

```dart
    if (isTeamMode != null) update['is_team_mode'] = isTeamMode;
```

- [ ] **Step 5: `leagueTeams` 프로바이더를 추가한다**

`leagueRanking` 프로바이더 바로 아래에 추가한다. 캐싱 규칙(리스트 5분 TTL)을 따른다:

```dart
@riverpod
Future<List<LeagueTeam>> leagueTeams(LeagueTeamsRef ref, String leagueId) {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 5), link.close);
  return ref.watch(leagueRepositoryProvider).getLeagueTeams(leagueId);
}
```

- [ ] **Step 6: 코드 생성을 돌린다**

```bash
cd /Users/jun/Desktop/code/HUK/fishing_competition
dart run build_runner build --delete-conflicting-outputs
```

Expected: `league_model.freezed.dart`, `league_model.g.dart`, `league_repository.g.dart` 가 갱신되고 "Succeeded after ..." 출력.

- [ ] **Step 7: 정적 분석을 돌린다**

```bash
flutter analyze lib/features/league/
```

Expected: `error` 0건. (기존에 있던 `info` 는 그대로 남아도 된다)

- [ ] **Step 8: 커밋**

```bash
git add lib/features/league/data/
git commit -m "$(cat <<'EOF'
feat(league): 팀 모델/리포지토리/프로바이더 추가

- LeagueTeam 모델 (멤버 user_id 를 embed 로 함께 받는다)
- League.isTeamMode
- 팀 CRUD, 참가자 팀 배정, shuffle RPC 호출
- leagueTeamsProvider (5분 TTL)

팀 조회는 빈 팀까지 나오도록 league_teams 기준 1회 쿼리로 처리한다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: 팀 집계 순수 함수 + 단위 테스트

이 태스크가 설계의 핵심이다. **DB 를 거치지 않는 순수 함수**이므로 TDD 로 작성한다.

**Files:**
- Create: `lib/features/league/data/team_ranking.dart`
- Create: `test/features/league/team_ranking_test.dart`

**Interfaces:**
- Consumes: `LeagueRankEntry` (`league_repository.dart`), `LeagueTeam` (`league_team_model.dart`)
- Produces:
  - `class LeagueTeamRank { LeagueTeam? team; List<LeagueRankEntry> members; double totalMeasure; int totalCount; double bestMeasure; bool get isUnassigned; }`
  - `List<LeagueTeamRank> buildTeamRanking({required List<LeagueRankEntry> ranking, required List<LeagueTeam> teams, required String rule})`

- [ ] **Step 1: 실패하는 테스트를 작성한다**

`test/features/league/team_ranking_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fishing_competition/features/league/data/league_repository.dart';
import 'package:fishing_competition/features/league/data/league_team_model.dart';
import 'package:fishing_competition/features/league/data/team_ranking.dart';

LeagueRankEntry entry(
  String userId, {
  double totalLength = 0,
  int totalCount = 0,
  double? bestLength,
}) {
  return LeagueRankEntry(
    userId: userId,
    username: userId,
    bestLength: bestLength,
    totalLength: totalLength,
    totalCount: totalCount,
    totalScore: 0,
    bestScore: 0,
    fishType: '배스',
    isLunker: false,
  );
}

LeagueTeam team(String id, List<String> members, {int sortOrder = 0}) {
  return LeagueTeam(
    id: id,
    leagueId: 'L',
    name: id,
    sortOrder: sortOrder,
    memberUserIds: members,
  );
}

void main() {
  group('buildTeamRanking', () {
    test('팀 점수는 팀원 각자의 개인 점수 합이다', () {
      final result = buildTeamRanking(
        ranking: [
          entry('갑', totalLength: 203, totalCount: 4, bestLength: 92),
          entry('을', totalLength: 86, totalCount: 1, bestLength: 86),
          entry('병', totalLength: 138, totalCount: 2, bestLength: 70),
          entry('정', totalLength: 55, totalCount: 1, bestLength: 55),
          entry('무'),
        ],
        teams: [team('A', ['갑', '을', '병', '정', '무'])],
        rule: '합산 길이',
      );

      expect(result, hasLength(1));
      expect(result.first.totalMeasure, 482);
      expect(result.first.totalCount, 8);
      expect(result.first.bestMeasure, 92);
      // 조과 0마리 참가자도 인원에 포함된다
      expect(result.first.members, hasLength(5));
    });

    test('팀 점수가 높은 순으로 정렬된다', () {
      final result = buildTeamRanking(
        ranking: [
          entry('a', totalLength: 100, totalCount: 1, bestLength: 100),
          entry('b', totalLength: 300, totalCount: 2, bestLength: 160),
        ],
        teams: [team('A', ['a'], sortOrder: 0), team('B', ['b'], sortOrder: 1)],
        rule: '합산 길이',
      );

      expect(result.map((t) => t.team!.name), ['B', 'A']);
    });

    test('마릿수 룰은 totalCount 로 정렬한다', () {
      // 마릿수 룰에서는 totalLength 가 0으로 들어온다.
      // 측정값으로 정렬하면 전 팀이 동점이 되어 순위가 뒤집힌다.
      final result = buildTeamRanking(
        ranking: [
          entry('a', totalCount: 2),
          entry('b', totalCount: 7),
        ],
        teams: [team('A', ['a'], sortOrder: 0), team('B', ['b'], sortOrder: 1)],
        rule: '마릿수',
      );

      expect(result.map((t) => t.team!.name), ['B', 'A']);
      expect(result.first.totalCount, 7);
    });

    test('동점이면 최대어가 큰 팀, 그다음 조과 수가 적은 팀이 앞선다', () {
      final result = buildTeamRanking(
        ranking: [
          entry('a', totalLength: 100, totalCount: 2, bestLength: 60),
          entry('b', totalLength: 100, totalCount: 2, bestLength: 90),
          entry('c', totalLength: 100, totalCount: 4, bestLength: 90),
        ],
        teams: [
          team('A', ['a'], sortOrder: 0),
          team('B', ['b'], sortOrder: 1),
          team('C', ['c'], sortOrder: 2),
        ],
        rule: '합산 길이',
      );

      // B·C 는 점수·최대어 동일 → 조과 수 적은 B 가 앞
      expect(result.map((t) => t.team!.name), ['B', 'C', 'A']);
    });

    test('미배정 참가자는 팀 점수에 섞이지 않고 맨 끝 그룹으로 나온다', () {
      final result = buildTeamRanking(
        ranking: [
          entry('a', totalLength: 100, totalCount: 1, bestLength: 100),
          entry('solo', totalLength: 9999, totalCount: 9, bestLength: 500),
        ],
        teams: [team('A', ['a'])],
        rule: '합산 길이',
      );

      expect(result, hasLength(2));
      expect(result.first.isUnassigned, isFalse);
      expect(result.first.totalMeasure, 100);

      final last = result.last;
      expect(last.isUnassigned, isTrue);
      expect(last.team, isNull);
      expect(last.members.single.userId, 'solo');
    });

    test('팀이 없으면 전원이 미배정 한 그룹이다', () {
      final result = buildTeamRanking(
        ranking: [entry('a', totalLength: 10, totalCount: 1, bestLength: 10)],
        teams: const [],
        rule: '합산 길이',
      );

      expect(result, hasLength(1));
      expect(result.single.isUnassigned, isTrue);
    });

    test('미배정자가 없으면 미배정 그룹을 만들지 않는다', () {
      final result = buildTeamRanking(
        ranking: [entry('a', totalLength: 10, totalCount: 1, bestLength: 10)],
        teams: [team('A', ['a'])],
        rule: '합산 길이',
      );

      expect(result, hasLength(1));
      expect(result.single.isUnassigned, isFalse);
    });

    test('순위에 없는 멤버 id 는 무시한다 (탈퇴·미승인)', () {
      final result = buildTeamRanking(
        ranking: [entry('a', totalLength: 10, totalCount: 1, bestLength: 10)],
        teams: [team('A', ['a', 'ghost'])],
        rule: '합산 길이',
      );

      expect(result.single.members, hasLength(1));
      expect(result.single.totalMeasure, 10);
    });
  });
}
```

- [ ] **Step 2: 테스트를 돌려 실패를 확인한다**

```bash
flutter test test/features/league/team_ranking_test.dart
```

Expected: FAIL — `Error: Couldn't resolve the package 'team_ranking.dart'` 또는 `buildTeamRanking isn't defined`.

- [ ] **Step 3: 최소 구현을 작성한다**

`lib/features/league/data/team_ranking.dart`:

```dart
import 'league_repository.dart' show LeagueRankEntry;
import 'league_team_model.dart';

/// 팀 하나의 순위 행. `team == null` 이면 미배정 그룹이다.
class LeagueTeamRank {
  const LeagueTeamRank({
    required this.team,
    required this.members,
    required this.totalMeasure,
    required this.totalCount,
    required this.bestMeasure,
  });

  final LeagueTeam? team;

  /// 팀 점수 기여가 큰 순으로 정렬된 멤버 (개인 순위 그대로의 값).
  final List<LeagueRankEntry> members;

  /// 팀원 개인 점수(cm 또는 g)의 합.
  final double totalMeasure;

  /// 팀원 마릿수의 합.
  final int totalCount;

  /// 팀 내 최대어 (동점 처리용).
  final double bestMeasure;

  bool get isUnassigned => team == null;
  int get memberCount => members.length;
}

/// 개인 순위를 팀으로 묶어 팀 순위를 만든다.
///
/// 점수 규칙은 전혀 재계산하지 않는다. [ranking] 은 `get_league_ranking`
/// 결과이고, 리그의 rule/catch_limit 은 이미 그 안에서 각 개인에게 적용돼
/// 있다. 여기서 하는 일은 합산과 정렬뿐이다.
///
/// [rule] 이 '마릿수' 면 측정값이 비어 있으므로 마릿수로 정렬한다.
List<LeagueTeamRank> buildTeamRanking({
  required List<LeagueRankEntry> ranking,
  required List<LeagueTeam> teams,
  required String rule,
}) {
  final byUserId = {for (final e in ranking) e.userId: e};
  final isCountRule = rule == '마릿수';

  final assigned = <String>{};
  final rows = <LeagueTeamRank>[];

  for (final team in teams) {
    final members = <LeagueRankEntry>[];
    for (final userId in team.memberUserIds) {
      final e = byUserId[userId];
      if (e == null) continue; // 탈퇴·미승인 → 순위에 없음
      members.add(e);
      assigned.add(userId);
    }
    rows.add(_rank(team, members, isCountRule));
  }

  final leftovers = ranking.where((e) => !assigned.contains(e.userId)).toList();
  final unassigned =
      leftovers.isEmpty ? null : _rank(null, leftovers, isCountRule);

  rows.sort((a, b) {
    if (isCountRule) {
      final c = b.totalCount.compareTo(a.totalCount);
      if (c != 0) return c;
    }
    final m = b.totalMeasure.compareTo(a.totalMeasure);
    if (m != 0) return m;
    final best = b.bestMeasure.compareTo(a.bestMeasure);
    if (best != 0) return best;
    // 같은 점수라면 적은 조과로 낸 팀이 앞선다
    return a.totalCount.compareTo(b.totalCount);
  });

  return [...rows, if (unassigned != null) unassigned];
}

LeagueTeamRank _rank(
  LeagueTeam? team,
  List<LeagueRankEntry> members,
  bool isCountRule,
) {
  var measure = 0.0;
  var count = 0;
  var best = 0.0;
  for (final e in members) {
    measure += e.totalLength;
    count += e.totalCount;
    final b = e.bestLength ?? 0;
    if (b > best) best = b;
  }

  final sorted = [...members]..sort((a, b) {
    if (isCountRule) {
      final c = b.totalCount.compareTo(a.totalCount);
      if (c != 0) return c;
    }
    return b.totalLength.compareTo(a.totalLength);
  });

  return LeagueTeamRank(
    team: team,
    members: sorted,
    totalMeasure: measure,
    totalCount: count,
    bestMeasure: best,
  );
}
```

- [ ] **Step 4: 테스트를 돌려 통과를 확인한다**

```bash
flutter test test/features/league/team_ranking_test.dart
```

Expected: `All tests passed!` (8개 통과)

- [ ] **Step 5: 전체 테스트가 깨지지 않았는지 확인한다**

```bash
flutter test
```

Expected: 기존 테스트 포함 모두 통과.

- [ ] **Step 6: 커밋**

```bash
git add lib/features/league/data/team_ranking.dart test/features/league/team_ranking_test.dart
git commit -m "$(cat <<'EOF'
feat(league): 팀 순위 집계 순수 함수 + 단위 테스트

buildTeamRanking: 개인 순위(get_league_ranking 결과)를 team_id 로 묶어
합산한다. 점수 규칙은 재계산하지 않는다.

- 마릿수 룰은 totalCount 로 정렬 (측정값이 0이라 동점이 되는 것 방지)
- 동점: 최대어 큰 팀 → 조과 수 적은 팀
- 미배정 참가자는 팀 점수에 섞이지 않고 맨 끝 그룹
- 조과 0마리 참가자도 인원에 포함

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: 리그 개설/수정 화면 — 팀전 토글

**Files:**
- Modify: `lib/features/league/presentation/screens/league_create_screen.dart`
- Modify: `lib/core/theme/app_colors.dart` (팀 색상 팔레트 추가)

**Interfaces:**
- Consumes: Task 2 의 `League.isTeamMode`, `createLeague(isTeamMode:)`, `updateLeague(isTeamMode:)`
- Produces: `AppColors.teamColors → Map<String, Color>` (키가 DB `league_teams.color` 에 저장되는 문자열)

- [ ] **Step 1: 팀 색상 팔레트를 `AppColors` 에 추가한다**

`lib/core/theme/app_colors.dart` 의 `liveRed` 정의 아래에 추가한다. **키 문자열이 DB 에 저장되는 값**이므로 바꾸면 기존 데이터가 깨진다.

```dart
  // ── 팀전 팀 색상 ──
  // 키는 league_teams.color 에 저장되는 값이다. 변경 금지.
  // 색상만으로 구분되지 않도록 UI 에서 팀명을 항상 함께 표시한다.
  static const Map<String, Color> teamColors = {
    'red': Color(0xFFE8674B),
    'blue': Color(0xFF4B8FE8),
    'green': Color(0xFF3DD6A0),
    'amber': Color(0xFFE8B84B),
    'purple': Color(0xFFA77BE8),
    'pink': Color(0xFFE86BA8),
  };

  /// 저장된 색 키를 Color 로. 알 수 없는 키/없는 값은 첫 색으로 대체한다.
  static Color teamColor(String? key) =>
      teamColors[key] ?? teamColors.values.first;

  /// 새 팀에 돌아가며 배정할 색 키.
  static String teamColorKeyAt(int index) =>
      teamColors.keys.elementAt(index % teamColors.length);
```

- [ ] **Step 2: 개설 화면 상태에 `_isTeamMode` 를 추가한다**

`league_create_screen.dart` 의 `bool _allowGallery = true;` 다음 줄에:

```dart
  bool _isTeamMode = false;
```

`initState` 의 편집 모드 복원부에서 `_allowGallery = l.allowGallery;` 다음 줄에:

```dart
      _isTeamMode = l.isTeamMode;
```

- [ ] **Step 3: `_submit` 에서 값을 넘긴다**

`_submit` 의 `updateLeague(...)` 호출에서 `allowGallery: _allowGallery,` 다음 줄에, 그리고 `createLeague(...)` 호출에서도 같은 위치에:

```dart
          isTeamMode: _isTeamMode,
```

- [ ] **Step 4: 토글 UI 를 추가한다**

`catch_limit` 칩 블록(현재 `if (_rule != '마릿수' && _rule != '최대어') ...[` 로 시작하는 블록) 이 끝난 **직후**에 아래를 넣는다. `AppCard` 를 쓰고 색은 토큰만 쓴다.

```dart
                const SizedBox(height: 24),
                Row(children: [
                  Text('팀전', style: AppTextStyles.label(context)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: context.accentColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('NEW', style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black)),
                  ),
                ]),
                const SizedBox(height: 8),
                AppCard(
                  variant: _isTeamMode ? AppCardVariant.tinted : AppCardVariant.surface,
                  tintColor: context.accentColor,
                  tintAlpha: 0.06,
                  borderColor: _isTeamMode
                      ? context.accentColor.withValues(alpha: 0.4)
                      : (context.isDark ? AppColors.darkDivider : AppColors.lightDivider),
                  radius: 14,
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('팀전으로 진행',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('팀원 각자의 점수를 합산해 팀 순위를 매깁니다.',
                              style: TextStyle(fontSize: 12,
                                  color: context.isDark
                                      ? AppColors.darkTextSub
                                      : AppColors.lightTextSub)),
                        ]),
                      ),
                      Switch(
                        value: _isTeamMode,
                        onChanged: (v) => setState(() => _isTeamMode = v),
                      ),
                    ]),
                    if (_isTeamMode) ...[
                      const SizedBox(height: 12),
                      Divider(height: 1, color: context.isDark
                          ? AppColors.darkDivider : AppColors.lightDivider),
                      const SizedBox(height: 12),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(LucideIcons.info, size: 15, color: context.accentColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '점수 규칙은 위에서 고른 그대로입니다. 팀 전용 설정은 없습니다.\n'
                            '팀은 개설 후 리그 관리 화면에서 만들고 배정합니다.',
                            style: TextStyle(fontSize: 12, height: 1.6,
                                color: context.isDark
                                    ? AppColors.darkTextSub
                                    : AppColors.lightTextSub),
                          ),
                        ),
                      ]),
                    ],
                  ]),
                ),
```

필요한 import 가 빠져 있으면 추가한다 (`app_card.dart`, `lucide_icons`, `app_colors.dart`, `app_text_styles.dart`). 이 파일에 이미 들어 있는 것은 중복 추가하지 않는다.

- [ ] **Step 5: 정적 분석 + 빌드 확인**

```bash
flutter analyze lib/features/league/ lib/core/theme/
```

Expected: `error` 0건.

- [ ] **Step 6: 실기기/시뮬레이터로 눈으로 확인한다**

```bash
flutter run
```

확인 항목:
- 리그 개설 화면에 `팀전` 섹션이 보이고, 토글을 켜면 안내 문구가 나타난다
- 토글을 켠 채 리그를 만들고, 수정 화면을 다시 열면 토글이 켜진 상태로 복원된다
- 토글을 끈 리그는 기존과 동일하다

- [ ] **Step 7: 커밋**

```bash
git add lib/core/theme/app_colors.dart lib/features/league/presentation/screens/league_create_screen.dart
git commit -m "$(cat <<'EOF'
feat(league): 리그 개설/수정 화면에 팀전 토글 추가

추가되는 설정은 토글 하나뿐. 점수 규칙(경기 방식·집계 조과 수)은
기존 그대로이고 팀 전용 집계 설정은 없다.

AppColors.teamColors: 팀 색상 팔레트 6종. 키 문자열이 DB 에 저장된다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: 팀 관리 화면 (호스트)

관리 화면의 `TabController` 는 길이가 2로 고정되어 있다. 탭을 늘리면 모집중/진행중/종료 각 분기를 모두 건드려야 하므로, **별도 화면으로 분리하고 관리 화면에는 진입 버튼 하나만** 추가한다. (설계의 "리그 관리 화면 안의 팀 관리 섹션"을 최소 변경으로 구현하는 형태)

**Files:**
- Create: `lib/features/league/presentation/screens/league_team_manage_screen.dart`
- Modify: `lib/core/router/app_router.dart` (라우트 추가)
- Modify: `lib/features/league/presentation/screens/league_manage_screen.dart` (진입 버튼)

**Interfaces:**
- Consumes: Task 2 의 `leagueTeamsProvider`, `createLeagueTeam`, `updateLeagueTeam`, `deleteLeagueTeam`, `assignParticipantTeam`, `shuffleLeagueTeams`; 기존 `leagueRankingProvider` (참가자 명단), `leagueDetailProvider`; Task 4 의 `AppColors.teamColors`
- Produces: 라우트 `/league/teams/:leagueId`, `AppRoutes.leagueTeams = '/league/teams'`

- [ ] **Step 1: 팀 관리 화면을 만든다**

`lib/features/league/presentation/screens/league_team_manage_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_ext.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/league_repository.dart';
import '../../data/league_team_model.dart';

/// 호스트 전용 팀 관리 화면.
///
/// 팀 생성/이름·색 변경/삭제, 참가자별 팀 배정, 자동 셔플.
/// 참가자 명단은 leagueRankingProvider 를 그대로 재사용한다
/// (승인된 참가자 전원이 0점 행으로도 들어 있다).
class LeagueTeamManageScreen extends ConsumerWidget {
  const LeagueTeamManageScreen({super.key, required this.leagueId});

  final String leagueId;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(leagueTeamsProvider(leagueId));
    ref.invalidate(leagueRankingProvider(leagueId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final teamsAsync = ref.watch(leagueTeamsProvider(leagueId));
    final rankingAsync = ref.watch(leagueRankingProvider(leagueId));

    return Scaffold(
      appBar: AppBar(title: const Text('팀 관리')),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('팀 정보를 불러오지 못했습니다: $e')),
        data: (teams) => rankingAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('참가자를 불러오지 못했습니다: $e')),
          data: (participants) {
            final byUserId = {for (final p in participants) p.userId: p};
            final assigned = <String, LeagueTeam>{};
            for (final t in teams) {
              for (final uid in t.memberUserIds) {
                assigned[uid] = t;
              }
            }
            final unassigned =
                participants.where((p) => !assigned.containsKey(p.userId)).toList();

            return RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  Row(children: [
                    Expanded(
                      child: Text('참가자 ${participants.length}명 · ${teams.length}팀',
                          style: TextStyle(fontSize: 13, color: sub)),
                    ),
                    AppButton(
                      label: '자동 셔플',
                      icon: LucideIcons.shuffle,
                      variant: AppButtonVariant.outline,
                      size: AppButtonSize.small,
                      onPressed: teams.isEmpty
                          ? null
                          : () => _shuffle(context, ref),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  if (unassigned.isNotEmpty) ...[
                    AppCard(
                      variant: AppCardVariant.tinted,
                      tintColor: AppColors.warning,
                      tintAlpha: 0.08,
                      borderColor: AppColors.warning.withValues(alpha: 0.35),
                      radius: 12,
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(LucideIcons.alertCircle,
                              size: 16, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Text('미배정 ${unassigned.length}명',
                              style: const TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w700, color: AppColors.warning)),
                        ]),
                        const SizedBox(height: 10),
                        for (final p in unassigned)
                          _MemberRow(
                            username: p.username,
                            avatarUrl: p.avatarUrl,
                            trailingLabel: '팀 선택',
                            trailingColor: AppColors.warning,
                            isDark: isDark,
                            onTap: teams.isEmpty
                                ? null
                                : () => _pickTeam(context, ref, teams, p.userId, null),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  for (final t in teams) ...[
                    _TeamCard(
                      team: t,
                      members: [
                        for (final uid in t.memberUserIds)
                          if (byUserId[uid] != null) byUserId[uid]!,
                      ],
                      isDark: isDark,
                      onRename: () => _editTeam(context, ref, t),
                      onDelete: () => _deleteTeam(context, ref, t),
                      onTapMember: (uid) => _pickTeam(context, ref, teams, uid, t.id),
                    ),
                    const SizedBox(height: 12),
                  ],

                  AppButton(
                    label: '팀 추가',
                    icon: LucideIcons.plus,
                    variant: AppButtonVariant.outline,
                    onPressed: () => _createTeam(context, ref, teams.length),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _shuffle(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: '자동 셔플',
      content: '승인된 참가자를 팀에 균등하게 다시 배정합니다.\n\n현재 배정은 모두 덮어씌워집니다.',
      confirmText: '셔플',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(leagueRepositoryProvider).shuffleLeagueTeams(leagueId);
      await _refresh(ref);
      if (context.mounted) AppSnackBar.success(context, '팀을 다시 배정했습니다.');
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, _message(e));
    }
  }

  Future<void> _createTeam(BuildContext context, WidgetRef ref, int count) async {
    final name = await _promptName(context, title: '팀 추가', initial: '');
    if (name == null || !context.mounted) return;
    try {
      await ref.read(leagueRepositoryProvider).createLeagueTeam(
        leagueId: leagueId,
        name: name,
        color: AppColors.teamColorKeyAt(count),
        sortOrder: count,
      );
      await _refresh(ref);
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, _message(e));
    }
  }

  Future<void> _editTeam(BuildContext context, WidgetRef ref, LeagueTeam t) async {
    final name = await _promptName(context, title: '팀 이름 변경', initial: t.name);
    if (name == null || !context.mounted) return;
    try {
      await ref.read(leagueRepositoryProvider)
          .updateLeagueTeam(teamId: t.id, name: name);
      await _refresh(ref);
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, _message(e));
    }
  }

  Future<void> _deleteTeam(BuildContext context, WidgetRef ref, LeagueTeam t) async {
    final ok = await showConfirmDialog(
      context,
      title: '팀 삭제',
      content: '${t.name} 을 삭제합니다.\n\n'
          '팀원들은 미배정으로 돌아가고, 등록된 조과는 그대로 유지됩니다.',
      confirmText: '삭제',
      confirmColor: AppColors.error,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(leagueRepositoryProvider).deleteLeagueTeam(t.id);
      await _refresh(ref);
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, _message(e));
    }
  }

  Future<void> _pickTeam(
    BuildContext context,
    WidgetRef ref,
    List<LeagueTeam> teams,
    String userId,
    String? currentTeamId,
  ) async {
    final picked = await showModalBottomSheet<_TeamPick>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('팀 선택',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          for (final t in teams)
            ListTile(
              leading: Container(
                width: 14, height: 14,
                decoration: BoxDecoration(
                  color: AppColors.teamColor(t.color), shape: BoxShape.circle),
              ),
              title: Text(t.name),
              trailing: t.id == currentTeamId
                  ? const Icon(LucideIcons.check, size: 18)
                  : null,
              onTap: () => Navigator.pop(ctx, _TeamPick(t.id)),
            ),
          if (currentTeamId != null)
            ListTile(
              leading: const Icon(LucideIcons.userMinus, size: 18),
              title: const Text('미배정으로'),
              onTap: () => Navigator.pop(ctx, const _TeamPick(null)),
            ),
        ]),
      ),
    );
    if (picked == null || !context.mounted) return;
    try {
      await ref.read(leagueRepositoryProvider).assignParticipantTeam(
        leagueId: leagueId, userId: userId, teamId: picked.teamId);
      await _refresh(ref);
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, _message(e));
    }
  }

  Future<String?> _promptName(BuildContext context,
      {required String title, required String initial}) async {
    final ctrl = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: AppTextField(controller: ctrl, hintText: '팀 이름', maxLength: 20),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isEmpty) return;
              Navigator.pop(ctx, v);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  String _message(Object e) {
    final s = e.toString();
    if (s.contains('NOT_LEAGUE_HOST')) return '호스트만 팀을 관리할 수 있습니다.';
    if (s.contains('NO_TEAMS')) return '먼저 팀을 만들어주세요.';
    if (s.contains('league_teams_league_id_name_key')) return '이미 같은 이름의 팀이 있습니다.';
    return '처리에 실패했습니다: $e';
  }
}

class _TeamPick {
  const _TeamPick(this.teamId);
  final String? teamId;
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
    required this.members,
    required this.isDark,
    required this.onRename,
    required this.onDelete,
    required this.onTapMember,
  });

  final LeagueTeam team;
  final List<LeagueRankEntry> members;
  final bool isDark;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final void Function(String userId) onTapMember;

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    return AppCard(
      variant: AppCardVariant.surface,
      radius: 14,
      padding: EdgeInsets.zero,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: AppColors.teamColor(team.color), shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(children: [
                Text(team.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Text('${members.length}명', style: TextStyle(fontSize: 12, color: sub)),
              ]),
            ),
            IconButton(
              onPressed: onRename,
              icon: const Icon(LucideIcons.pencil, size: 17),
              tooltip: '${team.name} 이름 변경',
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(LucideIcons.trash2, size: 17, color: AppColors.error),
              tooltip: '${team.name} 삭제',
            ),
          ]),
        ),
        if (members.isNotEmpty)
          Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
        for (final m in members)
          _MemberRow(
            username: m.username,
            avatarUrl: m.avatarUrl,
            trailingLabel: team.name,
            trailingColor: sub,
            isDark: isDark,
            onTap: () => onTapMember(m.userId),
          ),
      ]),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.username,
    required this.avatarUrl,
    required this.trailingLabel,
    required this.trailingColor,
    required this.isDark,
    this.onTap,
  });

  final String username;
  final String? avatarUrl;
  final String trailingLabel;
  final Color trailingColor;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          UserAvatar(username: username, avatarUrl: avatarUrl, radius: 14, isDark: isDark),
          const SizedBox(width: 10),
          Expanded(child: Text(username, style: const TextStyle(fontSize: 14))),
          Text(trailingLabel,
              style: TextStyle(fontSize: 12, color: trailingColor,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Icon(LucideIcons.chevronDown, size: 16, color: trailingColor),
        ]),
      ),
    );
  }
}
```

> 공통 위젯의 실제 생성자 파라미터명(`AppButton` 의 `label`/`variant`/`size`, `AppTextField` 의 `hintText`, `AppCard` 의 `variant`/`tintColor`, `showConfirmDialog` 의 인자, `AppSnackBar` 메서드명)이 위 코드와 다르면 **위젯 쪽이 정답이다.** `lib/core/widgets/` 의 해당 파일을 읽어 맞춘다. 새 공통 위젯을 만들지는 말 것.

- [ ] **Step 2: 라우트를 추가한다**

`lib/core/router/app_router.dart` 의 `AppRoutes` 에:

```dart
  static const String leagueTeams = '/league/teams';
```

그리고 `/league/participant/:leagueId/:userId` 라우트 정의 **바로 앞**에 (go_router 는 정의 순서가 매칭에 영향을 주므로 기존 league 라우트 그룹 안에 둔다):

```dart
      GoRoute(
        path: '/league/teams/:leagueId',
        builder: (context, state) => LeagueTeamManageScreen(
          leagueId: state.pathParameters['leagueId']!,
        ),
      ),
```

파일 상단에 import 를 추가한다:

```dart
import '../../features/league/presentation/screens/league_team_manage_screen.dart';
```

(기존 import 들이 쓰는 상대경로 깊이에 맞춘다.)

- [ ] **Step 3: 관리 화면에 진입 버튼을 추가한다**

`league_manage_screen.dart` 의 `_StatusCard` 호출 **직후**, 탭 바 위쪽 영역에 아래를 넣는다. 팀전 리그에서만 보인다:

```dart
                  if (league.isTeamMode)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: AppButton(
                        label: '팀 관리',
                        icon: LucideIcons.users,
                        variant: AppButtonVariant.outline,
                        onPressed: () => context.push('/league/teams/${widget.leagueId}'),
                      ),
                    ),
```

- [ ] **Step 4: 정적 분석**

```bash
flutter analyze lib/features/league/ lib/core/router/
```

Expected: `error` 0건.

- [ ] **Step 5: 실기기로 확인한다**

```bash
flutter run
```

확인 항목:
- 팀전 리그의 관리 화면에만 `팀 관리` 버튼이 보인다 (일반 리그에는 안 보인다)
- 팀 추가 → 이름 입력 → 목록에 색 점과 함께 나타난다
- 같은 이름으로 또 추가하면 "이미 같은 이름의 팀이 있습니다."
- 미배정 참가자의 `팀 선택` → 팀 고르면 해당 팀 카드로 이동한다
- 팀원 줄을 눌러 다른 팀/미배정으로 옮길 수 있다
- `자동 셔플` → 참가자가 팀에 고르게 나뉜다 (팀이 0개면 버튼이 비활성)
- 팀 삭제 → 멤버가 미배정으로 돌아가고 참가자 수는 그대로다

- [ ] **Step 6: 커밋**

```bash
git add lib/features/league/presentation/screens/league_team_manage_screen.dart \
        lib/core/router/app_router.dart \
        lib/features/league/presentation/screens/league_manage_screen.dart
git commit -m "$(cat <<'EOF'
feat(league): 호스트용 팀 관리 화면 추가

팀 생성/이름변경/삭제, 참가자별 팀 배정, 자동 셔플.
참가자 명단은 leagueRankingProvider 를 재사용한다.

관리 화면의 TabController 길이가 2로 고정되어 있어 탭을 늘리지 않고
별도 화면 + 진입 버튼으로 구현했다. 버튼은 팀전 리그에만 보인다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: 순위 화면 — 팀 탭

**Files:**
- Create: `lib/features/league/presentation/widgets/league_team_ranking_tab.dart`
- Modify: `lib/features/league/presentation/screens/league_detail_screen.dart` (탭 추가)

**Interfaces:**
- Consumes: Task 3 의 `buildTeamRanking`, `LeagueTeamRank`; Task 2 의 `leagueTeamsProvider`; 기존 `leagueRankingProvider`, `LeagueParticipantArgs`
- Produces: `LeagueTeamRankingTab({required League league, required bool isDark, required Color accent})`

- [ ] **Step 1: 팀 탭 위젯을 만든다**

`lib/features/league/presentation/widgets/league_team_ranking_tab.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/league_model.dart';
import '../../data/league_repository.dart';
import '../../data/team_ranking.dart';
import '../screens/league_participant_detail_screen.dart';

/// 팀 순위 탭.
///
/// 집계용 RPC 를 새로 만들지 않는다. 개인 탭이 이미 쓰는
/// leagueRankingProvider 결과를 leagueTeamsProvider 의 팀 명단과 합쳐
/// buildTeamRanking 이 묶는다.
class LeagueTeamRankingTab extends ConsumerWidget {
  const LeagueTeamRankingTab({
    super.key,
    required this.league,
    required this.isDark,
    required this.accent,
  });

  final League league;
  final bool isDark;
  final Color accent;

  /// 팀 카드를 기본으로 펼쳐 둘지. 팀이 많으면 1위만 펼친다.
  static const int _expandAllThreshold = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final teamsAsync = ref.watch(leagueTeamsProvider(league.id));
    final rankingAsync = ref.watch(leagueRankingProvider(league.id));

    if (teamsAsync.isLoading || rankingAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (teamsAsync.hasError) {
      return Center(child: Text('팀 정보를 불러오지 못했습니다: ${teamsAsync.error}'));
    }
    if (rankingAsync.hasError) {
      return Center(child: Text('순위를 불러오지 못했습니다: ${rankingAsync.error}'));
    }

    final teams = teamsAsync.requireValue;
    final ranking = rankingAsync.requireValue;

    if (teams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(LucideIcons.users, size: 48, color: sub),
            const SizedBox(height: 12),
            Text('아직 팀이 없습니다',
                style: TextStyle(fontSize: 14, color: sub)),
            const SizedBox(height: 6),
            Text('호스트가 리그 관리 > 팀 관리에서 팀을 만들면\n팀 순위가 표시됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: sub, height: 1.5)),
          ]),
        ),
      );
    }

    final rows = buildTeamRanking(
      ranking: ranking,
      teams: teams,
      rule: league.rule,
    );
    final expandAll = teams.length < _expandAllThreshold;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(leagueTeamsProvider(league.id));
        ref.invalidate(leagueRankingProvider(league.id));
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: rows.length,
        itemBuilder: (_, i) {
          final row = rows[i];
          final teamRank = row.isUnassigned ? 0 : i + 1;
          return _TeamRankCard(
            rank: teamRank,
            row: row,
            leagueId: league.id,
            rule: league.rule,
            catchLimit: league.catchLimit,
            isDark: isDark,
            accent: accent,
            initiallyExpanded: row.isUnassigned || expandAll || i == 0,
          );
        },
      ),
    );
  }
}

class _TeamRankCard extends StatefulWidget {
  const _TeamRankCard({
    required this.rank,
    required this.row,
    required this.leagueId,
    required this.rule,
    required this.catchLimit,
    required this.isDark,
    required this.accent,
    required this.initiallyExpanded,
  });

  final int rank; // 0 = 미배정
  final LeagueTeamRank row;
  final String leagueId;
  final String rule;
  final int catchLimit;
  final bool isDark;
  final Color accent;
  final bool initiallyExpanded;

  @override
  State<_TeamRankCard> createState() => _TeamRankCardState();
}

class _TeamRankCardState extends State<_TeamRankCard> {
  late bool _expanded = widget.initiallyExpanded;

  String get _mainValue {
    if (widget.rule == '마릿수') return '${widget.row.totalCount}마리';
    if (widget.rule == '무게') {
      return widget.row.totalMeasure > 0
          ? '${widget.row.totalMeasure.toStringAsFixed(0)}g'
          : '-';
    }
    return widget.row.totalMeasure > 0
        ? '${widget.row.totalMeasure.toStringAsFixed(1)}cm'
        : '-';
  }

  String _memberValue(LeagueRankEntry e) {
    if (widget.rule == '마릿수') return '${e.totalCount}마리';
    if (widget.rule == '무게') {
      return e.totalLength > 0 ? '${e.totalLength.toStringAsFixed(0)}g' : '0g';
    }
    if (widget.catchLimit == 1) {
      return e.bestLength != null
          ? '${e.bestLength!.toStringAsFixed(1)}cm'
          : '0.0cm';
    }
    return '${e.totalLength.toStringAsFixed(1)}cm';
  }

  Color get _rankColor {
    if (widget.rank == 1) return AppColors.gold;
    if (widget.rank == 2) return AppColors.silver;
    if (widget.rank == 3) return AppColors.bronze;
    return widget.isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final divider =
        widget.isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final row = widget.row;
    final isUnassigned = row.isUnassigned;
    final teamColor =
        isUnassigned ? sub : AppColors.teamColor(row.team!.color);

    return AppCard(
      variant: widget.rank == 1 ? AppCardVariant.tinted : AppCardVariant.surface,
      tintColor: AppColors.gold,
      tintAlpha: 0.06,
      borderColor: widget.rank == 1
          ? AppColors.gold.withValues(alpha: 0.3)
          : divider,
      radius: 14,
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              if (!isUnassigned) ...[
                SizedBox(
                  width: 24,
                  child: Text('${widget.rank}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w900, color: _rankColor)),
                ),
                const SizedBox(width: 6),
              ],
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: teamColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isUnassigned ? '미배정' : row.team!.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    isUnassigned
                        ? '${row.memberCount}명 · 팀 점수에 반영되지 않음'
                        : '${row.memberCount}명 · ${row.totalCount}마리',
                    style: TextStyle(fontSize: 12, color: sub),
                  ),
                ]),
              ),
              if (!isUnassigned)
                Text(_mainValue,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900,
                        color: widget.rank == 1 ? AppColors.gold : widget.accent)),
              const SizedBox(width: 4),
              Icon(_expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 18, color: sub),
            ]),
          ),
        ),
        if (_expanded && row.members.isNotEmpty) ...[
          Divider(height: 1, color: divider),
          for (final m in row.members)
            InkWell(
              onTap: () => context.push(
                '/league/participant/${widget.leagueId}/${m.userId}',
                extra: LeagueParticipantArgs(
                  entry: m,
                  rule: widget.rule,
                  catchLimit: widget.catchLimit,
                  rank: 0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  UserAvatar(username: m.username, avatarUrl: m.avatarUrl,
                      radius: 14, isDark: widget.isDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(m.username,
                        style: TextStyle(fontSize: 14,
                            fontWeight: m.totalCount > 0
                                ? FontWeight.w600 : FontWeight.w400,
                            color: m.totalCount > 0
                                ? (widget.isDark ? AppColors.darkText : AppColors.lightText)
                                : sub)),
                  ),
                  Text('${m.totalCount}마리',
                      style: TextStyle(fontSize: 12, color: sub)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 78,
                    child: Text(_memberValue(m),
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                            color: m.totalCount > 0
                                ? (widget.isDark ? AppColors.darkText : AppColors.lightText)
                                : sub)),
                  ),
                  const SizedBox(width: 2),
                  Icon(LucideIcons.chevronRight, size: 16, color: sub),
                ]),
              ),
            ),
        ],
      ]),
    );
  }
}
```

- [ ] **Step 2: 상세 화면에 팀 탭을 끼운다**

`league_detail_screen.dart` 에서:

1. import 추가:
```dart
import '../widgets/league_team_ranking_tab.dart';
```

2. `_tabLength` (line 80-81) 에 팀 탭을 더한다. 기존 식은 그대로 두고 앞에 더하기만 한다:

```dart
  int get _tabLength =>
      (widget.league.isTeamMode ? 1 : 0) +
      (_isHost && widget.league.status == 'in_progress' ? 3 : 2);
```

3. `didUpdateWidget` (line 170 부근) 은 지금 `status` 변경만 보고 `TabController` 를 다시 만든다. 호스트가 팀전 토글을 바꿨을 때도 다시 만들어야 길이가 어긋나지 않는다:

```dart
    if (old.league.status != widget.league.status ||
        old.league.isTeamMode != widget.league.isTeamMode) {
      _tab?.dispose();
      _tab = _hasTabs ? TabController(length: _tabLength, vsync: this) : null;
    }
```

4. `TabBar` 의 `tabs` (line 400 부근) 에서 순위 탭 **앞**에 팀 탭을 넣는다. 팀 탭이 첫 번째라 기본 선택된다. 조건은 `_tabLength` 와 같은 `widget.league.isTeamMode` 를 쓴다 (watched `league` 를 쓰면 컨트롤러 길이와 어긋날 수 있다):
```dart
                  tabs: [
                    if (widget.league.isTeamMode) const Tab(text: '팀 순위'),
                    Tab(text: league.status == 'completed' ? '최종 순위' : '실시간 순위'),
                    // ... 기존 나머지 그대로
```

5. `TabBarView` 의 children (line 414 부근) 에서 같은 위치에:
```dart
                        children: [
                          if (widget.league.isTeamMode)
                            LeagueTeamRankingTab(
                                league: league, isDark: isDark, accent: accent),
                          LeagueRankingTab(/* 기존 인자 그대로 */),
                          // ... 기존 나머지 그대로
```

`tabs` 와 `children` 의 **개수와 순서가 정확히 일치**해야 하고 둘 다 `_tabLength` 와 같아야 한다. 어긋나면 런타임에 바로 예외가 난다. 이 파일에는 상태별로 children 을 조립하는 분기가 3개(진행중+호스트 / 종료 / 모집중) 있으니, `_hasTabs` 가 true 인 분기(진행중·종료) **모두**에 팀 탭을 넣는다.

- [ ] **Step 3: 정적 분석**

```bash
flutter analyze lib/features/league/
```

Expected: `error` 0건.

- [ ] **Step 4: 실기기로 확인한다**

```bash
flutter run
```

확인 항목 (Review Focus 를 그대로 점검한다):
- 팀전 리그: `팀 순위` 탭이 **기본 선택**으로 열린다
- 일반 리그: 탭이 늘지 않고 지금과 동일하다
- 팀이 2~4개면 모든 카드가 **처음부터 펼쳐져** 있다
- 팀이 5개 이상이면 1위만 펼쳐져 있다
- 멤버 줄을 누르면 기존 참가자 상세 화면이 열린다 (조과까지 2탭)
- 조과 0마리 멤버는 흐리게 보이고 인원수에는 포함된다
- 미배정 참가자가 있으면 맨 아래 "미배정" 카드에 모이고, 점수 숫자가 없으며 "팀 점수에 반영되지 않음" 문구가 보인다
- 팀이 0개인 팀전 리그: 예외 없이 "아직 팀이 없습니다" 안내가 보인다
- `마릿수` 룰 리그: 팀 순위가 마릿수 많은 순이다

- [ ] **Step 5: 커밋**

```bash
git add lib/features/league/presentation/widgets/league_team_ranking_tab.dart \
        lib/features/league/presentation/screens/league_detail_screen.dart
git commit -m "$(cat <<'EOF'
feat(league): 순위 화면에 팀 순위 탭 추가

팀전 리그에만 '팀 순위' 탭이 생기고 기본 선택된다.
집계 RPC 없이 leagueRankingProvider + leagueTeamsProvider 를
buildTeamRanking 으로 묶는다.

- 팀 카드는 기본 펼침 (5팀 이상이면 1위만) → 조과까지 2탭 유지
- 멤버 줄 탭 → 기존 참가자 상세 화면 재사용
- 미배정 참가자는 맨 아래 별도 그룹, 팀 점수 미반영
- 팀 0개면 안내 문구

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: 개인 탭에 팀 배지

**Files:**
- Modify: `lib/features/league/presentation/widgets/league_ranking_tab.dart`

**Interfaces:**
- Consumes: Task 2 의 `leagueTeamsProvider`, Task 4 의 `AppColors.teamColor`
- Produces: 없음 (기존 위젯 보강)

- [ ] **Step 1: 팀 이름 조회 맵을 만들어 카드에 넘긴다**

`league_ranking_tab.dart` 의 `LeagueRankingTab.build` 에서, 팀전 리그일 때만 팀 정보를 함께 watch 한다. 팀전이 아니면 **추가 쿼리가 발생하지 않아야** 한다:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 팀전 리그에서만 팀 배지를 붙인다. 일반 리그는 추가 조회가 없다.
    final teamByUserId = <String, LeagueTeam>{};
    if (league.isTeamMode) {
      final teams = ref.watch(leagueTeamsProvider(league.id)).valueOrNull ?? const [];
      for (final t in teams) {
        for (final uid in t.memberUserIds) {
          teamByUserId[uid] = t;
        }
      }
    }

    return ref.watch(leagueRankingProvider(league.id)).when(
      // ...
```

`ListView.builder` 의 `itemBuilder` 에서 카드에 넘긴다:

```dart
            itemBuilder: (_, i) => LeagueRankCard(
              rank: i + 1,
              entry: entries[i],
              leagueId: league.id,
              rule: league.rule,
              catchLimit: league.catchLimit,
              isDark: isDark,
              accent: accent,
              team: teamByUserId[entries[i].userId],
              showTeamBadge: league.isTeamMode,
            ),
```

import 를 추가한다:

```dart
import '../../data/league_team_model.dart';
```

- [ ] **Step 2: `LeagueRankCard` 에 배지를 그린다**

생성자에 두 필드를 추가한다 (둘 다 옵셔널이라 기존 호출부는 그대로 동작한다):

```dart
    this.team,
    this.showTeamBadge = false,
  });

  final LeagueTeam? team;
  final bool showTeamBadge;
```

`build` 안의 `Wrap(spacing: 8, children: [...])` 에서 **첫 번째 자식 앞**에 배지를 넣는다. 색만으로 구분되지 않도록 팀명을 항상 함께 쓴다:

```dart
              Wrap(spacing: 8, children: [
                if (showTeamBadge)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: team != null
                            ? AppColors.teamColor(team!.color)
                            : sub,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(team?.name ?? '팀 미배정',
                        style: TextStyle(fontSize: 11, color: sub)),
                  ]),
                LeagueSubStat(icon: LucideIcons.fish, value: '${entry.totalCount}마리', sub: sub),
                // ... 기존 나머지
              ]),
```

`league_manage_screen.dart` 등에서 `LeagueRankCard` 를 직접 쓰는 곳이 있으면 **인자를 추가하지 않아도 그대로 컴파일**되어야 한다. 확인:

```bash
grep -rn "LeagueRankCard(" lib/
```

- [ ] **Step 3: 정적 분석 + 테스트**

```bash
flutter analyze lib/features/league/ && flutter test
```

Expected: `error` 0건, 모든 테스트 통과.

- [ ] **Step 4: 실기기로 확인한다**

```bash
flutter run
```

확인 항목:
- 팀전 리그의 개인 탭: 닉네임 아래에 색 점 + 팀명이 보인다
- 미배정 참가자는 "팀 미배정" 으로 보인다
- 일반 리그의 개인 탭: 배지가 없고 지금과 완전히 동일하다 (팀 쿼리도 발생하지 않는다)

- [ ] **Step 5: 커밋**

```bash
git add lib/features/league/presentation/widgets/league_ranking_tab.dart
git commit -m "$(cat <<'EOF'
feat(league): 개인 순위에 팀 배지 추가

팀전 리그에서만 닉네임 아래에 색 점 + 팀명을 표시한다.
일반 리그는 추가 조회 없이 기존과 동일하게 동작한다.

색상만으로 구분되지 않도록 팀명을 항상 함께 표시한다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## 전체 완료 확인

- [ ] `flutter analyze lib/` → `error` 0건
- [ ] `flutter test` → 전부 통과
- [ ] 일반 리그(`is_team_mode = false`)를 열어 탭 구성·순위·조과 등록이 **기존과 동일**함을 확인
- [ ] 팀전 리그 한 개를 끝까지 운영해 본다: 개설(토글 ON) → 팀 2개 생성 → 셔플 → 조과 등록 → 팀 순위/개인 순위 확인 → 팀 삭제 후 조과가 남아 있는지 확인
- [ ] push 는 사용자가 요청할 때만
