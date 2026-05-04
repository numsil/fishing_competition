-- 운영자(role='admin')는 모든 인증 요청/투표 조회 가능

DROP POLICY IF EXISTS "verif_select" ON catch_verifications;
CREATE POLICY "verif_select" ON catch_verifications FOR SELECT
  USING (
    submitter_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM verification_votes v
      WHERE v.verification_id = id AND v.voter_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "vote_select" ON verification_votes;
CREATE POLICY "vote_select" ON verification_votes FOR SELECT
  USING (
    voter_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
  );
