-- verif_select 무한 재귀 수정
-- 원인: verif_select → verification_votes 참조
--       vote_insert  → catch_verifications 참조 (서로 맞물려 무한 재귀)
-- 수정: verif_select에서 verification_votes 참조 제거 → is_verifier 조건으로 대체

DROP POLICY IF EXISTS "verif_select" ON catch_verifications;

CREATE POLICY "verif_select" ON catch_verifications FOR SELECT
  USING (
    submitter_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid()
        AND (u.is_verifier = true OR u.role = 'admin')
    )
  );
