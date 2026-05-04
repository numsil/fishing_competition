-- catch_limit 컬럼 추가 + RLS 정책 보완
-- (leagues UPDATE/DELETE, league_participants UPDATE/DELETE, posts DELETE)

ALTER TABLE leagues
  ADD COLUMN IF NOT EXISTS catch_limit INTEGER DEFAULT 1;

-- leagues: 호스트만 수정/삭제 가능
DROP POLICY IF EXISTS "League hosts can update their leagues." ON leagues;
CREATE POLICY "League hosts can update their leagues." ON leagues
  FOR UPDATE USING (auth.uid() = host_id);

DROP POLICY IF EXISTS "League hosts can delete their leagues." ON leagues;
CREATE POLICY "League hosts can delete their leagues." ON leagues
  FOR DELETE USING (auth.uid() = host_id);

-- league_participants: 호스트가 참가 승인/추방, 본인 탈퇴
DROP POLICY IF EXISTS "League hosts can update participants." ON league_participants;
CREATE POLICY "League hosts can update participants." ON league_participants
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM leagues
      WHERE leagues.id = league_participants.league_id
        AND leagues.host_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can leave or hosts can remove participants." ON league_participants;
CREATE POLICY "Users can leave or hosts can remove participants." ON league_participants
  FOR DELETE USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM leagues
      WHERE leagues.id = league_participants.league_id
        AND leagues.host_id = auth.uid()
    )
  );

-- posts: 본인 게시물만 삭제 가능
DROP POLICY IF EXISTS "Users can delete own posts." ON posts;
CREATE POLICY "Users can delete own posts." ON posts
  FOR DELETE USING (auth.uid() = user_id);
