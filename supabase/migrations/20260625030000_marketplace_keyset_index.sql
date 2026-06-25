-- 중고거래 목록 keyset 페이지네이션용 복합 인덱스
-- 쿼리: WHERE is_deleted = false ORDER BY created_at DESC, id DESC
-- (created_at, id) 복합 커서로 동일 created_at 경계 행 누락을 막을 때 인덱스 정합성 확보
CREATE INDEX IF NOT EXISTS marketplace_items_created_id_desc_idx
  ON public.marketplace_items (created_at DESC, id DESC)
  WHERE is_deleted = false;
