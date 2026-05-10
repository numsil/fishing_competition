-- 개인정보보호법 / 위치정보법 대응을 위한 동의 기록 컬럼
-- birth_date: 만 14세 미만 가입 차단 + 본인확인 보조
-- *_agreed_at: 동의 시점 기록 (감사 추적). NULL = 미동의

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS birth_date date,
  ADD COLUMN IF NOT EXISTS terms_agreed_at timestamptz,
  ADD COLUMN IF NOT EXISTS privacy_agreed_at timestamptz,
  ADD COLUMN IF NOT EXISTS marketing_agreed_at timestamptz,
  ADD COLUMN IF NOT EXISTS location_agreed_at timestamptz,
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

-- 만 14세 미만 가입 차단 (DB 레벨 가드)
-- 신규 가입자에 한해 적용. 기존 NULL은 통과
ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_min_age_check;

ALTER TABLE public.users
  ADD CONSTRAINT users_min_age_check CHECK (
    birth_date IS NULL
    OR birth_date <= (CURRENT_DATE - INTERVAL '14 years')
  );
