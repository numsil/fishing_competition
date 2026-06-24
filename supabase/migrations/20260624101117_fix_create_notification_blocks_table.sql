-- 핫픽스: create_notification 가 존재하지 않는 public.user_blocks 를 참조해
-- 모든 DM/댓글/팔로우 INSERT 가 실패하던 문제 수정. 실제 차단 테이블명은 public.blocks.
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
