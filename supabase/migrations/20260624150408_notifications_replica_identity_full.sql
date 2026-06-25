-- 알림 삭제(DELETE) Realtime 이벤트에 user_id가 실리도록 (구독 필터 매칭용).
ALTER TABLE public.notifications REPLICA IDENTITY FULL;
