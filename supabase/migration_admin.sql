-- ============================================================
-- 관리자 대시보드용 마이그레이션
-- Supabase Dashboard > SQL Editor 에서 실행
-- ============================================================

-- 1. users 테이블 컬럼 추가
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active' CHECK (status IN ('active', 'banned')),
  ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false NOT NULL;

-- 2. posts 테이블 컬럼 추가
ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS video_url TEXT;

-- post_videos 스토리지 버킷 생성 (공개)
INSERT INTO storage.buckets (id, name, public)
VALUES ('post_videos', 'post_videos', true)
ON CONFLICT (id) DO NOTHING;

-- post_videos 버킷 접근 정책
CREATE POLICY IF NOT EXISTS "Anyone can read post videos"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'post_videos');

CREATE POLICY IF NOT EXISTS "Authenticated users can upload post videos"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'post_videos' AND auth.role() = 'authenticated');

-- 3. reports 테이블 (신고)
CREATE TABLE IF NOT EXISTS reports (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  reporter_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  reason TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'rejected')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- 4. tickets 테이블 (문의)
CREATE TABLE IF NOT EXISTS tickets (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'closed')),
  admin_reply TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- 5. score_logs 테이블 (점수 변경 로그)
CREATE TABLE IF NOT EXISTS score_logs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  change NUMERIC NOT NULL,
  reason TEXT NOT NULL,
  admin_id UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- 6. badges 테이블 (배지)
CREATE TABLE IF NOT EXISTS badges (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  icon_url TEXT,
  condition TEXT,
  is_active BOOLEAN DEFAULT true NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- 7. user_badges 테이블 (유저-배지 관계)
CREATE TABLE IF NOT EXISTS user_badges (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  badge_id UUID REFERENCES badges(id) ON DELETE CASCADE NOT NULL,
  assigned_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
  UNIQUE(user_id, badge_id)
);

-- 8. RLS 활성화
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE score_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;

-- 9. RLS 정책 (관리자 대시보드는 service_role key 사용으로 RLS bypass)
-- 앱 유저용 정책만 추가
DROP POLICY IF EXISTS "Users can create reports." ON reports;
CREATE POLICY "Users can create reports." ON reports
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can view own reports." ON reports;
CREATE POLICY "Users can view own reports." ON reports
  FOR SELECT USING (auth.uid() = reporter_id);

DROP POLICY IF EXISTS "Users can create tickets." ON tickets;
CREATE POLICY "Users can create tickets." ON tickets
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view own tickets." ON tickets;
CREATE POLICY "Users can view own tickets." ON tickets
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Badges are viewable by everyone." ON badges;
CREATE POLICY "Badges are viewable by everyone." ON badges
  FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "User badges are viewable by everyone." ON user_badges;
CREATE POLICY "User badges are viewable by everyone." ON user_badges
  FOR SELECT USING (true);
