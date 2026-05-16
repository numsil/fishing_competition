-- 사진/동영상 혼합 미디어를 순서 보존하여 저장하기 위한 컬럼 추가
-- 기존 image_url / image_urls / video_url 컬럼은 호환성을 위해 유지한다.
-- 신규 게시물: media 컬럼 + 기존 컬럼 둘 다 채움
-- 구 게시물: media = NULL → 앱에서 기존 컬럼으로 폴백

ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS media jsonb;

COMMENT ON COLUMN public.posts.media IS
  '순서 보존 미디어 배열. 예: [{"type":"image","url":"...","aspect_ratio":1.0},{"type":"video","url":"...","thumbnail_url":"...","aspect_ratio":0.56}]. NULL이면 구버전 게시물.';
