-- vote_select RLS 수정: verifier가 같은 인증 건의 모든 투표를 집계할 수 있도록
-- 문제: voter_id = auth.uid() 만 허용 → submitVote()에서 내 투표 1개만 읽힘
--       → approve_count 최대 1 → 승인 2명 조건 절대 불충족
-- 수정: is_verifier=true 또는 admin이면 모든 투표 조회 허용

DROP POLICY IF EXISTS "vote_select" ON verification_votes;

CREATE POLICY "vote_select" ON verification_votes FOR SELECT
  USING (
    voter_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid()
        AND (u.is_verifier = true OR u.role = 'admin')
    )
  );
