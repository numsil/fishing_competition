-- 유튜브 링크 게시물 지원.
-- youtube_url 이 있으면 image_url 은 YouTube 썸네일(hqdefault.jpg)을 가리키고,
-- 본문 표시 시 인앱 플레이어로 임베드 재생한다.
-- 사진/동영상 게시물과 상호 배타 (XOR) — 검증은 앱 단에서 처리.

ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS youtube_url text;

COMMENT ON COLUMN public.posts.youtube_url IS '유튜브 임베드 게시물 URL (있으면 image_url 은 YT 썸네일)';
