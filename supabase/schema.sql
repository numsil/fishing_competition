-- 피싱그램(Fishing Gram) Supabase 데이터베이스 스키마

-- UUID 생성을 위한 확장 기능 활성화 (필수)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Users (사용자)
CREATE TABLE users (
  id UUID REFERENCES auth.users NOT NULL PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  username TEXT NOT NULL,
  avatar_url TEXT,
  manner_temperature NUMERIC DEFAULT 36.5, -- 당근 온도 (매너 점수)
  is_lunker_club BOOLEAN DEFAULT false, -- 런커 클럽 배지 여부
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 2. Leagues (리그/대회)
CREATE TABLE leagues (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  host_id UUID REFERENCES users(id) NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  location TEXT NOT NULL, -- 장소 이름 (예: 충주호)
  lat NUMERIC, -- 위도
  lng NUMERIC, -- 경도
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE NOT NULL,
  entry_fee INTEGER DEFAULT 0,
  max_participants INTEGER DEFAULT 100,
  status TEXT DEFAULT 'recruiting' CHECK (status IN ('recruiting', 'in_progress', 'completed', 'canceled')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 3. League Participants (리그 참가자)
CREATE TABLE league_participants (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  league_id UUID REFERENCES leagues(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  has_paid BOOLEAN DEFAULT false, -- 입금 여부
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  UNIQUE(league_id, user_id)
);

-- 4. Posts (조과 피드 게시물)
CREATE TABLE posts (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  league_id UUID REFERENCES leagues(id) ON DELETE SET NULL, -- 리그 참여 중 올린 조과인 경우
  image_url TEXT NOT NULL,
  caption TEXT,
  fish_type TEXT DEFAULT '배스',
  length NUMERIC, -- 길이 (cm)
  lure_type TEXT,
  depth NUMERIC, -- 수심
  temperature NUMERIC, -- 기온
  location TEXT, -- 측정 장소 이름
  lat NUMERIC, -- GPS 검증용 위도
  lng NUMERIC, -- GPS 검증용 경도
  is_lunker BOOLEAN DEFAULT false, -- 50cm 이상 런커 여부
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 5. Post Likes (좋아요)
CREATE TABLE post_likes (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  UNIQUE(post_id, user_id)
);

-- 6. Post Comments (댓글)
CREATE TABLE post_comments (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Row Level Security (RLS) 설정 (기본적으로 모두 허용하는 예시, 운영 시 수정 필요)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE leagues ENABLE ROW LEVEL SECURITY;
ALTER TABLE league_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public profiles are viewable by everyone." ON users FOR SELECT USING (true);
CREATE POLICY "Users can insert their own profile." ON users FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own profile." ON users FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Leagues are viewable by everyone." ON leagues FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create leagues." ON leagues FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Participants viewable by everyone." ON league_participants FOR SELECT USING (true);
CREATE POLICY "Authenticated users can join leagues." ON league_participants FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Posts are viewable by everyone." ON posts FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create posts." ON posts FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Likes are viewable by everyone." ON post_likes FOR SELECT USING (true);
CREATE POLICY "Authenticated users can toggle likes." ON post_likes FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Users can delete own likes." ON post_likes FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Comments are viewable by everyone." ON post_comments FOR SELECT USING (true);
CREATE POLICY "Authenticated users can comment." ON post_comments FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Users can delete own comments." ON post_comments FOR DELETE USING (auth.uid() = user_id);
