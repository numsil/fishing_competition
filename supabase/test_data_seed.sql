-- ================================================================
-- 테스트 데이터 시드 스크립트
-- Supabase 대시보드 → SQL Editor 에서 실행하세요
-- 프로젝트: https://zpcmpfrswlbnqkqrmvxu.supabase.co
-- ================================================================

-- ── 0. DB 스키마 마이그레이션 (컬럼 없으면 추가) ─────────────────
ALTER TABLE leagues ADD COLUMN IF NOT EXISTS fish_types TEXT DEFAULT '배스';
ALTER TABLE leagues ADD COLUMN IF NOT EXISTS rule TEXT DEFAULT '최대어';
ALTER TABLE leagues ADD COLUMN IF NOT EXISTS catch_limit INTEGER DEFAULT 1;
ALTER TABLE leagues ADD COLUMN IF NOT EXISTS prize_info TEXT;
ALTER TABLE leagues ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT true;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS weight NUMERIC;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS catch_count INTEGER DEFAULT 1;

-- 유저 ID 정리
-- 운영자:  bc678d73-0e5f-4417-ad8a-27520c1be9cb
-- 루코:    898e8a90-e14f-406f-8658-ed24b1a9a23d
-- 다슬기:  1e2076b5-d12b-4316-a9b5-49ad396cdf85

-- ── 1. 리그 상태 → 진행중 (in_progress) ──────────────────────────
UPDATE leagues
SET
  status      = 'in_progress',
  start_time  = NOW() - INTERVAL '3 hours',
  end_time    = NOW() + INTERVAL '21 hours',
  rule        = '합산 길이',
  catch_limit = 3
WHERE id = 'c9d80b22-3641-4d98-80cf-f119f541781f';

-- ── 2. 참가자 3명 등록 (approved) ────────────────────────────────
INSERT INTO league_participants (league_id, user_id, status)
VALUES
  ('c9d80b22-3641-4d98-80cf-f119f541781f', 'bc678d73-0e5f-4417-ad8a-27520c1be9cb', 'approved'),
  ('c9d80b22-3641-4d98-80cf-f119f541781f', '898e8a90-e14f-406f-8658-ed24b1a9a23d', 'approved'),
  ('c9d80b22-3641-4d98-80cf-f119f541781f', '1e2076b5-d12b-4316-a9b5-49ad396cdf85', 'approved')
ON CONFLICT (league_id, user_id) DO UPDATE SET status = 'approved';

-- ── 3. 조과 기록 (순위표용 posts) ────────────────────────────────

-- 운영자 조과: 배스 52cm (런커!), 44cm
INSERT INTO posts (user_id, league_id, image_url, caption, fish_type, length, lure_type, location, lat, lng, is_lunker, created_at)
VALUES
  (
    'bc678d73-0e5f-4417-ad8a-27520c1be9cb',
    'c9d80b22-3641-4d98-80cf-f119f541781f',
    'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=800',
    '아침부터 런커 터졌다! 52cm 🎣',
    '배스', 52.0, '크랭크베이트',
    '충주호', 36.9910, 127.9850,
    true,
    NOW() - INTERVAL '2 hours 30 minutes'
  ),
  (
    'bc678d73-0e5f-4417-ad8a-27520c1be9cb',
    'c9d80b22-3641-4d98-80cf-f119f541781f',
    'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=800',
    '두 번째도 나왔다 44cm',
    '배스', 44.0, '스피너베이트',
    '충주호', 36.9910, 127.9850,
    false,
    NOW() - INTERVAL '1 hour 45 minutes'
  );

-- 루코 조과: 배스 48cm, 41cm, 38cm
INSERT INTO posts (user_id, league_id, image_url, caption, fish_type, length, lure_type, location, lat, lng, is_lunker, created_at)
VALUES
  (
    '898e8a90-e14f-406f-8658-ed24b1a9a23d',
    'c9d80b22-3641-4d98-80cf-f119f541781f',
    'https://images.unsplash.com/photo-1543726969-a1da85a6d334?w=800',
    '48cm 나왔어요! 오늘 컨디션 좋은데?',
    '배스', 48.0, '지그',
    '충주호 서쪽', 36.9900, 127.9800,
    false,
    NOW() - INTERVAL '2 hours'
  ),
  (
    '898e8a90-e14f-406f-8658-ed24b1a9a23d',
    'c9d80b22-3641-4d98-80cf-f119f541781f',
    'https://images.unsplash.com/photo-1516731415730-0c607149933a?w=800',
    '41cm 추가!',
    '배스', 41.0, '웜',
    '충주호 서쪽', 36.9900, 127.9800,
    false,
    NOW() - INTERVAL '1 hour 20 minutes'
  ),
  (
    '898e8a90-e14f-406f-8658-ed24b1a9a23d',
    'c9d80b22-3641-4d98-80cf-f119f541781f',
    'https://images.unsplash.com/photo-1504197832061-98356e3dcdcf?w=800',
    '막내 38cm ㅋㅋ',
    '배스', 38.0, '웜',
    '충주호 서쪽', 36.9900, 127.9800,
    false,
    NOW() - INTERVAL '40 minutes'
  );

