-- [MEDIUM] 스토리지 하드닝
--
-- 문제 1: post_images / post_videos / league_images 의 업로드(INSERT) 정책이 bucket_id 만 검사해서,
--         누구나 임의 파일을 올리거나 남의 uid 접두어로 파일을 올릴 수 있었음.
-- 문제 2: 공개 버킷(avatars/league_images/post_videos)의 SELECT 정책이 anon 목록조회(list)를 허용해
--         업로드된 파일 전체를 열거할 수 있었음.
--
-- 경로 규칙(앱 확인): 전부 "{폴더}/{uid}_..." 형태
--   - post_images : posts/{uid}_...  또는 marketplace/{uid}_...
--   - post_videos : posts/{uid}_...
--   - league_images: leagues/{hostId}_...
--   → 소유자 uid = split_part(split_part(name,'/',2),'_',1)
--
-- 표시는 전부 getPublicUrl(공개 CDN, RLS 미적용)이고 앱은 .list()/.download()를 쓰지 않으므로
-- SELECT 정책을 authenticated로 좁혀도 이미지 표시는 정상.

-- ── 1) 업로드: 본인 uid 접두어만 허용 ────────────────────────────────
DROP POLICY IF EXISTS "Authenticated upload post_images" ON storage.objects;
CREATE POLICY "post_images owner insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'post_images'
    AND split_part(split_part(name, '/', 2), '_', 1) = auth.uid()::text
  );

DROP POLICY IF EXISTS "Authenticated users can upload post videos" ON storage.objects;
CREATE POLICY "post_videos owner insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'post_videos'
    AND split_part(split_part(name, '/', 2), '_', 1) = auth.uid()::text
  );

DROP POLICY IF EXISTS "league_images_insert" ON storage.objects;
CREATE POLICY "league_images owner insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'league_images'
    AND split_part(split_part(name, '/', 2), '_', 1) = auth.uid()::text
  );

-- ── 2) 삭제: 본인 파일만 (기존 정책은 경로 규칙과 안 맞아 무효였음) ──────
DROP POLICY IF EXISTS "Owner delete post_images" ON storage.objects;
CREATE POLICY "post_images owner delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'post_images'
    AND split_part(split_part(name, '/', 2), '_', 1) = auth.uid()::text
  );

CREATE POLICY "post_videos owner delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'post_videos'
    AND split_part(split_part(name, '/', 2), '_', 1) = auth.uid()::text
  );

DROP POLICY IF EXISTS "league_images_delete" ON storage.objects;
CREATE POLICY "league_images owner delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'league_images'
    AND split_part(split_part(name, '/', 2), '_', 1) = auth.uid()::text
  );

-- ── 3) 목록조회(list) 차단: 공개 버킷 SELECT를 authenticated로 축소 ────
--     (표시는 공개 CDN URL이라 영향 없음. anon 파일 열거만 차단)
DROP POLICY IF EXISTS "avatars_public_read" ON storage.objects;
CREATE POLICY "avatars authed read" ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "league_images_select" ON storage.objects;
CREATE POLICY "league_images authed read" ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'league_images');

DROP POLICY IF EXISTS "Anyone can read post videos" ON storage.objects;
CREATE POLICY "post_videos authed read" ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'post_videos');

-- ── 4) 존재하지 않는 'post-images'(하이픈) 버킷용 죽은 정책 정리 ────────
DROP POLICY IF EXISTS "Authenticated upload post-images" ON storage.objects;
DROP POLICY IF EXISTS "Owner delete post-images" ON storage.objects;
