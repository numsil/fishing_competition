-- 개인 기록용 플래그 컬럼 추가
-- 개인 기록 페이지에서만 보이고, 홈 피드/프로필 피드에는 노출되지 않는 게시물 구분용
-- "내 피드에 공유" 시 is_personal_record = false 인 복사본이 INSERT 됨

ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS is_personal_record BOOLEAN DEFAULT false NOT NULL;

-- 개인 기록 조회 가속용 인덱스
CREATE INDEX IF NOT EXISTS idx_posts_personal_record
  ON posts (user_id, is_personal_record)
  WHERE league_id IS NULL;
