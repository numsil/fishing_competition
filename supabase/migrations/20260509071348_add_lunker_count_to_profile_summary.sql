-- get_user_profile_summary RPC에 lunker_count 추가.
-- 리그 게시물(league_id IS NOT NULL) + 개인 기록(is_personal_record = true) 중
-- is_lunker = true 인 승인된(approved) 게시물 수를 합산.

CREATE OR REPLACE FUNCTION public.get_user_profile_summary(p_user_id uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    AS $$
    DECLARE
      v_season_start timestamp := (EXTRACT(YEAR FROM NOW())::int::text || '-01-01')::timestamp;
      v_season_end   timestamp := ((EXTRACT(YEAR FROM NOW())::int + 1)::text || '-01-01')::timestamp;
      v_user record;
      v_catch_score int;
      v_bonus_score int;
      v_angler_score int;
      v_max_fish record;
      v_stats record;
      v_lunker_count int;
    BEGIN
      SELECT id, email, username, user_key, avatar_url, manner_temperature, is_lunker_club
      INTO v_user
      FROM users WHERE id = p_user_id;
      IF NOT FOUND THEN RETURN NULL; END IF;

      -- 진행중/완료 리그 조과만 점수 합산
      SELECT COALESCE(SUM(p.score), 0)::int INTO v_catch_score
      FROM posts p
      JOIN leagues l ON l.id = p.league_id
      WHERE p.user_id = p_user_id
        AND p.review_status = 'approved' AND COALESCE(p.is_deleted, false) = false
        AND p.created_at >= v_season_start AND p.created_at < v_season_end
        AND l.status IN ('in_progress', 'completed');

      SELECT COALESCE(SUM(rank_bonus), 0)::int INTO v_bonus_score
      FROM league_participants
      WHERE user_id = p_user_id AND rank_bonus > 0
        AND rank_bonus_earned_at >= v_season_start AND rank_bonus_earned_at < v_season_end;

      SELECT COALESCE(SUM(score), 0)::int INTO v_angler_score
      FROM posts
      WHERE user_id = p_user_id AND is_personal_record = true
        AND review_status = 'approved' AND COALESCE(is_deleted, false) = false
        AND created_at >= v_season_start AND created_at < v_season_end;

      SELECT p.id, p.image_url, p.fish_type, p.length, p.location, p.created_at
      INTO v_max_fish
      FROM posts p
      LEFT JOIN leagues l ON l.id = p.league_id
      WHERE p.user_id = p_user_id AND p.review_status = 'approved'
        AND COALESCE(p.is_deleted, false) = false AND p.length IS NOT NULL
        AND (p.league_id IS NULL OR l.status IN ('in_progress', 'completed'))
      ORDER BY p.length DESC LIMIT 1;

      -- 리그 게시물 + 개인 기록 중 런커 + 승인된 것의 합
      SELECT COUNT(*)::int INTO v_lunker_count
      FROM posts
      WHERE user_id = p_user_id
        AND is_lunker = true
        AND review_status = 'approved'
        AND COALESCE(is_deleted, false) = false
        AND (league_id IS NOT NULL OR is_personal_record = true);

      SELECT * INTO v_stats FROM get_user_league_stats(p_user_id);

      RETURN jsonb_build_object(
        'id', v_user.id,
        'email', v_user.email,
        'username', v_user.username,
        'user_key', v_user.user_key,
        'avatar_url', v_user.avatar_url,
        'manner_temperature', v_user.manner_temperature,
        'is_lunker_club', COALESCE(v_user.is_lunker_club, false),
        'league_score', v_catch_score + v_bonus_score,
        'angler_score', v_angler_score,
        'participation_count', COALESCE(v_stats.participation_count, 0),
        'win_count', COALESCE(v_stats.win_count, 0),
        'lunker_count', v_lunker_count,
        'max_fish', CASE
          WHEN v_max_fish.id IS NULL THEN NULL
          ELSE jsonb_build_object(
            'id', v_max_fish.id,
            'image_url', v_max_fish.image_url,
            'fish_type', v_max_fish.fish_type,
            'length', v_max_fish.length,
            'location', v_max_fish.location,
            'created_at', v_max_fish.created_at
          )
        END
      );
    END;
  $$;
