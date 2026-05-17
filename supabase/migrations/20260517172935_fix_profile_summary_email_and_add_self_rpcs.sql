-- ============================================================
-- Part 1/2: Fix RPC email leak + add self-only RPCs
-- ------------------------------------------------------------
-- 본 마이그레이션은 클라이언트 코드 변경 없이 안전하게 적용 가능.
-- (컬럼 권한 REVOKE 는 Part 2 의 별도 마이그레이션에서, 신버전
--  클라 배포 후 적용한다.)
--
-- 변경 내용:
--   B. get_user_profile_summary RPC 의 응답에서 email 제거
--      → 타인 프로필 조회 시 email 누출 차단
--      → 기존 클라는 data['email'] 를 null-coalesce 로 받으므로
--        UI 깨짐 없음 (profile_repository.dart:77 참고).
--   C. get_my_account_status() 신설
--      → 본인 status/is_deleted/role/is_verifier/
--        location_agreed_at/email 한 번에 반환.
--      → SECURITY DEFINER + auth.uid() 게이팅.
--   D. find_invitable_user(p_user_key text) 신설
--      → 초대 검색 시 타인 status/is_deleted 노출 없이
--        active 사용자만 반환.
--
-- Part 2 (별도 파일, 신버전 클라 배포 후 적용):
--   A. users 테이블의 anon/authenticated SELECT 권한을
--      안전한 공개 컬럼으로만 잠금 (REVOKE / GRANT cols).
-- ============================================================


-- ── B) get_user_profile_summary 에서 email 제거 ───────────
--    follow_fixes.sql 의 정의 기반, email 만 제거.
CREATE OR REPLACE FUNCTION public.get_user_profile_summary(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE
SET search_path = public
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
      v_follower_count int;
      v_following_count int;
      v_is_following boolean;
      v_viewer_id uuid := auth.uid();
    BEGIN
      SELECT id, username, user_key, avatar_url, manner_temperature, is_lunker_club
      INTO v_user
      FROM users WHERE id = p_user_id;
      IF NOT FOUND THEN RETURN NULL; END IF;

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

      SELECT COUNT(*)::int INTO v_lunker_count
      FROM posts
      WHERE user_id = p_user_id
        AND is_lunker = true
        AND review_status = 'approved'
        AND COALESCE(is_deleted, false) = false
        AND (league_id IS NOT NULL OR is_personal_record = true);

      SELECT * INTO v_stats FROM get_user_league_stats(p_user_id);

      SELECT COUNT(*)::int INTO v_follower_count
      FROM follows f
      JOIN users u ON u.id = f.follower_id
      WHERE f.followee_id = p_user_id
        AND COALESCE(u.is_deleted, false) = false;

      SELECT COUNT(*)::int INTO v_following_count
      FROM follows f
      JOIN users u ON u.id = f.followee_id
      WHERE f.follower_id = p_user_id
        AND COALESCE(u.is_deleted, false) = false;

      IF v_viewer_id IS NULL OR v_viewer_id = p_user_id THEN
        v_is_following := false;
      ELSE
        SELECT EXISTS(
          SELECT 1 FROM follows
          WHERE follower_id = v_viewer_id AND followee_id = p_user_id
        ) INTO v_is_following;
      END IF;

      RETURN jsonb_build_object(
        'id', v_user.id,
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
        'follower_count', v_follower_count,
        'following_count', v_following_count,
        'is_following', v_is_following,
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


-- ── C) 본인 계정 상태 통합 조회 RPC ────────────────────────
CREATE OR REPLACE FUNCTION public.get_my_account_status()
RETURNS TABLE (
  status text,
  is_deleted boolean,
  role text,
  is_verifier boolean,
  location_agreed_at timestamptz,
  email text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    u.status,
    u.is_deleted,
    u.role,
    u.is_verifier,
    u.location_agreed_at,
    u.email
  FROM public.users u
  WHERE u.id = auth.uid();
$$;

REVOKE EXECUTE ON FUNCTION public.get_my_account_status() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_my_account_status() TO authenticated;


-- ── D) 초대용 사용자 검색 RPC ───────────────────────────────
CREATE OR REPLACE FUNCTION public.find_invitable_user(p_user_key text)
RETURNS TABLE (
  id uuid,
  username text,
  user_key text,
  avatar_url text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT u.id, u.username, u.user_key, u.avatar_url
  FROM public.users u
  WHERE u.user_key = p_user_key
    AND u.status = 'active'
    AND COALESCE(u.is_deleted, false) = false
    AND u.id <> auth.uid();
$$;

REVOKE EXECUTE ON FUNCTION public.find_invitable_user(text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.find_invitable_user(text) TO authenticated;
