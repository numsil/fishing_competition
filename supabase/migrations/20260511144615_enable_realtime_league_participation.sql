-- 리그 상세 화면 실시간 갱신.
-- 호스트가 참가 승인/거절/초대 취소했을 때 신청자·invitee 화면이 즉시 반영되도록.
-- league_participants: SELECT USING(true) → 누구나 변경 수신 가능 (이미 공개 정보)
-- league_invites: SELECT는 호스트/invitee 본인만 → 본인 행만 수신됨

ALTER PUBLICATION supabase_realtime ADD TABLE public.league_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE public.league_invites;
