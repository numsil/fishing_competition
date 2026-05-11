-- 약관 버전 추적.
-- 기존: *_agreed_at (시점만 저장) → 약관 개정 시 누가 신/구버전 동의했는지 추적 불가.
-- 추가: *_version 컬럼으로 동의한 약관 버전 문자열 보관 (예: '1.0').
-- 향후 강제 재동의 흐름 도입 시 클라 상수 vs DB 값 비교로 사용.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS terms_version text,
  ADD COLUMN IF NOT EXISTS privacy_version text,
  ADD COLUMN IF NOT EXISTS marketing_version text;

-- handle_new_user 트리거: raw_user_meta_data 에서 버전 읽어 저장.
-- 기존 로직 그대로 두고 버전 컬럼만 추가 (메타데이터에 키 없으면 NULL).
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
  v_terms_version text;
  v_privacy_version text;
  v_marketing_version text;
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
  v_terms_version := NEW.raw_user_meta_data->>'terms_version';
  v_privacy_version := NEW.raw_user_meta_data->>'privacy_version';
  v_marketing_version := NEW.raw_user_meta_data->>'marketing_version';

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
    marketing_agreed_at,
    terms_version,
    privacy_version,
    marketing_version
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
    CASE WHEN v_marketing_agreed THEN NOW() ELSE NULL END,
    v_terms_version,
    v_privacy_version,
    CASE WHEN v_marketing_agreed THEN v_marketing_version ELSE NULL END
  );

  RETURN NEW;
END;
$$;
