-- 중고거래 테이블
CREATE TABLE public.marketplace_items (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title        TEXT        NOT NULL,
  description  TEXT,
  price        INTEGER     NOT NULL DEFAULT 0,
  image_urls   TEXT[]      NOT NULL DEFAULT '{}',
  category     TEXT        NOT NULL DEFAULT '기타',  -- 낚시대, 릴, 루어, 소품, 기타
  status       TEXT        NOT NULL DEFAULT 'selling', -- selling, reserved, sold
  location     TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted   BOOLEAN     NOT NULL DEFAULT FALSE
);

-- RLS
ALTER TABLE public.marketplace_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "marketplace_select" ON public.marketplace_items
  FOR SELECT USING (is_deleted = FALSE);

CREATE POLICY "marketplace_insert" ON public.marketplace_items
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "marketplace_update" ON public.marketplace_items
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "marketplace_delete" ON public.marketplace_items
  FOR DELETE USING (auth.uid() = user_id);

-- 인덱스
CREATE INDEX idx_marketplace_created_at
  ON public.marketplace_items (created_at DESC)
  WHERE is_deleted = FALSE;

CREATE INDEX idx_marketplace_user_id
  ON public.marketplace_items (user_id)
  WHERE is_deleted = FALSE;

CREATE INDEX idx_marketplace_status
  ON public.marketplace_items (status)
  WHERE is_deleted = FALSE;
