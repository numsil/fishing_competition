-- vote_insert 정책 수정
-- 기존: submitter가 아닌 사람만 insert 가능 (잘못된 로직)
-- 수정: submitter 본인이 다른 유저들에게 vote 배정 가능
DROP POLICY IF EXISTS "vote_insert" ON verification_votes;

CREATE POLICY "vote_insert" ON verification_votes FOR INSERT
  WITH CHECK (
    voter_id != auth.uid()  -- 자기 자신에게 배정 불가
    AND EXISTS (
      SELECT 1 FROM catch_verifications cv
      WHERE cv.id = verification_id
        AND cv.status = 'pending'
        AND cv.submitter_id = auth.uid()  -- 본인이 제출한 인증 요청에만 배정 가능
    )
  );
