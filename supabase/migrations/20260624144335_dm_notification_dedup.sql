-- DM 알림 중복 방지: 수신자가 해당 대화에 안읽은 메시지가 이미 있으면
-- (= 이전 알림을 아직 확인 안 함) 새 메시지에 대해 푸시/알림을 또 보내지 않는다.
-- 대화방을 열어 읽으면(on_dm_read) 안읽음이 0으로 리셋 → 다음 메시지는 다시 알림.
-- 트리거는 메시지 INSERT 시점에 실행되고, on_dm_sent(unread 증가)는 그 후 호출되므로
-- 여기서 보는 unread 값은 "이 메시지 직전" 상태다.
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
            v_recipient, 'dm', NEW.sender_id, NEW.conversation_id, left(NEW.content, 100));
    END IF;
    RETURN NEW;
END;
$$;
