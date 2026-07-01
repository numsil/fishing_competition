-- [HIGH] cleanup_users() 외부 실행 차단
--
-- cleanup_users()는 미인증 7일/탈퇴 30일 계정을 하드 삭제(FK 연쇄)하는 SECURITY DEFINER 함수인데
-- anon/authenticated에게 EXECUTE가 열려 있어, 누구나 select cleanup_users()로 삭제 작업을 강제
-- 트리거할 수 있었음(런칭 유입 중 남용/조기삭제 벡터). create_notification과 동일한 잠금 누락분.
-- 크론(cron.job #1)이 소유자 권한으로 호출하므로 REVOKE해도 정기 정리는 정상 동작.

REVOKE EXECUTE ON FUNCTION public.cleanup_users() FROM anon, authenticated, PUBLIC;
