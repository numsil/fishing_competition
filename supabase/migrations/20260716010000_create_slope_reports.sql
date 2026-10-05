-- 슬로프 제보/오류신고 테이블
-- 유저가 앱에서 '새 슬로프 제보' 또는 '오류 신고'를 보낸다.
-- 읽기: 본인 제보만. 어드민은 service_role로 RLS 우회하여 전체 열람.

-- 1) 테이블 ─────────────────────────────────────────────
CREATE TABLE public.slope_reports (
  id          uuid DEFAULT extensions.uuid_generate_v4() NOT NULL PRIMARY KEY,
  type        text NOT NULL,                    -- 'new_slope' | 'error'
  reporter_id uuid NOT NULL REFERENCES public.users (id),
  slope_id    text REFERENCES public.slopes (id),  -- 오류신고 대상 (new_slope은 null)
  slope_name  text,                             -- 새 슬로프 제보의 제안 이름/위치
  address     text,                             -- 새 슬로프 제보의 주소/위치 설명
  content     text,                             -- 상세/오류 내용
  status      text NOT NULL DEFAULT 'pending',  -- 'pending' | 'resolved' | 'rejected'
  created_at  timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at  timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT slope_reports_type_check
    CHECK (type = ANY (ARRAY['new_slope'::text, 'error'::text])),
  CONSTRAINT slope_reports_status_check
    CHECK (status = ANY (ARRAY['pending'::text, 'resolved'::text, 'rejected'::text]))
);

-- 어드민 미처리 목록 조회용 (최신순)
CREATE INDEX slope_reports_status_created_idx
  ON public.slope_reports (status, created_at DESC);

-- updated_at 자동 갱신 트리거
CREATE OR REPLACE FUNCTION public.tg_slope_reports_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END $$;

CREATE TRIGGER slope_reports_updated_at
  BEFORE UPDATE ON public.slope_reports
  FOR EACH ROW EXECUTE FUNCTION public.tg_slope_reports_updated_at();

-- 2) RLS ────────────────────────────────────────────────
ALTER TABLE public.slope_reports ENABLE ROW LEVEL SECURITY;

-- 제출: 로그인 유저가 본인 이름으로만
CREATE POLICY "Users can insert their own slope reports."
  ON public.slope_reports FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);

-- 열람: 본인 제보만 (어드민은 service_role로 우회)
CREATE POLICY "Users can view their own slope reports."
  ON public.slope_reports FOR SELECT
  USING (auth.uid() = reporter_id);

-- 상태 변경: 어드민만
CREATE POLICY "Admins can update slope reports."
  ON public.slope_reports FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() AND u.role = 'admin'
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() AND u.role = 'admin'
  ));

-- 삭제: 어드민만
CREATE POLICY "Admins can delete slope reports."
  ON public.slope_reports FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() AND u.role = 'admin'
  ));
