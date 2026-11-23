-- 리그 팀전(Team Mode) 스키마
--
-- 설계: docs/superpowers/specs/2026-11-23-league-team-mode-design.md
-- 계획: docs/superpowers/plans/2026-11-23-league-team-mode.md
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
-- league_teams 정책과 shuffle RPC 가 공유한다.
-- auth.uid() 로 판별한다 (current_user 는 SECURITY DEFINER 안에서 no-op).
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

-- ── 6. team_id 변경 권한 ──────────────────────────────────────
-- 별도 트리거를 두지 않는다. league_participants 의 기존 UPDATE 정책
-- "League hosts can update participants." 가 이미 호스트만 허용하고 있어
-- (USING: leagues.host_id = auth.uid()) 참가자는 자기 행을 아예 수정할 수
-- 없다. 따라서 team_id 도 호스트만 바꿀 수 있다.
--
-- 이 정책은 참가 승인/거절 플로우도 함께 게이트하므로 건드리지 않는다.
-- 결과적으로 admin 은 앱에서 개별 배정을 못 하지만, 관리자 웹은 service
-- role 로 RLS 를 우회하고 shuffle_league_teams 는 SECURITY DEFINER 라
-- admin 도 쓸 수 있다.

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
