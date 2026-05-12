-- ad_feeds_media_check: 빈 문자열도 미디어 없음으로 간주하도록 강화.
-- 기존: image_url IS NOT NULL 이라 빈 문자열('') 통과
-- 변경: COALESCE로 빈 문자열까지 막음

ALTER TABLE public.ad_feeds
  DROP CONSTRAINT IF EXISTS ad_feeds_media_check;

ALTER TABLE public.ad_feeds
  ADD CONSTRAINT ad_feeds_media_check CHECK (
    COALESCE(image_url, '') <> ''
    OR COALESCE(array_length(image_urls, 1), 0) > 0
    OR COALESCE(video_url, '') <> ''
  );
