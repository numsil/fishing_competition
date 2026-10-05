-- 조과 사진 중복 업로드 차단
--
-- 같은 배스 사진으로 인증을 두 번 받아 점수를 중복 획득하는 부정을 막는다.
-- 파일명은 앱이 posts/{userId}_{timestamp}.jpg 로 매번 새로 생성하므로 판별에 쓸 수 없어,
-- 압축 전 원본 사진 바이트의 SHA-256(hex 64자)을 지문으로 저장한다.
-- 설계: docs/superpowers/specs/2026-09-28-duplicate-photo-guard-design.md

ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS image_hash text;

COMMENT ON COLUMN public.posts.image_hash IS
  '압축 전 원본 사진 바이트의 SHA-256 (hex). 조과 중복 등록 차단용. 앱에서 계산.';

-- 개인기록끼리 중복 차단 (전역)
CREATE UNIQUE INDEX IF NOT EXISTS posts_personal_image_hash_unique
  ON public.posts (image_hash)
  WHERE image_hash IS NOT NULL
    AND is_personal_record = true
    AND COALESCE(is_deleted, false) = false;

-- 같은 리그 안에서 중복 차단
CREATE UNIQUE INDEX IF NOT EXISTS posts_league_image_hash_unique
  ON public.posts (league_id, image_hash)
  WHERE image_hash IS NOT NULL
    AND league_id IS NOT NULL
    AND COALESCE(is_deleted, false) = false;

-- 사전 조회(업로드 전 중복 확인)용 인덱스는 위 두 부분 인덱스가 그대로 사용된다.
