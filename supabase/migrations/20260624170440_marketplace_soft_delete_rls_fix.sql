-- 소프트 삭제 버그 수정.
-- 기존 SELECT 정책이 is_deleted=false 만 허용해서, 소유자가 is_deleted=true 로
-- UPDATE 하면 "새 행이 SELECT 정책 위반(안 보이게 됨)"으로 RLS가 update를 거부했다.
-- → 소유자는 본인 매물을 (삭제 여부와 무관하게) 볼 수 있게 해 update를 허용한다.
-- 일반 사용자에겐 여전히 is_deleted=false 만 노출되고, 앱 목록 쿼리도 .eq('is_deleted', false)
-- 로 삭제 항목을 거르므로 소유자 화면에도 삭제 항목은 나타나지 않는다.
ALTER POLICY "marketplace_select" ON public.marketplace_items
  USING (is_deleted = false OR auth.uid() = user_id);
