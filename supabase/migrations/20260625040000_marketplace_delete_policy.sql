-- 중고거래 매물 하드 삭제 지원: 본인 행만 DELETE 가능
-- (소프트 삭제 → 하드 삭제로 전환. 어드민은 service role로 RLS 우회)
DROP POLICY IF EXISTS "marketplace_delete" ON public.marketplace_items;
CREATE POLICY "marketplace_delete" ON public.marketplace_items
  FOR DELETE
  USING (auth.uid() = user_id);
