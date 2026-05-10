-- 회원가입 트리거.
-- auth.users INSERT 시 raw_user_meta_data 에서 정보 읽어 public.users 자동 생성.
--
-- 도입 이유:
-- 1. Email Confirm ON 환경에서 클라가 직접 public.users INSERT 시 RLS 위반
--    (signUp 직후엔 session 없음 → auth.uid() = null)
-- 2. auth.users 와 public.users 가 단일 트랜잭션으로 atomic 처리됨
-- 3. 향후 OAuth(카카오·구글 등) 추가해도 동일 트리거가 처리

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_username text;
  v_birth_date date;
  v_gender text;
  v_marketing_agreed boolean;
  v_user_key text;
  v_candidate text;
  v_suffix int := 2;
BEGIN
  v_username := NEW.raw_user_meta_data->>'username';
  v_gender := NEW.raw_user_meta_data->>'gender';
  v_marketing_agreed := COALESCE(
    (NEW.raw_user_meta_data->>'marketing_agreed')::boolean,
    false
  );

  -- birth_date 안전 캐스팅 (잘못된 형식이면 NULL)
  BEGIN
    v_birth_date := (NEW.raw_user_meta_data->>'birth_date')::date;
  EXCEPTION WHEN OTHERS THEN
    v_birth_date := NULL;
  END;

  -- username 없으면 (예: 향후 OAuth) 이메일 앞부분 또는 user_<id> fallback
  IF v_username IS NULL OR LENGTH(TRIM(v_username)) = 0 THEN
    v_username := COALESCE(
      NULLIF(SPLIT_PART(NEW.email, '@', 1), ''),
      'user_' || SUBSTRING(NEW.id::text, 1, 8)
    );
  END IF;

  -- user_key 유니크 생성 (같은 닉네임 충돌 시 숫자 접미사)
  v_candidate := v_username;
  LOOP
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.users WHERE user_key = v_candidate
    );
    v_candidate := v_username || v_suffix::text;
    v_suffix := v_suffix + 1;
    IF v_suffix > 1000 THEN
      -- 안전장치: 1000번 시도 실패 시 랜덤 접미사
      v_candidate := v_username || '_' || SUBSTRING(NEW.id::text, 1, 6);
      EXIT;
    END IF;
  END LOOP;
  v_user_key := v_candidate;

  INSERT INTO public.users (
    id,
    email,
    username,
    user_key,
    birth_date,
    gender,
    terms_agreed_at,
    privacy_agreed_at,
    marketing_agreed_at
  )
  VALUES (
    NEW.id,
    NEW.email,
    v_username,
    v_user_key,
    v_birth_date,
    v_gender,
    NOW(),
    NOW(),
    CASE WHEN v_marketing_agreed THEN NOW() ELSE NULL END
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
