-- 슬로프 기능 접근 제한 (베타 → 추후 유료화)
--
-- 일반 유저에게는 기능의 존재 자체를 노출하지 않는다.
--   1) 앱: 피드 상단 아이콘 비노출 + 라우트 가드
--   2) DB: 허용된 유저만 slopes 조회 (이 파일)
--
-- 기존 'Slopes are viewable by everyone.' 정책이 USING (true) 라서
-- 비로그인 anon 키만으로도 전체 슬로프를 조회할 수 있었다. 유료화 시에는
-- 결제하지 않은 사용자가 API 로 그대로 받아갈 수 있으므로 지금 닫는다.
--
-- 플래그는 만료일 하나로 베타와 유료 구독을 모두 표현한다.
--   NULL/과거 → 차단 (기본), 2099-12-31 → 베타(무기한), 결제 만료일 → 유료

-- 1. 접근 플래그
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS slope_access_until timestamptz;

COMMENT ON COLUMN public.users.slope_access_until IS
  '슬로프 기능 접근 만료 시각. NULL/과거면 차단, 미래면 허용. 베타는 2099-12-31, 유료는 구독 만료일.';

CREATE INDEX IF NOT EXISTS users_slope_access_until_idx
  ON public.users (slope_access_until)
  WHERE slope_access_until IS NOT NULL;

-- 2. 접근 판정 헬퍼 (RLS 정책에서 재사용)
CREATE OR REPLACE FUNCTION public.has_slope_access(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = p_user_id
      AND COALESCE(u.is_deleted, false) = false
      AND (u.role = 'admin' OR u.slope_access_until > now())
  );
$$;

-- anon 에도 EXECUTE 를 준다. 권한이 없으면 RLS 평가 중 42501 에러가 나서
-- "권한 거부" 라는 사실과 함수 이름이 노출된다. 실행을 허용하면 auth.uid() 가
-- NULL 이라 false 가 되어 조용히 빈 결과가 된다.
REVOKE ALL ON FUNCTION public.has_slope_access(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.has_slope_access(uuid) TO authenticated, anon;

-- 3. slopes 조회 정책 교체 (전체 공개 → 허용 유저 전용)
--    anon 은 auth.uid() 가 NULL 이라 자동 차단된다.
DROP POLICY IF EXISTS "Slopes are viewable by everyone." ON public.slopes;
DROP POLICY IF EXISTS slopes_select_allowed ON public.slopes;

CREATE POLICY slopes_select_allowed ON public.slopes
  FOR SELECT
  USING (public.has_slope_access(auth.uid()));

-- 4. 제보는 허용 유저만 (조회는 기존 '본인 제보만' 정책 유지)
DROP POLICY IF EXISTS "Users can insert their own slope reports." ON public.slope_reports;
DROP POLICY IF EXISTS slope_reports_insert_allowed ON public.slope_reports;

CREATE POLICY slope_reports_insert_allowed ON public.slope_reports
  FOR INSERT
  WITH CHECK (auth.uid() = reporter_id AND public.has_slope_access(auth.uid()));

-- 5. 계정 상태 RPC 에 슬로프 접근 여부 포함
--    (앱 시작 시 이미 호출·캐시되는 RPC 라 추가 쿼리가 발생하지 않는다)
--    반환 타입이 바뀌므로 DROP 후 재생성한다. 라이브 호출이 끊기지 않도록
--    한 트랜잭션으로 묶고, 기존 권한(authenticated/service_role)을 그대로 복원한다.
BEGIN;

DROP FUNCTION IF EXISTS public.get_my_account_status();

CREATE FUNCTION public.get_my_account_status()
RETURNS TABLE(
  status text,
  is_deleted boolean,
  role text,
  is_verifier boolean,
  location_agreed_at timestamp with time zone,
  email text,
  can_use_slopes boolean
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT
    u.status,
    u.is_deleted,
    u.role,
    u.is_verifier,
    u.location_agreed_at,
    u.email,
    COALESCE(u.role = 'admin' OR u.slope_access_until > now(), false) AS can_use_slopes
  FROM public.users u
  WHERE u.id = auth.uid();
$$;

REVOKE ALL ON FUNCTION public.get_my_account_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_account_status() TO authenticated, service_role;

COMMIT;
