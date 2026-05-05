-- verifier가 인증 처리 시 posts.review_status를 변경할 수 있도록 허용
-- 문제: submitVote()에서 posts UPDATE 시 RLS에 막혀 오류 발생
--       posts UPDATE 정책이 본인/리그호스트/admin만 허용, verifier 누락
DROP POLICY IF EXISTS "verifier can update review_status" ON posts;

CREATE POLICY "verifier can update review_status" ON posts
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid() AND u.is_verifier = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid() AND u.is_verifier = true
    )
  );
