-- ================================================================
-- 프로필 사진(avatars) Storage 버킷 + RLS 설정
-- Supabase 대시보드 → SQL Editor 에서 실행하세요
-- ================================================================

-- 1. avatars 버킷 생성 (이미 있으면 무시)
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- 2. 기존 정책 제거 (재실행 시 충돌 방지)
DROP POLICY IF EXISTS "avatars_public_read"   ON storage.objects;
DROP POLICY IF EXISTS "avatars_owner_upload"  ON storage.objects;
DROP POLICY IF EXISTS "avatars_owner_update"  ON storage.objects;
DROP POLICY IF EXISTS "avatars_owner_delete"  ON storage.objects;

-- 3. 누구나 읽기 가능 (public 버킷)
CREATE POLICY "avatars_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

-- 4. 본인 폴더({userId}/avatar.ext)만 업로드/수정/삭제 가능
CREATE POLICY "avatars_owner_upload" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "avatars_owner_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "avatars_owner_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
