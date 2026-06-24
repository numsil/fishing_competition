-- DM 알림 본문을 실제 메시지 내용 대신 일반 문구로 변경 (잠금화면 내용 노출 방지).
-- 제목엔 보낸 사람 이름이 그대로 들어가므로 "OO / 새로운 메시지가 왔습니다" 형태가 된다.
-- (중복 방지 로직은 그대로 유지)
CREATE OR REPLACE FUNCTION public.on_message_insert() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_recipient uuid;
    v_prior_unread int;
BEGIN
    SELECT
        CASE WHEN user1_id = NEW.sender_id THEN user2_id ELSE user1_id END,
        CASE WHEN user1_id = NEW.sender_id THEN unread_count_user2 ELSE unread_count_user1 END
      INTO v_recipient, v_prior_unread
      FROM public.conversations WHERE id = NEW.conversation_id;

    -- 수신자가 아직 안 읽은 메시지가 있으면(이미 알림 받음) 중복 알림/푸시 생략
    IF v_recipient IS NOT NULL AND COALESCE(v_prior_unread, 0) = 0 THEN
        PERFORM public.create_notification(
            v_recipient, 'dm', NEW.sender_id, NEW.conversation_id, '새로운 메시지가 왔습니다');
    END IF;
    RETURN NEW;
END;
$$;
