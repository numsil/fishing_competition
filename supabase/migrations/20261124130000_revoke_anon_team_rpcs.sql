-- 팀 관련 RPC 네 개에서 `anon`(비로그인) 의 EXECUTE 권한을 회수한다.
--
-- 네 함수 모두 첫 줄이 `auth.uid() IS NULL -> AUTH_REQUIRED` 라서 지금도
-- 비로그인 호출은 아무 일도 못 한다. 즉 구멍을 막는 게 아니라 방어선을
-- 하나 더 깐다 — 나중에 그 검사를 지우거나 리팩터링해도 DB 권한이 막는다.
--
-- 왜 기존 마이그레이션의 `REVOKE ALL ... FROM public` 으로 안 됐나:
-- Supabase 는 CREATE FUNCTION 직후 default privileges 로 `anon`/`authenticated`
-- 에게 EXECUTE 를 다시 부여한다. `public`(모두) 에서 빼도 `anon` 에게 개별로
-- 다시 붙는다. 그래서 롤 이름을 직접 적어 회수해야 한다.
--
-- 앱 동작은 바뀌지 않는다. 앱은 항상 로그인 세션으로 호출하므로
-- 롤이 `authenticated` 이고, 그 권한은 그대로 둔다.

REVOKE EXECUTE ON FUNCTION public.create_my_league_team(uuid, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.set_my_league_team(uuid, uuid)          FROM anon;
REVOKE EXECUTE ON FUNCTION public.assign_league_teams(uuid, jsonb)        FROM anon;
REVOKE EXECUTE ON FUNCTION public.shuffle_league_teams(uuid)              FROM anon;
