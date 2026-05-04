-- posts 테이블에 score 컬럼 추가
ALTER TABLE posts ADD COLUMN IF NOT EXISTS score integer NOT NULL DEFAULT 0;

-- 기존 데이터 score 일괄 계산 업데이트
-- 공식: round(length^2.5 / 800) × tier_multiplier  (30cm 이하 = 0)
UPDATE posts
SET score = CASE
  WHEN length IS NULL OR length <= 30 THEN 0
  WHEN length >= 60 THEN round(pow(length, 2.5) / 800 * 10)
  WHEN length >= 55 THEN round(pow(length, 2.5) / 800 * 7)
  WHEN length >= 50 THEN round(pow(length, 2.5) / 800 * 5)
  WHEN length >= 45 THEN round(pow(length, 2.5) / 800 * 3)
  WHEN length >= 40 THEN round(pow(length, 2.5) / 800 * 2)
  ELSE                   round(pow(length, 2.5) / 800 * 1.5)
END
WHERE is_deleted = false;

-- 인덱스 추가 (리그 랭킹 집계 성능)
CREATE INDEX IF NOT EXISTS idx_posts_league_score
  ON posts (league_id, score DESC)
  WHERE is_deleted = false;
