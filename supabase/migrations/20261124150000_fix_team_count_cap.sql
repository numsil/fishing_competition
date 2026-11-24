-- 팀 개수 상한 공식 수정.
--
-- 기존: 올림(최대 참가자 / 팀당 정원). 그건 "전원을 앉히려면 최소 몇 팀이
-- 필요한가" 이고 최대값이 아니다. 정원 12 · 참가자 12 인 리그가 상한 1팀이
-- 되어, 첫 사람이 팀을 만들면 나머지 참가자 전원이 TEAM_LIMIT_REACHED 로
-- 막혔다 (실기기에서 잡힌 버그).
--
-- 변경: 내림(최대 참가자 / 2), 최소 2. 팀당 정원은 쓰지 않는다 — 정원으로는
-- 최대 팀 수를 역산할 수 없다. 정원은 여전히 합류를 막는다(TEAM_FULL).
--
-- 클라이언트의 같은 규칙:
--   lib/features/league/data/team_create_options.dart (maxTeamCount)
-- 두 곳이 어긋나면 `팀 만들기` 버튼이 거짓말을 한다.

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

  SELECT l.is_team_mode, l.team_assign_mode, l.max_participants
  INTO v_is_team_mode, v_mode, v_max_participants
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
  --
  -- `내림(최대 참가자 / 2)`, 최소 2. 팀이 성립하려면 2명은 있어야 하므로
  -- 12명 리그에서 만들 수 있는 팀은 많아도 6개다.
  --
  -- 팀당 정원(team_capacity)은 쓰지 않는다. 정원 12 는 "12명 1팀" 도
  -- "2명 6팀" 도 유효해서 최대 팀 수를 역산할 수 없다. 예전 공식
  -- `올림(참가자 / 정원)` 은 "전원을 앉히려면 최소 몇 팀이 필요한가" 였고
  -- 최대값이 아니었다 — 정원 12·참가자 12 인 리그가 상한 1팀이 되어
  -- 첫 사람이 팀을 만들면 나머지 전원이 막혔다.
  --
  -- 규칙: lib/features/league/data/team_create_options.dart (maxTeamCount)
  v_max_teams := CASE
    WHEN v_max_participants > 0 THEN greatest(v_max_participants / 2, 2)
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