-- 다슬기 조과: 배스 45cm, 43cm
INSERT INTO posts (user_id, league_id, image_url, caption, fish_type, length, lure_type, location, lat, lng, is_lunker, created_at)
VALUES
  (
    '1e2076b5-d12b-4316-a9b5-49ad396cdf85',
    'c9d80b22-3641-4d98-80cf-f119f541781f',
    'https://images.unsplash.com/photo-1518732714860-b62714ce0c59?w=800',
    '45cm! 런커까지 5cm 남았다',
    '배스', 45.0, '탑워터',
    '충주호 북쪽', 36.9950, 127.9870,
    false,
    NOW() - INTERVAL '1 hour 50 minutes'
  ),
  (
    '1e2076b5-d12b-4316-a9b5-49ad396cdf85',
    'c9d80b22-3641-4d98-80cf-f119f541781f',
    'https://images.unsplash.com/photo-1497015289639-54688650d173?w=800',
    '43cm도 추가! 합산으로 승부한다',
    '배스', 43.0, '탑워터',
    '충주호 북쪽', 36.9950, 127.9870,
    false,
    NOW() - INTERVAL '55 minutes'
  );

-- ── 4. 좋아요 데이터 ──────────────────────────────────────────────
-- 런커 게시물에 좋아요
INSERT INTO post_likes (post_id, user_id)
SELECT p.id, '898e8a90-e14f-406f-8658-ed24b1a9a23d'
FROM posts p
WHERE p.user_id = 'bc678d73-0e5f-4417-ad8a-27520c1be9cb'
  AND p.length = 52
ON CONFLICT DO NOTHING;

INSERT INTO post_likes (post_id, user_id)
SELECT p.id, '1e2076b5-d12b-4316-a9b5-49ad396cdf85'
FROM posts p
WHERE p.user_id = 'bc678d73-0e5f-4417-ad8a-27520c1be9cb'
  AND p.length = 52
ON CONFLICT DO NOTHING;

-- ── 5. 댓글 데이터 ───────────────────────────────────────────────
INSERT INTO post_comments (post_id, user_id, content)
SELECT p.id, '898e8a90-e14f-406f-8658-ed24b1a9a23d', '와 런커 대박이다!! 🔥'
FROM posts p
WHERE p.user_id = 'bc678d73-0e5f-4417-ad8a-27520c1be9cb' AND p.length = 52;

INSERT INTO post_comments (post_id, user_id, content)
SELECT p.id, '1e2076b5-d12b-4316-a9b5-49ad396cdf85', '부럽다... 저도 런커 한번만요 ㅠㅠ'
FROM posts p
WHERE p.user_id = 'bc678d73-0e5f-4417-ad8a-27520c1be9cb' AND p.length = 52;

-- ── 결과 확인 ─────────────────────────────────────────────────────
SELECT '=== 리그 상태 ===' AS info;
SELECT id, title, status, start_time, end_time FROM leagues WHERE id = 'c9d80b22-3641-4d98-80cf-f119f541781f';

SELECT '=== 참가자 ===' AS info;
SELECT lp.user_id, u.username, lp.status
FROM league_participants lp
JOIN users u ON u.id = lp.user_id
WHERE lp.league_id = 'c9d80b22-3641-4d98-80cf-f119f541781f';

SELECT '=== 순위표 (최대어 기준) ===' AS info;
SELECT u.username, MAX(p.length) AS 최대어_cm, SUM(p.length) AS 합산_cm, COUNT(*) AS 마릿수
FROM posts p
JOIN users u ON u.id = p.user_id
WHERE p.league_id = 'c9d80b22-3641-4d98-80cf-f119f541781f'
GROUP BY u.username
ORDER BY 최대어_cm DESC;
