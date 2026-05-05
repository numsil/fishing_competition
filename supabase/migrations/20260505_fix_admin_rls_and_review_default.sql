-- ============================================================
-- 1. catch_verifications UPDATE: admin 허용
--    기존 정책은 verification_votes에 배정된 유저만 허용
--    → admin이 adminResolveVerification()으로 직접 처리할 수 없었음
-- ============================================================
DROP POLICY IF EXISTS "verif_update" ON catch_verifications;

CREATE POLICY "verif_update" ON catch_verifications FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM verification_votes v
      WHERE v.verification_id = id AND v.voter_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM verification_votes v
      WHERE v.verification_id = id AND v.voter_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
  );


-- ============================================================
-- 2. posts UPDATE: admin이 review_status 직접 변경 허용
--    기존: 본인 게시물 또는 리그 호스트만 UPDATE 가능
--    → admin이 다른 유저 게시물의 review_status를 변경할 수 없었음
-- ============================================================
DROP POLICY IF EXISTS "admin can update review_status" ON posts;

CREATE POLICY "admin can update review_status" ON posts
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
  );


-- ============================================================
-- 3. review_status 컬럼 기본값 'approved' → 'pending' 변경
--    최초 컬럼 추가 시 DEFAULT 'approved'로 설정되어
--    review_status를 명시하지 않은 INSERT가 바로 approved 상태가 됨
-- ============================================================
ALTER TABLE posts ALTER COLUMN review_status SET DEFAULT 'pending';


-- ============================================================
-- 4. 기존 데이터 보정
--    catch_verifications가 없는 게시물(인증 요청 생성 전 등록)은
--    review_status가 'approved'로 잘못 저장되어 있을 수 있음
--    → 인증 요청이 없는 개인기록/리그 게시물을 pending으로 되돌림
--    (리그 호스트가 명시적으로 approved 처리한 것은 제외)
-- ============================================================
UPDATE posts
SET review_status = 'pending'
WHERE review_status = 'approved'
  AND NOT EXISTS (
    SELECT 1 FROM catch_verifications cv
    WHERE cv.post_id = posts.id AND cv.status = 'approved'
  );
