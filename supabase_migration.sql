-- ============================================================
-- app_versions 테이블 재구성 (env별 독립 버전 관리)
-- Supabase SQL Editor에서 실행
-- ============================================================

-- 기존 테이블 삭제 후 재생성
DROP TABLE IF EXISTS app_versions;

CREATE TABLE app_versions (
  env           text PRIMARY KEY,       -- 'production' | 'staging' | 'development'
  version       text NOT NULL,          -- 예: "1.0.1"
  build_number  int  NOT NULL,          -- 예: 3 (pubspec의 version: 1.0.1+3)
  apk_url       text,                   -- Android APK 다운로드 URL
  ios_url       text,                   -- iOS TestFlight URL
  release_notes text,                   -- 업데이트 내용 (커밋 메시지 자동 입력)
  force_update  boolean DEFAULT false,  -- true = 강제 업데이트 (나중에 버튼 숨김)
  updated_at    timestamptz DEFAULT now()
);

-- ── RLS 설정 ──────────────────────────────────────────────────
ALTER TABLE app_versions ENABLE ROW LEVEL SECURITY;

-- 앱에서 읽기 허용 (anon key)
CREATE POLICY "app_versions_public_read" ON app_versions
  FOR SELECT USING (true);

-- GitHub Actions에서 쓰기 허용 (service key → RLS 우회)
-- service key는 RLS를 자동으로 우회하므로 별도 정책 불필요

-- ── 초기 데이터 (현재 버전으로 설정 → 업데이트 알림 안 뜸) ───
INSERT INTO app_versions (env, version, build_number) VALUES
  ('production',   '1.0.0', 1),
  ('staging',      '1.0.0', 1),
  ('development',  '1.0.0', 1)
ON CONFLICT (env) DO NOTHING;
