-- 성별 + 마지막 접속 시각

-- 성별: 가입 시 주민번호 앞 7자리에서 파싱하여 'M' 또는 'F' 저장
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS gender text,
  ADD COLUMN IF NOT EXISTS last_seen_at timestamptz;

ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_gender_check;
ALTER TABLE public.users
  ADD CONSTRAINT users_gender_check
  CHECK (gender IS NULL OR gender = ANY (ARRAY['M'::text, 'F'::text]));

-- last_seen_at 은 매 포그라운드마다 UPDATE 되므로 인덱스 X (HOT update 보존).
-- 향후 활성 유저 쿼리가 느려질 때 BRIN 또는 부분 인덱스 검토.
