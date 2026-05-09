-- conversations 테이블을 Realtime publication에 추가
-- (홈 DM 아이콘 빨간점이 실시간 반영되도록 conversations.UPDATE 이벤트를 broadcast)
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
