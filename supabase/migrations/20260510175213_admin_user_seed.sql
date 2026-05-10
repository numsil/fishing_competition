-- 관리자 시드 계정 생성.
-- 앱 사용자 문의 (DM) 흐름의 상대방 역할.
-- 고정 UUID 사용 → 앱·어드민 코드에서 참조 가능.
-- ON CONFLICT DO NOTHING 으로 idempotent 보장.

-- 1) auth.users 직접 시드
--    encrypted_password 는 절대 로그인 불가능한 강한 랜덤 값
--    email_confirmed_at 채워서 active 상태
--    raw_user_meta_data 채워서 handle_new_user 트리거가 정상 동작
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_user_meta_data,
  raw_app_meta_data,
  created_at,
  updated_at
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-000000000001'::uuid,
  'authenticated',
  'authenticated',
  'admin@nakstar.app',
  crypt('LOCK-' || gen_random_uuid()::text || '-' || gen_random_uuid()::text, gen_salt('bf')),
  NOW(),
  jsonb_build_object(
    'username', 'NAKSTAR 관리자',
    'birth_date', '2000-01-01',
    'gender', 'M'
  ),
  '{"provider":"email","providers":["email"]}'::jsonb,
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- 2) public.users 명시적 덮어씀
--    트리거가 만든 행을 admin role + 깔끔한 user_key 로 정정
UPDATE public.users
SET
  username = 'NAKSTAR 관리자',
  user_key = 'admin',
  role = 'admin',
  is_lunker_club = false,
  is_verifier = false,
  status = 'active',
  is_deleted = false
WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

-- 3) 관리자 계정 보호 — 탈퇴/삭제/변경 차단 트리거
CREATE OR REPLACE FUNCTION public.protect_admin_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid := '00000000-0000-0000-0000-000000000001'::uuid;
BEGIN
  IF TG_OP = 'DELETE' AND OLD.id = v_admin_id THEN
    RAISE EXCEPTION '관리자 계정은 삭제할 수 없습니다';
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.id = v_admin_id THEN
    IF (NEW.is_deleted = true AND OLD.is_deleted = false)
       OR (NEW.status = 'banned')
       OR (NEW.role <> 'admin') THEN
      RAISE EXCEPTION '관리자 계정은 탈퇴/정지/role 변경 불가';
    END IF;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS protect_admin_user_trigger ON public.users;
CREATE TRIGGER protect_admin_user_trigger
  BEFORE UPDATE OR DELETE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.protect_admin_user();
