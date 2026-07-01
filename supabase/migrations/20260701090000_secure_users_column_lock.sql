-- [CRITICAL] 본인 계정 권한 상승(self privilege escalation) 차단
--
-- 문제: public.users의 UPDATE 정책("Users can update own profile.")에 WITH CHECK/컬럼 제한이
--       없어, 일반 사용자가 자기 프로필을 수정하면서 role='admin' / is_verifier=true 로 바꿀 수 있었음.
--       한 번 admin/verifier가 되면 게시물 review_status 승인·거절, 조과 검증 확정 등 모든 권한 통제를 우회.
--
-- 해결: BEFORE UPDATE 트리거로 권한/상태/평판 컬럼을 일반 사용자가 변경하지 못하게 잠금.
--
-- 주의: 트리거 함수는 SECURITY DEFINER라 함수 내부에서 current_user/session_user가 소유자(postgres)로
--       잡히므로, 호출 주체 구분에는 auth.role()(JWT 기반)을 사용한다.
--       - auth.role()이 'authenticated'/'anon'이 아니면(=service_role 또는 JWT 없는 백필) 통과
--       - 기존 admin 은 통과(권한 관리 목적)
--       - withdraw_user()는 is_deleted/deleted_at 만 변경 → 차단 목록에 없어 정상 동작
--       - user_key(프로필 편집)/username/avatar 등 일반 수정은 차단하지 않음

CREATE OR REPLACE FUNCTION public.enforce_users_update_columns()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $function$
DECLARE
  v_is_admin boolean;
BEGIN
  -- JWT 없는 서버/백필 또는 service_role(엣지 함수)은 통과
  IF auth.role() IS DISTINCT FROM 'authenticated'
     AND auth.role() IS DISTINCT FROM 'anon' THEN
    RETURN NEW;
  END IF;

  -- 기존 관리자는 통과(권한 관리 목적)
  SELECT (role = 'admin') INTO v_is_admin FROM users WHERE id = auth.uid();
  IF COALESCE(v_is_admin, false) THEN
    RETURN NEW;
  END IF;

  -- 일반 사용자: 권한/상태/평판 컬럼 변경 차단
  IF NEW.role               IS DISTINCT FROM OLD.role               THEN RAISE EXCEPTION 'role 변경 불가'; END IF;
  IF NEW.is_verifier        IS DISTINCT FROM OLD.is_verifier        THEN RAISE EXCEPTION 'is_verifier 변경 불가'; END IF;
  IF NEW.status             IS DISTINCT FROM OLD.status             THEN RAISE EXCEPTION 'status 변경 불가'; END IF;
  IF NEW.manner_temperature IS DISTINCT FROM OLD.manner_temperature THEN RAISE EXCEPTION 'manner_temperature 변경 불가'; END IF;
  IF NEW.is_lunker_club     IS DISTINCT FROM OLD.is_lunker_club     THEN RAISE EXCEPTION 'is_lunker_club 변경 불가'; END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS users_enforce_update_columns ON public.users;
CREATE TRIGGER users_enforce_update_columns
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.enforce_users_update_columns();
