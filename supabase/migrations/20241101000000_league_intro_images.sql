-- leagues 테이블에 소개 이미지 배열 + short_description 컬럼 추가
-- league_images 스토리지 버킷 생성 + RLS

ALTER TABLE leagues
  ADD COLUMN IF NOT EXISTS intro_image_urls TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS short_description TEXT;

INSERT INTO storage.buckets (id, name, public)
VALUES ('league_images', 'league_images', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "league_images_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'league_images');

CREATE POLICY "league_images_select" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'league_images');

CREATE POLICY "league_images_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'league_images' AND auth.uid()::text = (storage.foldername(name))[1]);
