-- [MEDIUM] DM 메시지/대화 변조 차단
--
-- 문제 1: messages UPDATE 정책에 WITH CHECK가 없어, 같은 대화방 멤버가 상대방 메시지의
--         content 를 rewrite 할 수 있었음. → is_read 외 컬럼 변경을 트리거로 차단.
--         (앱 markAsRead는 {is_read:true} 만 바꾸므로 정상 동작)
-- 문제 2: conversations "자신의 대화 업데이트" 정책으로 last_message/미읽음 수를 직접 조작 가능.
--         앱은 conversations를 직접 UPDATE하지 않고 SECURITY DEFINER RPC(on_dm_*)로만 갱신하므로,
--         직접 UPDATE 정책을 제거해 조작 경로 차단(RPC는 RLS 우회라 정상 동작).

-- 1) messages: is_read 외 컬럼 변경 잠금
CREATE OR REPLACE FUNCTION public.enforce_messages_update_columns()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $function$
BEGIN
  -- SECURITY DEFINER라 current_user는 소유자로 잡히므로 auth.role()(JWT)로 판별.
  -- JWT 없는 서버/백필 또는 service_role 은 통과.
  IF auth.role() IS DISTINCT FROM 'authenticated'
     AND auth.role() IS DISTINCT FROM 'anon' THEN
    RETURN NEW;
  END IF;

  IF NEW.content         IS DISTINCT FROM OLD.content         THEN RAISE EXCEPTION 'content 변경 불가'; END IF;
  IF NEW.sender_id       IS DISTINCT FROM OLD.sender_id       THEN RAISE EXCEPTION 'sender_id 변경 불가'; END IF;
  IF NEW.conversation_id IS DISTINCT FROM OLD.conversation_id THEN RAISE EXCEPTION 'conversation_id 변경 불가'; END IF;
  IF NEW.created_at      IS DISTINCT FROM OLD.created_at      THEN RAISE EXCEPTION 'created_at 변경 불가'; END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS messages_enforce_update_columns ON public.messages;
CREATE TRIGGER messages_enforce_update_columns
  BEFORE UPDATE ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.enforce_messages_update_columns();

-- 2) conversations: 클라이언트 직접 UPDATE 경로 제거(앱은 RPC만 사용)
DROP POLICY IF EXISTS "자신의 대화 업데이트" ON public.conversations;
