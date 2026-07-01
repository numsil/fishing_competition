-- [HIGH] 공개 실행 가능한 SECURITY DEFINER 함수 잠금
--
-- 1) create_notification / record_daily_snapshot : 앱이 직접 호출하지 않음(트리거/크론 전용).
--    그런데 anon/authenticated 에게 EXECUTE 권한이 열려 있어, 누구나 임의 대상에게
--    가짜 푸시 알림을 보낼 수 있었음(피싱/스팸). → 외부 실행 권한 회수.
--    (트리거 내부 호출은 함수 소유자=postgres 권한으로 실행되므로 정상 동작)
--
-- 2) on_dm_sent / on_dm_read / hide_conversation : 앱(DM)이 직접 호출하므로 회수하지 않고,
--    호출자가 해당 대화의 멤버 본인인지 검증하는 가드를 추가(SECURITY DEFINER IDOR 차단) +
--    search_path 고정. anon 실행 권한은 회수(로그인 사용자만).

-- 1) 트리거/크론 전용 함수: 외부 직접 실행 차단
REVOKE EXECUTE ON FUNCTION public.create_notification(uuid, text, uuid, uuid, text) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.record_daily_snapshot() FROM anon, authenticated, PUBLIC;

-- 2) DM 함수 하드닝: 본인·멤버 검증 가드 + search_path 고정
CREATE OR REPLACE FUNCTION public.on_dm_sent(p_conv_id uuid, p_sender_id uuid, p_content text)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $function$
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_sender_id
     OR NOT EXISTS (
       SELECT 1 FROM conversations c
       WHERE c.id = p_conv_id AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
     ) THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;

  UPDATE conversations SET
    last_message       = p_content,
    last_message_at    = NOW(),
    unread_count_user1 = CASE WHEN user2_id = p_sender_id THEN unread_count_user1 + 1 ELSE unread_count_user1 END,
    unread_count_user2 = CASE WHEN user1_id = p_sender_id THEN unread_count_user2 + 1 ELSE unread_count_user2 END,
    user1_hidden_at    = CASE WHEN user2_id = p_sender_id THEN NULL ELSE user1_hidden_at END,
    user2_hidden_at    = CASE WHEN user1_id = p_sender_id THEN NULL ELSE user2_hidden_at END
  WHERE id = p_conv_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.on_dm_read(p_conv_id uuid, p_reader_id uuid)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $function$
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_reader_id
     OR NOT EXISTS (
       SELECT 1 FROM conversations c
       WHERE c.id = p_conv_id AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
     ) THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;

  UPDATE conversations SET
    unread_count_user1 = CASE WHEN user1_id = p_reader_id THEN 0 ELSE unread_count_user1 END,
    unread_count_user2 = CASE WHEN user2_id = p_reader_id THEN 0 ELSE unread_count_user2 END
  WHERE id = p_conv_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.hide_conversation(p_conv_id uuid, p_user_id uuid)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $function$
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id
     OR NOT EXISTS (
       SELECT 1 FROM conversations c
       WHERE c.id = p_conv_id AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
     ) THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;

  UPDATE conversations SET
    user1_hidden_at = CASE WHEN user1_id = p_user_id THEN NOW() ELSE user1_hidden_at END,
    user2_hidden_at = CASE WHEN user2_id = p_user_id THEN NOW() ELSE user2_hidden_at END
  WHERE id = p_conv_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.on_dm_sent(uuid, uuid, text)  FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.on_dm_read(uuid, uuid)        FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.hide_conversation(uuid, uuid) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION public.on_dm_sent(uuid, uuid, text)  TO authenticated;
GRANT  EXECUTE ON FUNCTION public.on_dm_read(uuid, uuid)        TO authenticated;
GRANT  EXECUTE ON FUNCTION public.hide_conversation(uuid, uuid) TO authenticated;
