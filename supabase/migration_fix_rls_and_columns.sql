-- ============================================================
-- 마이그레이션: catch_limit 컬럼 추가 + RLS 정책 보완
-- Supabase Dashboard > SQL Editor 에서 실행
-- ============================================================

-- 1. leagues 테이블에 catch_limit 컬럼 추가 (리그 개설 필수)
ALTER TABLE leagues
  ADD COLUMN IF NOT EXISTS catch_limit INTEGER DEFAULT 1;

-- ============================================================
-- 2. leagues UPDATE 정책 (호스트만 수정 가능)
--    없으면 대회 시작/종료가 모두 막힘
-- ============================================================
DROP POLICY IF EXISTS "League hosts can update their leagues." ON leagues;
CREATE POLICY "League hosts can update their leagues." ON leagues
  FOR UPDATE USING (auth.uid() = host_id);

-- ============================================================
-- 3. league_participants UPDATE 정책 (호스트가 참가 승인 가능)
-- ============================================================
DROP POLICY IF EXISTS "League hosts can update participants." ON league_participants;
CREATE POLICY "League hosts can update participants." ON league_participants
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM leagues
      WHERE leagues.id = league_participants.league_id
        AND leagues.host_id = auth.uid()
    )
  );

-- ============================================================
-- 4. league_participants DELETE 정책
--    - 본인 탈퇴 가능
--    - 호스트가 참가자 추방 가능
-- ============================================================
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

-- ============================================================
-- 5. posts DELETE 정책 (본인 게시물만 삭제 가능)
-- ============================================================
DROP POLICY IF EXISTS "Users can delete own posts." ON posts;
CREATE POLICY "Users can delete own posts." ON posts
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 6. leagues DELETE 정책 (호스트만 삭제 가능)
-- ============================================================
DROP POLICY IF EXISTS "League hosts can delete their leagues." ON leagues;
CREATE POLICY "League hosts can delete their leagues." ON leagues
  FOR DELETE USING (auth.uid() = host_id);
