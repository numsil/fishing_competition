-- ============================================================
-- Part 2/2: Revoke users PII column access from anon/authenticated
-- ------------------------------------------------------------
-- ⚠️ 적용 전 필수 선행 조건:
--   1. Part 1 (20260517172935_fix_profile_summary_email_and_add_self_rpcs.sql)
--      이 prod 에 이미 적용되어 있어야 함.
--   2. 다음 클라이언트 코드가 신버전으로 배포되어 사용자 대부분이
--      신버전을 받은 상태여야 함:
--        - lib/main.dart                                  (banned 확인)
--        - lib/features/auth/data/auth_repository.dart    (banned 확인)
--        - lib/core/services/location_consent_service.dart (location_agreed_at 조회)
--        - lib/features/verification/data/verification_repository.dart (role 조회)
--        - lib/features/league/data/league_invite_repository.dart      (user_key 검색)
--        - lib/features/profile/data/profile_repository.dart           (email 필드 제거)
--      → 위 5개 파일에서 더 이상 users 테이블의 status/is_deleted/
--        role/location_agreed_at/email 컬럼을 직접 SELECT 하지 않도록
--        get_my_account_status() / find_invitable_user() RPC 로
--        교체되어 있어야 함.
--
-- 적용 후 효과:
--   - anon / authenticated 가 /rest/v1/users 로 email, birth_date,
--     gender, status, is_deleted, role, last_seen_at, deleted_at,
--     terms/privacy/marketing_*, user_key (← 그대로 둠) 등 비공개
--     컬럼을 더 이상 SELECT 할 수 없음.
--   - 공개 가능한 컬럼만 SELECT 허용:
--     id, username, user_key, avatar_url, manner_temperature,
--     is_lunker_club, is_verifier, created_at.
--   - 기존의 users!inner(...) join 들은 모두 위 공개 컬럼만 사용
--     중이므로 영향 없음.
-- ============================================================

-- 기존 광범위 SELECT 권한 회수
REVOKE SELECT ON public.users FROM anon, authenticated;

-- 공개 가능한 컬럼만 다시 부여
GRANT SELECT (
  id,
  username,
  user_key,
  avatar_url,
  manner_temperature,
  is_lunker_club,
  is_verifier,
  created_at
) ON public.users TO anon, authenticated;

-- 참고: service_role 은 RLS / column 권한 우회하므로 별도 GRANT 불필요.
