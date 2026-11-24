-- 참가자가 직접 팀을 만든다 (원하는 팀명).
--
-- RLS 는 건드리지 않는다. league_teams 의 INSERT 를 참가자에게 열면 팀 개수
-- 상한을 걸 자리가 없다 (RLS 정책은 "이 행을 넣어도 되는가"만 보고, 테이블
-- 전체 개수를 세는 조건은 동시 삽입에서 깨진다). 기존 set_my_league_team 과
-- 같은 방식으로 SECURITY DEFINER RPC 하나만 허용한다.
--
-- 상한: 올림(최대 참가자 ÷ 팀당 정원). 내림이면 자리가 모자라 어느 팀에도
-- 못 들어가는 참가자가 생긴다. 정원이 무제한(0)이면 상한 없음 — 한 팀에
-- 전원이 들어갈 수 있어서 역산할 근거가 없다.
--
-- 클라이언트의 같은 규칙: lib/features/league/data/team_create_options.dart

BEGIN;

CREATE OR REPLACE FUNCTION public.create_my_league_team(
  p_league_id uuid,
  p_name text,
  p_color text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_uid uuid;
  v_is_team_mode boolean;
  v_mode text;
  v_capacity int;
  v_max_participants int;
  v_max_teams int;
  v_team_count int;
  v_name text;
  v_team_id uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT l.is_team_mode, l.team_assign_mode, l.team_capacity, l.max_participants
  INTO v_is_team_mode, v_mode, v_capacity, v_max_participants
  FROM public.leagues l WHERE l.id = p_league_id;

  IF v_mode IS NULL THEN
    RAISE EXCEPTION 'LEAGUE_NOT_FOUND';
  END IF;

  -- 호스트 배정 리그는 호스트가 팀 구성을 통제하는 게 전제다.
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

  v_name := btrim(coalesce(p_name, ''));
  IF v_name = '' THEN
    RAISE EXCEPTION 'TEAM_NAME_BLANK';
  END IF;
  IF char_length(v_name) > 20 THEN
    RAISE EXCEPTION 'TEAM_NAME_TOO_LONG';
  END IF;

  -- 상한 판정. 세는 것과 넣는 것 사이의 경쟁은 아래 lock 으로 막는다.
  v_max_teams := CASE
    WHEN v_capacity > 0 AND v_max_participants > 0
      THEN (v_max_participants + v_capacity - 1) / v_capacity
    ELSE 0
  END;

  IF v_max_teams > 0 THEN
    -- 같은 리그의 동시 생성을 직렬화한다. 둘이 같이 세면 둘 다 통과해서
    -- 상한을 한 칸 넘긴다. 리그 행 하나에만 걸리므로 다른 리그는 막지 않는다.
    PERFORM 1 FROM public.leagues WHERE id = p_league_id FOR UPDATE;

    SELECT count(*) INTO v_team_count
    FROM public.league_teams t WHERE t.league_id = p_league_id;

    IF v_team_count >= v_max_teams THEN
      RAISE EXCEPTION 'TEAM_LIMIT_REACHED';
    END IF;
  END IF;

  -- 이름 중복은 league_teams_league_id_name_key 가 잡는다 (클라이언트가
  -- 그 제약 이름으로 문구를 고른다). 여기서 미리 세지 않는다 — 세고 넣는
  -- 사이에 끼어들면 결국 제약이 판정하므로 검사가 둘로 갈라질 뿐이다.
  INSERT INTO public.league_teams (league_id, name, color, sort_order)
  VALUES (
    p_league_id,
    v_name,
    nullif(btrim(coalesce(p_color, '')), ''),
    COALESCE(
      (SELECT max(t.sort_order) FROM public.league_teams t
       WHERE t.league_id = p_league_id),
      -1
    ) + 1
  )
  RETURNING id INTO v_team_id;

  -- 만든 사람은 바로 그 팀에 들어간다. 빈 팀이 쌓이면 팀 목록이 쓰레기가
  -- 된다. 새 팀은 0명이므로 정원 검증이 필요 없다.
  UPDATE public.league_participants
  SET team_id = v_team_id
  WHERE league_id = p_league_id AND user_id = v_uid;

  RETURN v_team_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_my_league_team(uuid, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.create_my_league_team(uuid, text, text) TO authenticated;

COMMIT;
