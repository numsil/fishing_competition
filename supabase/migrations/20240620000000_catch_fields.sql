-- posts 테이블 컬럼 추가: weight(무게), catch_count(마릿수)

ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS weight      NUMERIC,
  ADD COLUMN IF NOT EXISTS catch_count INTEGER DEFAULT 1;
