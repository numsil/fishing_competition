-- 진행중 리그 테스트 데이터 (전체 기능 확인용)
-- Supabase Dashboard > SQL Editor 에서 실행
-- migration_league_fields.sql 과 migration_catch_fields.sql 먼저 실행 필요

DO $$
DECLARE
  v_user_id   UUID := 'bc678d73-0e5f-4417-ad8a-27520c1be9cb';
  v_league_id UUID;
BEGIN

  -- ── 1. 진행중 리그 생성 ─────────────────────────────────
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
    '충주호 배스 오픈 2026 🔴 LIVE',
    '충주호에서 열리는 배스 낚시 오픈 대회입니다.'
    || E'\n최대어 기준으로 순위를 결정하며, 50cm 이상은 런커로 인정됩니다.'
    || E'\n\n📌 규칙'
    || E'\n- 배스만 인정 (스몰마우스 포함)'
    || E'\n- 생미끼 사용 금지 (루어만 허용)'
    || E'\n- 계측 후 즉시 방류 원칙'
    || E'\n- 조과 사진 필수 등록',
    '충주호',
    36.9910, 127.9850,
    NOW() - INTERVAL '2 hours',   -- 2시간 전 시작
    NOW() + INTERVAL '6 hours',   -- 6시간 후 종료
    10000,
    30,
    'in_progress',
    '배스, 배스(스몰)',
    '최대어',
    E'1위: 300,000원\n2위: 150,000원\n3위: 80,000원',
    true
  ) RETURNING id INTO v_league_id;

  -- ── 2. 나(호스트) 참가 등록 ────────────────────────────
  INSERT INTO league_participants (league_id, user_id, status, has_paid)
  VALUES (v_league_id, v_user_id, 'approved', true)
  ON CONFLICT (league_id, user_id) DO NOTHING;

  -- ── 3. 테스트 조과 게시물 3건 ──────────────────────────
  INSERT INTO posts (
    user_id, league_id, image_url,
    fish_type, length, weight, catch_count,
    is_lunker, location, caption
  ) VALUES
    (
      v_user_id, v_league_id,
      'https://picsum.photos/seed/catch1/400/400',
      '배스', 42.5, 980, 1,
      false, '충주호 북쪽',
      '오전 첫 조과! 상태 좋은 배스 #배스 #충주호 #조황'
    ),
    (
      v_user_id, v_league_id,
      'https://picsum.photos/seed/catch2/400/400',
      '배스', 55.3, 1820, 1,
      true, '충주호 남쪽 포인트',
      '런커 등장!! 역대 최대어 경신 🎣 #배스 #런커 #충주호'
    ),
    (
      v_user_id, v_league_id,
      'https://picsum.photos/seed/catch3/400/400',
      '배스', 38.2, 750, 2,
      false, '충주호 중앙',
      '연속 히트! 2마리 동시에 #배스 #조황 #충주호'
    );

  RAISE NOTICE '✅ 리그 ID: %', v_league_id;
  RAISE NOTICE '✅ 참가자 등록 완료';
  RAISE NOTICE '✅ 조과 3건 등록 완료';

END $$;
