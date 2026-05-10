-- 좀비 계정 자동 정리 cron.
-- 1) 미인증 7일 경과 가입자 → 완전 삭제
-- 2) 탈퇴 30일 경과 회원 → 완전 삭제 (개인정보보호법 "이용 목적 달성 후 즉시 파기" 대응)
--
-- 매일 새벽 3시 KST (= 18:00 UTC) 실행.

-- pg_cron 확장 활성화 (Supabase Free·Pro 모두 지원)
CREATE EXTENSION IF NOT EXISTS pg_cron;

CREATE OR REPLACE FUNCTION public.cleanup_users()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  -- ── 1) 미인증 7일 경과 좀비 계정 ──────────────────────
  -- public.users 먼저 (FK 보호)
  DELETE FROM public.users
  WHERE id IN (
    SELECT id FROM auth.users
    WHERE email_confirmed_at IS NULL
      AND created_at < NOW() - INTERVAL '7 days'
  );

  DELETE FROM auth.users
  WHERE email_confirmed_at IS NULL
    AND created_at < NOW() - INTERVAL '7 days';

  -- ── 2) 탈퇴 30일 경과 회원 영구 삭제 ────────────────────
  -- public.users 와 auth.users 함께 삭제
  WITH expired AS (
    DELETE FROM public.users
    WHERE is_deleted = true
      AND deleted_at IS NOT NULL
      AND deleted_at < NOW() - INTERVAL '30 days'
    RETURNING id
  )
  DELETE FROM auth.users WHERE id IN (SELECT id FROM expired);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.cleanup_users() FROM public;

-- 기존 동일 작업 있으면 제거 후 재등록
DO $$
BEGIN
  PERFORM cron.unschedule('cleanup-users-daily');
EXCEPTION WHEN OTHERS THEN
  NULL; -- 없으면 무시
END $$;

SELECT cron.schedule(
  'cleanup-users-daily',
  '0 18 * * *',  -- 매일 18:00 UTC = 03:00 KST
  $$SELECT public.cleanup_users();$$
);
