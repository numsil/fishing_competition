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

  -- 권한 검사가 빈 배열 조기 반환보다 먼저 와야 한다. 그렇지 않으면
  -- 비호스트가 빈 배열로 호출했을 때 성공처럼 보인다.
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
    -- 위반 = 정원 초과 AND 이 배정이 그 팀을 더 나쁘게 만들었다.
    --
    -- `>=` 가 아니라 `>` 여야 한다. 정원을 낮춰 여러 팀이 동시에 초과한
    -- 상태에서는, 한 팀에서 사람을 빼는 배정이 **손대지 않은** 다른 초과
    -- 팀(적용 전 = 적용 후)에 걸려 거부된다. 그러면 호스트가 초과 상태를
    -- 복구할 수단이 없어진다.
    SELECT 1 FROM after_counts a
    LEFT JOIN before_counts b ON b.team_id = a.team_id
    WHERE a.n > v_capacity
      AND a.n > COALESCE(b.n, 0)
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
