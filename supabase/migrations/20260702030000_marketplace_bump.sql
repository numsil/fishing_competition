-- 중고거래 "끌어올리기": 목록 정렬 기준이 될 bumped_at 컬럼
-- 등록일(created_at)은 보존하고, 끌어올릴 때 bumped_at = now() 로 갱신해 맨 위로.
ALTER TABLE public.marketplace_items
  ADD COLUMN IF NOT EXISTS bumped_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- 기존 행은 등록일 기준으로 초기화 (1회 백필)
UPDATE public.marketplace_items SET bumped_at = created_at;

-- 목록 keyset 페이지네이션용 인덱스 (bumped_at DESC, id DESC)
CREATE INDEX IF NOT EXISTS idx_marketplace_bumped_at
  ON public.marketplace_items (bumped_at DESC, id DESC)
  WHERE is_deleted = FALSE;
