-- ─────────────────────────────────────────────────────────
-- 광고 피드 시스템
-- - 어드민이 등록한 광고가 일반 피드 사이에 섞여 노출
-- - 이미지(단일/캐러셀) 또는 자체 호스팅 영상
-- - 노출/클릭 트래킹, 기간 설정, 노출 한도
-- ─────────────────────────────────────────────────────────

-- 1) ad_feeds 테이블 ─────────────────────────────────────
CREATE TABLE public.ad_feeds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,                       -- 어드민 내부 식별용
  body text,                                 -- 카드 캡션
  image_url text,                            -- 단일 이미지
  image_urls text[] DEFAULT '{}',            -- 캐러셀
  video_url text,                            -- 자체 호스팅 영상
  thumbnail_url text,                        -- 영상 썸네일
  aspect_ratio numeric DEFAULT 1.0,
  link_url text NOT NULL,                    -- 클릭 시 이동할 외부 링크
  placement text NOT NULL DEFAULT 'feed',    -- 'feed' (향후 확장)
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  starts_at timestamptz,
  ends_at timestamptz,
  impression_limit int,                      -- NULL이면 무제한
  impression_count int NOT NULL DEFAULT 0,
  click_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  CONSTRAINT ad_feeds_placement_check
    CHECK (placement IN ('feed')),
  CONSTRAINT ad_feeds_media_check
    CHECK (
      image_url IS NOT NULL
      OR array_length(image_urls, 1) > 0
      OR video_url IS NOT NULL
    ),
  CONSTRAINT ad_feeds_dates_check
    CHECK (starts_at IS NULL OR ends_at IS NULL OR ends_at > starts_at),
  CONSTRAINT ad_feeds_limit_check
    CHECK (impression_limit IS NULL OR impression_limit > 0)
);

CREATE INDEX ad_feeds_active_idx
  ON public.ad_feeds (placement, sort_order, created_at DESC)
  WHERE is_active = true;

-- updated_at 자동 갱신 트리거
CREATE OR REPLACE FUNCTION public.tg_ad_feeds_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

CREATE TRIGGER ad_feeds_updated_at
  BEFORE UPDATE ON public.ad_feeds
  FOR EACH ROW EXECUTE FUNCTION public.tg_ad_feeds_updated_at();

-- 2) ad_impressions 테이블 ───────────────────────────────
CREATE TABLE public.ad_impressions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ad_id uuid NOT NULL REFERENCES public.ad_feeds(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ad_impressions_type_check
    CHECK (event_type IN ('view', 'click'))
);

CREATE INDEX ad_impressions_ad_idx
  ON public.ad_impressions (ad_id, created_at DESC);
CREATE INDEX ad_impressions_ad_type_idx
  ON public.ad_impressions (ad_id, event_type);

-- 3) RLS ────────────────────────────────────────────────
ALTER TABLE public.ad_feeds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_impressions ENABLE ROW LEVEL SECURITY;

-- ad_feeds: 일반 유저는 활성 + 기간 내 + 한도 미달 광고만 SELECT
CREATE POLICY "ad_feeds_select_active"
  ON public.ad_feeds FOR SELECT
  USING (
    is_active = true
    AND (starts_at IS NULL OR now() >= starts_at)
    AND (ends_at IS NULL OR now() < ends_at)
    AND (impression_limit IS NULL OR impression_count < impression_limit)
  );
-- INSERT/UPDATE/DELETE 정책 없음 → service_role(어드민)만 가능

-- ad_impressions: INSERT는 RPC만 (SECURITY DEFINER가 우회).
-- 클라가 직접 못 쓰게 PERMISSIVE 없음.
-- SELECT는 admin role만
CREATE POLICY "ad_impressions_select_admin"
  ON public.ad_impressions FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() AND u.role = 'admin'
  ));

-- 4) RPC: 노출/클릭 기록 + 한도 도달 시 자동 비활성화 ─────
CREATE OR REPLACE FUNCTION public.record_ad_impression(
  p_ad_id uuid,
  p_event_type text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_ad record;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다' USING ERRCODE = '28000';
  END IF;
  IF NOT public.is_active_user(v_caller) THEN
    RETURN; -- 비활성 유저는 silently 무시
  END IF;
  IF p_event_type NOT IN ('view', 'click') THEN
    RAISE EXCEPTION '잘못된 이벤트 타입' USING ERRCODE = '22023';
  END IF;

  SELECT id, impression_limit, impression_count, is_active
    INTO v_ad
    FROM public.ad_feeds
    WHERE id = p_ad_id
    FOR UPDATE;
  IF NOT FOUND THEN
    RETURN; -- 광고 없으면 silently 무시
  END IF;
  IF NOT v_ad.is_active THEN
    RETURN; -- 이미 비활성
  END IF;

  -- 이벤트 기록
  INSERT INTO public.ad_impressions (ad_id, user_id, event_type)
    VALUES (p_ad_id, v_caller, p_event_type);

  IF p_event_type = 'view' THEN
    -- 노출 카운트 증가 + 한도 도달 시 자동 비활성화
    UPDATE public.ad_feeds
       SET impression_count = impression_count + 1,
           is_active = CASE
             WHEN impression_limit IS NOT NULL
               AND impression_count + 1 >= impression_limit
             THEN false
             ELSE is_active
           END
       WHERE id = p_ad_id;
  ELSIF p_event_type = 'click' THEN
    UPDATE public.ad_feeds
       SET click_count = click_count + 1
       WHERE id = p_ad_id;
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.record_ad_impression(uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION public.record_ad_impression(uuid, text) TO authenticated;

-- 5) Storage 버킷 ──────────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('ads', 'ads', true)
ON CONFLICT (id) DO NOTHING;

-- ads 버킷 SELECT: 공개 (public read)
DROP POLICY IF EXISTS "ads bucket public read" ON storage.objects;
CREATE POLICY "ads bucket public read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'ads');

-- INSERT/UPDATE/DELETE 정책 없음 → service_role(어드민)만 가능
