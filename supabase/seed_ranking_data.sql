-- 리그 순위 테스트 데이터
-- Supabase Dashboard > SQL Editor 에서 실행
-- (seed_leagues.sql 먼저 실행되어 있어야 합니다)

DO $$
DECLARE
  v_host_id     UUID := 'bc678d73-0e5f-4417-ad8a-27520c1be9cb';
  v_inprogress  UUID;
  v_completed   UUID;
BEGIN

  -- 리그 ID 조회
  SELECT id INTO v_inprogress  FROM leagues WHERE status = 'in_progress'  ORDER BY created_at LIMIT 1;
  SELECT id INTO v_completed   FROM leagues WHERE status = 'completed'    ORDER BY created_at LIMIT 1;

  -- ── 진행중 리그: 호스트 참가 등록 ──────────────────────
  INSERT INTO league_participants (league_id, user_id, status, has_paid)
  VALUES (v_inprogress, v_host_id, 'approved', true)
  ON CONFLICT (league_id, user_id) DO NOTHING;

  -- ── 진행중 리그: 조과 게시물 2건 ────────────────────────
  INSERT INTO posts (user_id, league_id, image_url, fish_type, length, is_lunker, location, caption)
  VALUES
    (v_host_id, v_inprogress,
     'https://picsum.photos/seed/bass1/400/400',
     '배스', 42.5, false, '소양강댐',
     '오전 조과! #배스 #조황 #소양강'),
    (v_host_id, v_inprogress,
     'https://picsum.photos/seed/bass2/400/400',
     '배스', 55.3, true, '소양강댐',
     '런커 등장!! #배스 #런커 #소양강');

  -- ── 종료 리그: 호스트 참가 등록 ────────────────────────
  INSERT INTO league_participants (league_id, user_id, status, has_paid)
  VALUES (v_completed, v_host_id, 'approved', true)
  ON CONFLICT (league_id, user_id) DO NOTHING;

  -- ── 종료 리그: 조과 게시물 2건 ──────────────────────────
  INSERT INTO posts (user_id, league_id, image_url, fish_type, length, is_lunker, location, caption)
  VALUES
    (v_host_id, v_completed,
     'https://picsum.photos/seed/bass3/400/400',
     '배스', 38.2, false, '가평',
     '가평 조과 #배스 #가평'),
    (v_host_id, v_completed,
     'https://picsum.photos/seed/bass4/400/400',
     '배스', 47.8, false, '가평',
     '역대급 조황 #배스 #조황 #가평');

END $$;
