-- 리그 삭제 시 다른 참가자의 조과가 공개 피드로 유출되는 문제 수정.
--
-- [기존 동작]
--   앱의 deleteLeague 는 posts 를 먼저 지우지만, posts DELETE RLS 가
--   `auth.uid() = user_id` 이므로 호스트 자기 글만 지워지고 다른 참가자의
--   조과는 조용히 남는다(RLS 는 에러 없이 행을 걸러낸다).
--   그 뒤 leagues 가 삭제되면 posts_league_id_fkey 의 ON DELETE SET NULL 이
--   남은 조과의 league_id 를 비우고, 피드 조건
--   (league_id IS NULL AND is_personal_record = false) 에 걸려 공개 피드에 노출된다.
--
-- [변경]
--   1. FK 를 ON DELETE RESTRICT 로 바꿔 조과가 남은 리그는 DB 에서 삭제가 막힌다.
--   2. cancel_league : 기록을 보존한 채 status = 'canceled' 로 전환.
--   3. delete_league : 기록이 전혀 없는 리그만 삭제(SECURITY DEFINER 로 RLS 우회 →
--      조용한 부분 삭제가 사라진다).

BEGIN;

-- ─────────────────────────────────────────────────────────────
-- 1. posts.league_id FK : SET NULL → RESTRICT
--    같은 이름/같은 컬럼으로 교체하므로 PostgREST 관계가 새로 생기지 않는다
--    (embed ambiguity 유발 안 함).
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.posts
  DROP CONSTRAINT IF EXISTS posts_league_id_fkey;

ALTER TABLE public.posts
  ADD CONSTRAINT posts_league_id_fkey
  FOREIGN KEY (league_id) REFERENCES public.leagues(id) ON DELETE RESTRICT;

-- ─────────────────────────────────────────────────────────────
-- 2. 리그 취소 (기록 보존)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cancel_league(p_league_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_uid      uuid := auth.uid();
  v_host     uuid;
  v_status   text;
  v_is_admin boolean;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT l.host_id, l.status
  INTO v_host, v_status
  FROM public.leagues l
  WHERE l.id = p_league_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'LEAGUE_NOT_FOUND';
  END IF;

  SELECT (u.role = 'admin') INTO v_is_admin
  FROM public.users u WHERE u.id = v_uid;

  IF v_host IS DISTINCT FROM v_uid AND NOT COALESCE(v_is_admin, false) THEN
    RAISE EXCEPTION 'NOT_LEAGUE_HOST';
  END IF;

  -- 종료된 리그는 전적 데이터라 손대지 않는다.
  IF v_status = 'completed' THEN
    RAISE EXCEPTION 'LEAGUE_COMPLETED';
  END IF;

  IF v_status = 'canceled' THEN
    RETURN;
  END IF;

  UPDATE public.leagues SET status = 'canceled' WHERE id = p_league_id;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 3. 리그 삭제 (기록이 전혀 없을 때만)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.delete_league(p_league_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_uid         uuid := auth.uid();
  v_host        uuid;
  v_status      text;
  v_is_admin    boolean;
  v_live_posts  integer;
  v_others      integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT l.host_id, l.status
  INTO v_host, v_status
  FROM public.leagues l
  WHERE l.id = p_league_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'LEAGUE_NOT_FOUND';
  END IF;

  SELECT (u.role = 'admin') INTO v_is_admin
  FROM public.users u WHERE u.id = v_uid;

  IF v_host IS DISTINCT FROM v_uid AND NOT COALESCE(v_is_admin, false) THEN
    RAISE EXCEPTION 'NOT_LEAGUE_HOST';
  END IF;

  IF v_status = 'completed' THEN
    RAISE EXCEPTION 'LEAGUE_COMPLETED';
  END IF;

  -- 살아있는 조과가 하나라도 있으면 삭제 불가 → 취소를 써야 한다.
  SELECT count(*) INTO v_live_posts
  FROM public.posts p
  WHERE p.league_id = p_league_id
    AND COALESCE(p.is_deleted, false) = false;

  IF v_live_posts > 0 THEN
    RAISE EXCEPTION 'LEAGUE_HAS_CATCHES';
  END IF;

  -- 호스트 외 승인된 참가자가 있으면 삭제 불가.
  SELECT count(*) INTO v_others
  FROM public.league_participants lp
  WHERE lp.league_id = p_league_id
    AND lp.status = 'approved'
    AND lp.user_id IS DISTINCT FROM v_host;

  IF v_others > 0 THEN
    RAISE EXCEPTION 'LEAGUE_HAS_PARTICIPANTS';
  END IF;

  -- 소프트 삭제로 남아있던 잔여 행까지 정리해야 FK(RESTRICT)가 풀린다.
  DELETE FROM public.posts WHERE league_id = p_league_id;
  DELETE FROM public.leagues WHERE id = p_league_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancel_league(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_league(uuid) TO authenticated;

COMMIT;
