-- 리그 테이블 컬럼 추가 마이그레이션
-- Supabase Dashboard > SQL Editor 에서 실행

ALTER TABLE leagues
  ADD COLUMN IF NOT EXISTS fish_types  TEXT    DEFAULT '배스',
  ADD COLUMN IF NOT EXISTS rule        TEXT    DEFAULT '최대어',
  ADD COLUMN IF NOT EXISTS prize_info  TEXT,
  ADD COLUMN IF NOT EXISTS is_public   BOOLEAN DEFAULT true;
