-- 피드 상단 팔로우 바 전용: 팔로잉 + 시즌(올해) max(league_score, angler_score)
-- TierAvatar 테두리 색 계산용. 기존 get_following과 분리 (성능 격리).

CREATE OR REPLACE FUNCTION public.get_following_with_max_score(
  p_user_id uuid,
  p_limit int DEFAULT 100
) RETURNS TABLE(
  user_id uuid,
  username text,
  user_key text,
  avatar_url text,
  is_lunker_club boolean,
  is_following boolean,
  followed_at timestamptz,
  max_score int
)
LANGUAGE sql STABLE
SET search_path = public
AS $$
  WITH season AS (
    SELECT
      date_trunc('year', now())                       AS season_start,
      date_trunc('year', now()) + interval '1 year'   AS season_end
  ),
  base AS (
    SELECT
      u.id,
      u.username,
      u.user_key,
      u.avatar_url,
      COALESCE(u.is_lunker_club, false) AS is_lunker_club,
      f.created_at                       AS followed_at
    FROM follows f
    JOIN users u ON u.id = f.followee_id
    WHERE f.follower_id = p_user_id
      AND COALESCE(u.is_deleted, false) = false
    ORDER BY f.created_at DESC
    LIMIT p_limit
  )
  SELECT
    b.id,
    b.username,
    b.user_key,
    b.avatar_url,
    b.is_lunker_club,
    CASE
      WHEN auth.uid() IS NULL OR auth.uid() = b.id THEN false
      ELSE EXISTS(
        SELECT 1 FROM follows f2
        WHERE f2.follower_id = auth.uid() AND f2.followee_id = b.id
      )
    END AS is_following,
    b.followed_at,
    GREATEST(
      -- league_score = catch score + rank bonus (시즌 범위)
      COALESCE((
        SELECT SUM(p.score)::int
        FROM posts p
        JOIN leagues l ON l.id = p.league_id
        WHERE p.user_id = b.id
          AND p.review_status = 'approved'
          AND COALESCE(p.is_deleted, false) = false
          AND p.created_at >= (SELECT season_start FROM season)
          AND p.created_at <  (SELECT season_end FROM season)
          AND l.status IN ('in_progress', 'completed')
      ), 0)
      + COALESCE((
        SELECT SUM(rank_bonus)::int
        FROM league_participants
        WHERE user_id = b.id AND rank_bonus > 0
          AND rank_bonus_earned_at >= (SELECT season_start FROM season)
          AND rank_bonus_earned_at <  (SELECT season_end FROM season)
      ), 0),
      -- angler_score = 개인 기록 합 (시즌 범위)
      COALESCE((
        SELECT SUM(score)::int
        FROM posts
        WHERE user_id = b.id AND is_personal_record = true
          AND review_status = 'approved'
          AND COALESCE(is_deleted, false) = false
          AND created_at >= (SELECT season_start FROM season)
          AND created_at <  (SELECT season_end FROM season)
      ), 0)
    ) AS max_score
  FROM base b
  ORDER BY b.followed_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_following_with_max_score(uuid, int) TO authenticated;
