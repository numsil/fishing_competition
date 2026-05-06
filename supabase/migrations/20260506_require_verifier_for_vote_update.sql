-- ============================================================
-- vote_update RLS 강화 — 현재 is_verifier=true인 유저만 투표 가능
--
-- 문제: 기존 정책은 voter_id = auth.uid()만 검증 → 권한 박탈 후에도
--       기존에 배정된 vote 행을 처리 가능
--
-- 해결: WITH CHECK에 is_verifier=true 조건 추가
-- ============================================================

DROP POLICY IF EXISTS "vote_update" ON verification_votes;

CREATE POLICY "vote_update" ON verification_votes FOR UPDATE
  USING (voter_id = auth.uid())
  WITH CHECK (
    voter_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid() AND u.is_verifier = true
    )
  );
