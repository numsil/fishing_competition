-- ============================================================
-- 전체 테스트 데이터 (마이그레이션 포함) - 한 번에 실행
-- Supabase Dashboard > SQL Editor 에서 전체 복사 후 실행
-- ============================================================

-- ── Step 1: 컬럼 추가 (이미 있으면 무시) ────────────────────
ALTER TABLE leagues
  ADD COLUMN IF NOT EXISTS fish_types TEXT    DEFAULT '배스',
  ADD COLUMN IF NOT EXISTS rule       TEXT    DEFAULT '최대어',
  ADD COLUMN IF NOT EXISTS prize_info TEXT,
  ADD COLUMN IF NOT EXISTS is_public  BOOLEAN DEFAULT true;

ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS weight      NUMERIC,
  ADD COLUMN IF NOT EXISTS catch_count INTEGER DEFAULT 1;

-- ── Step 2: 현재 로그인한 유저 ID 확인 및 데이터 삽입 ───────
DO $$
DECLARE
  v_user_id   UUID;
  v_league_id UUID;
BEGIN

  -- public.users 에서 첫 번째 유저 ID 가져오기
  SELECT id INTO v_user_id FROM public.users LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '❌ public.users 테이블에 유저가 없습니다. 앱에서 먼저 로그인해주세요.';
  END IF;

  RAISE NOTICE '✅ 유저 ID: %', v_user_id;

  -- ── Step 3: 기존 테스트 리그 정리 (중복 방지) ──────────────
  DELETE FROM leagues WHERE title = '충주호 배스 오픈 2026 LIVE' AND host_id = v_user_id;

  -- ── Step 4: 진행중 리그 생성 ───────────────────────────────
  INSERT INTO leagues (
    host_id, title, description, location,
    lat, lng,
    start_time, end_time,
    entry_fee, max_participants,
    status,
    fish_types, rule,
    prize_info, is_public
  ) VALUES (
    v_user_id,
    '충주호 배스 오픈 2026 LIVE',
    '충주호에서 열리는 배스 낚시 오픈 대회입니다.' || E'\n' ||
    '최대어 기준으로 순위를 결정하며, 50cm 이상은 런커로 인정됩니다.' || E'\n\n' ||
    '📌 규칙' || E'\n' ||
    '- 배스만 인정 (스몰마우스 포함)' || E'\n' ||
    '- 생미끼 사용 금지 (루어만 허용)' || E'\n' ||
    '- 계측 후 즉시 방류 원칙' || E'\n' ||
    '- 조과 사진 필수 등록',
    '충주호',
    36.9910, 127.9850,
    NOW() - INTERVAL '2 hours',
    NOW() + INTERVAL '6 hours',
    10000, 30,
    'in_progress',
    '배스, 배스(스몰)',
    '최대어',
    '1위: 300,000원' || E'\n' || '2위: 150,000원' || E'\n' || '3위: 80,000원',
    true
  ) RETURNING id INTO v_league_id;

  RAISE NOTICE '✅ 리그 생성 완료. ID: %', v_league_id;

  -- ── Step 5: 참가자 등록 ────────────────────────────────────
  INSERT INTO league_participants (league_id, user_id, status, has_paid)
  VALUES (v_league_id, v_user_id, 'approved', true)
  ON CONFLICT (league_id, user_id) DO NOTHING;

  RAISE NOTICE '✅ 참가자 등록 완료';

  -- ── Step 6: 조과 게시물 등록 ──────────────────────────────
  INSERT INTO posts (
    user_id, league_id, image_url,
    fish_type, length, weight, catch_count,
    is_lunker, location, caption
  ) VALUES
    (
      v_user_id, v_league_id,
      'https://picsum.photos/seed/bass_a/400/400',
      '배스', 42.5, 980, 1,
      false, '충주호 북쪽',
      '오전 첫 조과! 상태 좋은 배스 #배스 #충주호 #조황'
    ),
    (
      v_user_id, v_league_id,
      'https://picsum.photos/seed/bass_b/400/400',
      '배스', 55.3, 1820, 1,
      true, '충주호 남쪽 포인트',
      '런커 등장!! #배스 #런커 #충주호'
    ),
    (
      v_user_id, v_league_id,
      'https://picsum.photos/seed/bass_c/400/400',
      '배스', 38.2, 750, 2,
      false, '충주호 중앙',
      '연속 히트! 2마리 동시에 #배스 #조황 #충주호'
    );

  RAISE NOTICE '✅ 조과 3건 등록 완료';
  RAISE NOTICE '🎉 모든 테스트 데이터 삽입 완료!';

END $$;

-- ── 확인용 조회 ─────────────────────────────────────────────
SELECT
  l.id,
  l.title,
  l.status,
  l.fish_types,
  l.rule,
  COUNT(lp.id) AS participants
FROM leagues l
LEFT JOIN league_participants lp ON lp.league_id = l.id
WHERE l.status = 'in_progress'
GROUP BY l.id, l.title, l.status, l.fish_types, l.rule
ORDER BY l.created_at DESC;
