-- 리그 알림 3종 추가: 초대 / 리그 시작 / 참가 승인
--
-- 기존 파이프라인(create_notification -> pg_net -> send-push -> FCM)을 그대로
-- 재사용한다. Edge Function 과 device_tokens 는 건드리지 않는다.

-- ─────────────────────────────────────────────────────────────
-- 1. notifications.type 허용 목록 확장
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check
  CHECK (type = ANY (ARRAY[
    'dm', 'comment', 'follow', 'league_catch_edit',
    'league_invite', 'league_start', 'league_approved'
  ]));

-- ─────────────────────────────────────────────────────────────
-- 2. create_notification: 푸시 제목 분기에 3종 추가
--
-- 본문의 나머지는 라이브 정의 그대로다 (차단 테이블은 `blocks`).
-- ELSE '알림' 폴백이 있어 제목 없이도 동작하지만, 제목이 '알림'이면
-- 알림 서랍에서 무슨 일인지 알 수 없다.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_notification(
    p_recipient uuid,
    p_type text,
    p_actor uuid,
    p_target uuid,
    p_body text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
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
        WHEN 'league_invite' THEN '리그 초대'
        WHEN 'league_start' THEN '리그 시작'
        WHEN 'league_approved' THEN '참가 승인'
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

-- ─────────────────────────────────────────────────────────────
-- 3. 리그 초대: create_league_invite 안에서 알림 발송
--
-- 라이브 정의를 그대로 옮기고 INSERT 직후에만 알림을 넣는다.
-- 이 함수에는 "이미 pending/accepted 초대가 있으면 기존 id 를 그대로
-- 반환" 하는 조기 반환 경로가 있다. 알림을 함수 맨 끝이 아니라 INSERT
-- 직후에 두는 이유가 그것이다 — 호스트가 같은 사람을 또 초대해도
-- 푸시가 두 번 가지 않는다.
--
-- 앱이 보내던 초대 DM 은 제거했다 (league_invite_repository.dart).
-- DM 을 남겨두면 초대 1건에 푸시가 2번(DM + 초대) 울리고, DM 푸시는
-- 탭하면 리그가 아니라 채팅방으로 간다.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_league_invite(
  p_league_id uuid,
  p_invitee_id uuid
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_league record;
  v_invite_id uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다' USING ERRCODE = '28000';
  END IF;
  IF NOT public.is_active_user(v_caller) THEN
    RAISE EXCEPTION '비활성 계정입니다' USING ERRCODE = '42501';
  END IF;
  IF v_caller = p_invitee_id THEN
    RAISE EXCEPTION '자기 자신은 초대할 수 없습니다' USING ERRCODE = '22023';
  END IF;
  IF NOT public.is_active_user(p_invitee_id) THEN
    RAISE EXCEPTION '초대할 수 없는 유저입니다' USING ERRCODE = '42501';
  END IF;

  -- title 을 추가로 읽는다 (알림 본문에 쓴다)
  SELECT id, host_id, is_public, status, title
    INTO v_league
    FROM public.leagues
    WHERE id = p_league_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '리그를 찾을 수 없습니다' USING ERRCODE = '02000';
  END IF;
  IF v_league.host_id <> v_caller THEN
    RAISE EXCEPTION '호스트만 초대할 수 있습니다' USING ERRCODE = '42501';
  END IF;
  IF v_league.status NOT IN ('recruiting', 'in_progress') THEN
    RAISE EXCEPTION '종료된 리그입니다' USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.league_participants
    WHERE league_id = p_league_id
      AND user_id = p_invitee_id
      AND status IN ('approved', 'pending')
  ) THEN
    RAISE EXCEPTION '이미 참여 중인 유저입니다' USING ERRCODE = '23505';
  END IF;

  SELECT id INTO v_invite_id
    FROM public.league_invites
    WHERE league_id = p_league_id
      AND invitee_id = p_invitee_id
      AND status IN ('pending', 'accepted');
  IF v_invite_id IS NOT NULL THEN
    RETURN v_invite_id;
  END IF;

  INSERT INTO public.league_invites (league_id, inviter_id, invitee_id, status)
    VALUES (p_league_id, v_caller, p_invitee_id, 'pending')
    RETURNING id INTO v_invite_id;

  PERFORM public.create_notification(
    p_invitee_id, 'league_invite', v_caller, p_league_id,
    '''' || COALESCE(v_league.title, '리그') || '''');

  RETURN v_invite_id;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 4. 리그 시작: recruiting -> in_progress 전이에만 발동
--
-- OLD.status 로 전이를 묶으므로 다른 컬럼 수정이나 completed ->
-- in_progress 되돌리기에는 울리지 않는다.
--
-- 참가자 수만큼 net.http_post 가 돈다. 기존 broadcast-push Edge
-- Function 은 전체 유저 대상이라 참가자 부분집합에는 쓸 수 없다.
-- 수백 명 규모 리그가 생기면 send-push 에 다중 수신자 지원을 추가해야
-- 한다.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.on_league_started() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE r record;
BEGIN
  IF OLD.status = 'recruiting' AND NEW.status = 'in_progress' THEN
    FOR r IN
      SELECT user_id FROM public.league_participants
      WHERE league_id = NEW.id AND status = 'approved'
    LOOP
      -- 호스트 본인은 create_notification 의 p_recipient = p_actor
      -- 가드가 걸러낸다.
      PERFORM public.create_notification(
        r.user_id, 'league_start', NEW.host_id, NEW.id,
        '''' || COALESCE(NEW.title, '리그') || '''');
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_league_started_notify ON public.leagues;
CREATE TRIGGER trg_league_started_notify
  AFTER UPDATE OF status ON public.leagues
  FOR EACH ROW EXECUTE FUNCTION public.on_league_started();

-- ─────────────────────────────────────────────────────────────
-- 5. 참가 승인: pending -> approved 전이에만 발동
--
-- actor 는 리그 호스트다. league_participants 에 승인자 컬럼이 없다.
--
-- 초대 수락 경로(respond_league_invite)는 participants 를 INSERT 하므로
-- 이 트리거를 타지 않는다 — 초대받아 들어온 사람에게 "승인됐습니다"가
-- 중복으로 가지 않는다.
--
-- 거절은 이 트리거 대상이 아니다. 앱의 거절은 status 변경이 아니라
-- DELETE 이고(removeParticipant), 같은 DELETE 가 추방에도 쓰인다.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.on_participant_approved() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_league record;
BEGIN
  IF OLD.status = 'pending' AND NEW.status = 'approved' THEN
    SELECT host_id, title INTO v_league
      FROM public.leagues WHERE id = NEW.league_id;
    IF v_league.host_id IS NOT NULL THEN
      PERFORM public.create_notification(
        NEW.user_id, 'league_approved', v_league.host_id, NEW.league_id,
        '''' || COALESCE(v_league.title, '리그') || '''');
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_participant_approved_notify ON public.league_participants;
CREATE TRIGGER trg_participant_approved_notify
  AFTER UPDATE OF status ON public.league_participants
  FOR EACH ROW EXECUTE FUNCTION public.on_participant_approved();
