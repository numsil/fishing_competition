-- 조과 인증 실시간 업데이트 활성화.
-- 다른 verifier가 투표해서 status가 pending → approved/rejected로 바뀌면,
-- 이 인증에 배정된 모든 voter의 클라이언트가 즉시 알림 받아 리스트에서 제거.
-- (RLS verif_select가 적용돼서 본인이 배정된 인증의 변경만 수신)

ALTER PUBLICATION supabase_realtime ADD TABLE public.catch_verifications;
