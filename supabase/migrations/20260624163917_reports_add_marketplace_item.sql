-- 중고거래 매물 신고 지원: reports에 marketplace_item_id 추가.
ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS marketplace_item_id uuid
  REFERENCES public.marketplace_items(id) ON DELETE CASCADE;

-- 대상 중 최소 하나는 있어야 함 (post/comment/marketplace).
ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_target_check;
ALTER TABLE public.reports
  ADD CONSTRAINT reports_target_check
  CHECK (post_id IS NOT NULL OR comment_id IS NOT NULL OR marketplace_item_id IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_reports_marketplace_item_id
  ON public.reports(marketplace_item_id) WHERE marketplace_item_id IS NOT NULL;
