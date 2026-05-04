-- posts 테이블에 개인 기록 플래그 추가
-- is_personal_record=true인 게시물은 홈 피드/프로필 피드에 노출되지 않음

ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS is_personal_record BOOLEAN DEFAULT false NOT NULL;

CREATE INDEX IF NOT EXISTS idx_posts_personal_record
  ON posts (user_id, is_personal_record)
  WHERE league_id IS NULL;
