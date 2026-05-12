-- 앱 전역 설정 (어드민이 코드 재배포 없이 조정 가능한 값들).
-- key-value 형태. 초기 광고 간격 두 개 시드.

CREATE TABLE public.app_config (
  key text PRIMARY KEY,
  value_int int,
  value_text text,
  description text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- 누구나 SELECT 가능 (앱이 시작 시 fetch).
CREATE POLICY "app_config_select_all"
  ON public.app_config FOR SELECT
  USING (true);

-- INSERT/UPDATE/DELETE는 service_role(어드민)만 → 정책 없음.

-- 초기 시드
INSERT INTO public.app_config (key, value_int, description) VALUES
  ('ad_min_gap', 5, '피드 광고 최소 간격 (게시물 N개당 1개)'),
  ('ad_max_gap', 7, '피드 광고 최대 간격 (게시물 N개당 1개)')
ON CONFLICT (key) DO NOTHING;
