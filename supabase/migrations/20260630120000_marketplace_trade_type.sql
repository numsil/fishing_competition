-- 중고거래: 거래 유형(팝니다/삽니다) 컬럼 추가
-- sell = 팝니다(판매), buy = 삽니다(구매원함). 기존 행은 전부 'sell'.
ALTER TABLE public.marketplace_items
  ADD COLUMN IF NOT EXISTS trade_type TEXT NOT NULL DEFAULT 'sell';

-- 유형별 필터 인덱스 (삭제 안 된 행만)
CREATE INDEX IF NOT EXISTS idx_marketplace_trade_type
  ON public.marketplace_items (trade_type)
  WHERE is_deleted = FALSE;
