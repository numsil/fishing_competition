-- 긴급 수정: posts ↔ users 임베드 모호성 제거 (PGRST201)
--
-- 20261005090000 에서 추가한 measure_edited_by 의 외래키가 posts↔users 관계를
-- 둘로 만들어, PostgREST 의 users(...) 임베드가 전부 실패했다.
--   Could not embed because more than one relationship was found for 'posts' and 'users'
-- 피드·프로필·리그·개인기록 등 users 를 조인하는 모든 조회가 라이브에서 깨짐
-- (DB 변경이라 구버전 앱도 즉시 영향).
--
-- 해결: FK 를 제거하고 컬럼은 유지한다. measure_edited_by 는 "누가 고쳤는지"를
-- 남기는 감사 필드일 뿐이고, 값은 host_edit_catch_measure RPC 가 auth.uid() 로만
-- 채우므로 참조 무결성이 없어도 잘못된 값이 들어가지 않는다.
-- (FK 를 유지하면서 고치려면 모든 쿼리를 users!posts_user_id_fkey 로 바꿔야 하는데,
--  그건 앱 재배포가 필요해 이미 설치된 유저를 구제하지 못한다.)

ALTER TABLE public.posts DROP CONSTRAINT IF EXISTS posts_measure_edited_by_fkey;

COMMENT ON COLUMN public.posts.measure_edited_by IS
  '수치를 수정한 호스트/어드민의 users.id. PostgREST 임베드 모호성(PGRST201)을 피하려고 FK는 걸지 않는다.';
