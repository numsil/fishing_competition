-- 리그 삭제 시 소속 posts도 함께 삭제되도록 외래키 변경
-- ON DELETE SET NULL → ON DELETE CASCADE

ALTER TABLE posts
  DROP CONSTRAINT IF EXISTS posts_league_id_fkey;

ALTER TABLE posts
  ADD CONSTRAINT posts_league_id_fkey
    FOREIGN KEY (league_id) REFERENCES leagues(id) ON DELETE CASCADE;
