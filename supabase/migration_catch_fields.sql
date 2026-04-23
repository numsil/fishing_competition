-- posts 테이블에 무게, 마릿수 컬럼 추가
-- Supabase Dashboard > SQL Editor 에서 실행

ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS weight      NUMERIC,          -- 무게 (g)
  ADD COLUMN IF NOT EXISTS catch_count INTEGER DEFAULT 1; -- 마릿수
