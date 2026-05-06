-- ============================================================
-- catch_verifications SELECT RLS 강화 — verifier가 본인에게 배정된 건만 조회 가능
--
-- 문제: 현재 정책은 is_verifier=true인 모든 유저에게 모든 catch_verifications SELECT 허용
--   → 다른 사람이 심사 중인 인증의 image, location, 측정값 등 노출
--
-- 해결: SECURITY DEFINER 헬퍼 함수로 무한 재귀 회피하면서
--       verifier는 본인에게 배정된(verification_votes에 있는) 건만 조회 허용
--
-- 영향: getAllPendingVerifications() (admin) 정상 작동, verifier는 own only
-- ============================================================

-- 1. SECURITY DEFINER 헬퍼: RLS 우회하여 vote 배정 여부 확인
CREATE OR REPLACE FUNCTION user_is_assigned_voter(p_verification_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM verification_votes
    WHERE verification_id = p_verification_id
      AND voter_id = p_user_id
  );
$$;

-- 2. verif_select 정책 교체
DROP POLICY IF EXISTS "verif_select" ON catch_verifications;

CREATE POLICY "verif_select" ON catch_verifications FOR SELECT
  USING (
    -- 본인이 제출한 인증 요청
    submitter_id = auth.uid()
    -- 또는 admin
    OR EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
    -- 또는 본인에게 vote가 배정된 verifier (헬퍼 함수로 재귀 회피)
    OR user_is_assigned_voter(id, auth.uid())
  );
