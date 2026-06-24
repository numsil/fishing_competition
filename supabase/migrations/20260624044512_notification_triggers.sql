CREATE EXTENSION IF NOT EXISTS pg_net;

-- 공통: 알림 row 삽입 + Edge Function 호출(푸시). 차단 관계면 스킵.
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
        SELECT 1 FROM public.user_blocks
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

-- 1) DM: messages INSERT → 상대에게 알림
CREATE OR REPLACE FUNCTION public.on_message_insert() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_recipient uuid;
BEGIN
    SELECT CASE WHEN user1_id = NEW.sender_id THEN user2_id ELSE user1_id END
      INTO v_recipient FROM public.conversations WHERE id = NEW.conversation_id;
    IF v_recipient IS NOT NULL THEN
        PERFORM public.create_notification(
            v_recipient, 'dm', NEW.sender_id, NEW.conversation_id, left(NEW.content, 100));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_message_notify
    AFTER INSERT ON public.messages
    FOR EACH ROW EXECUTE FUNCTION public.on_message_insert();

-- 2) 댓글: post_comments INSERT → 글 주인에게 알림
CREATE OR REPLACE FUNCTION public.on_comment_insert() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_owner uuid;
BEGIN
    SELECT user_id INTO v_owner FROM public.posts WHERE id = NEW.post_id;
    IF v_owner IS NOT NULL THEN
        PERFORM public.create_notification(
            v_owner, 'comment', NEW.user_id, NEW.post_id, left(NEW.content, 100));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_comment_notify
    AFTER INSERT ON public.post_comments
    FOR EACH ROW EXECUTE FUNCTION public.on_comment_insert();

-- 3) 팔로우: follows INSERT → followee에게 알림
CREATE OR REPLACE FUNCTION public.on_follow_insert() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    PERFORM public.create_notification(
        NEW.followee_id, 'follow', NEW.follower_id, NULL, '회원님을 팔로우하기 시작했습니다');
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_follow_notify
    AFTER INSERT ON public.follows
    FOR EACH ROW EXECUTE FUNCTION public.on_follow_insert();
