-- realtime DELETE 이벤트에 모든 컬럼이 실리도록 REPLICA IDENTITY FULL 설정.
-- 클라이언트에서 user_id=eq.<myId> 서버 필터를 쓰려면 DELETE에도 user_id가 필요함.
-- (기본값은 PK만 실려서 추방/탈퇴 이벤트를 미스함)

ALTER TABLE public.league_participants REPLICA IDENTITY FULL;
