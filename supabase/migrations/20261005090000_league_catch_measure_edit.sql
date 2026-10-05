-- 리그 호스트의 조과 수치 수정
--
-- 심사 탭에는 보류/해지만 있어, 참가자가 길이를 잘못 적으면 호스트가 보류 후 재등록을
-- 요청하는 수밖에 없었다. 호스트가 직접 수치를 고칠 수 있게 하고, 최초 원본 값과
-- 수정자·시각을 남기고 작성자에게 알림을 보낸다.
-- 설계: docs/superpowers/specs/2026-10-05-league-catch-measure-edit-design.md

-- 1. 이력 컬럼 (original_*는 첫 수정 때만 기록)
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS original_length   numeric,
  ADD COLUMN IF NOT EXISTS original_weight   numeric,
  ADD COLUMN IF NOT EXISTS measure_edited_by uuid REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS measure_edited_at timestamptz;

COMMENT ON COLUMN public.posts.original_length IS
  '호스트가 길이를 수정한 경우 참가자가 올린 최초 값. 재수정 시에도 유지.';
COMMENT ON COLUMN public.posts.original_weight IS
  '호스트가 무게를 수정한 경우 참가자가 올린 최초 값. 재수정 시에도 유지.';

-- 2. notifications.type 허용 목록에 league_catch_edit 추가
--    (기존: dm | comment | follow)
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check
  CHECK (type = ANY (ARRAY['dm', 'comment', 'follow', 'league_catch_edit']));

-- 3. 푸시 제목 분기에 league_catch_edit 추가
--    (기존 함수 본문 유지 + CASE 한 줄 추가)
CREATE OR REPLACE FUNCTION public.create_notification(
  p_recipient uuid, p_type text, p_actor uuid, p_target uuid, p_body text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
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
        SELECT 1 FROM public.blocks
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
        WHEN 'league_catch_edit' THEN '조과 기록 수정'
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

-- 4. 수치 수정 RPC
--
-- score는 trg_calc_post_score(BEFORE INSERT OR UPDATE OF length)가 자동 재계산한다.
-- is_lunker는 자동이 아니므로 여기서 함께 설정한다.
-- enforce_posts_update_columns 트리거는 current_user가 함수 소유자(postgres)가 되어
-- 통과하므로 수정하지 않는다 → 일반 UPDATE 경로의 컬럼 보호는 그대로 유지.
CREATE OR REPLACE FUNCTION public.host_edit_catch_measure(
  p_post_id uuid,
  p_value   numeric
) RETURNS TABLE(length numeric, weight numeric, score integer, is_lunker boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_uid        uuid := auth.uid();
  v_author     uuid;
  v_league     uuid;
  v_host       uuid;
  v_rule       text;
  v_is_weight  boolean;
  v_old        numeric;
  v_is_admin   boolean;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT p.user_id, p.league_id
  INTO v_author, v_league
  FROM public.posts p
  WHERE p.id = p_post_id
    AND p.league_id IS NOT NULL
    AND COALESCE(p.is_deleted, false) = false
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'POST_NOT_FOUND';
  END IF;

  SELECT l.host_id, COALESCE(l.rule, '합산 길이')
  INTO v_host, v_rule
  FROM public.leagues l
  WHERE l.id = v_league;

  SELECT (u.role = 'admin') INTO v_is_admin
  FROM public.users u WHERE u.id = v_uid;

  IF v_host IS DISTINCT FROM v_uid AND NOT COALESCE(v_is_admin, false) THEN
    RAISE EXCEPTION 'NOT_LEAGUE_HOST';
  END IF;

  v_is_weight := (v_rule = '무게');

  IF p_value IS NULL
     OR p_value <= 0
     OR (v_is_weight AND p_value > 50000)
     OR (NOT v_is_weight AND p_value > 200) THEN
    RAISE EXCEPTION 'INVALID_VALUE';
  END IF;

  IF v_is_weight THEN
    SELECT p.weight INTO v_old FROM public.posts p WHERE p.id = p_post_id;
  ELSE
    SELECT p.length INTO v_old FROM public.posts p WHERE p.id = p_post_id;
  END IF;

  -- 값이 같으면 수정도 알림도 없음
  IF v_old IS NOT DISTINCT FROM p_value THEN
    RETURN QUERY
      SELECT p.length, p.weight, p.score, p.is_lunker
      FROM public.posts p WHERE p.id = p_post_id;
    RETURN;
  END IF;

  IF v_is_weight THEN
    UPDATE public.posts p
    SET weight            = p_value,
        original_weight   = COALESCE(p.original_weight, v_old),
        measure_edited_by = v_uid,
        measure_edited_at = now()
    WHERE p.id = p_post_id;
  ELSE
    UPDATE public.posts p
    SET length            = p_value,
        original_length   = COALESCE(p.original_length, v_old),
        is_lunker         = (p_value >= 50),
        measure_edited_by = v_uid,
        measure_edited_at = now()
    WHERE p.id = p_post_id;
  END IF;

  PERFORM public.create_notification(
    v_author,
    'league_catch_edit',
    v_uid,
    p_post_id,
    format(
      '리그 조과 %s가 %s → %s 로 수정되었습니다',
      CASE WHEN v_is_weight THEN '무게' ELSE '길이' END,
      CASE WHEN v_old IS NULL THEN '미입력'
           ELSE trim(to_char(v_old, 'FM999990.0')) || CASE WHEN v_is_weight THEN 'g' ELSE 'cm' END END,
      trim(to_char(p_value, 'FM999990.0')) || CASE WHEN v_is_weight THEN 'g' ELSE 'cm' END
    )
  );

  RETURN QUERY
    SELECT p.length, p.weight, p.score, p.is_lunker
    FROM public.posts p WHERE p.id = p_post_id;
END;
$$;

REVOKE ALL ON FUNCTION public.host_edit_catch_measure(uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.host_edit_catch_measure(uuid, numeric) TO authenticated;
