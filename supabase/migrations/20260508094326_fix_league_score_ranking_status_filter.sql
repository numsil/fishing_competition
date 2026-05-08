CREATE OR REPLACE FUNCTION public.get_league_score_ranking(top_n integer DEFAULT 10, season_year integer DEFAULT NULL::integer)
RETURNS TABLE(user_id uuid, username text, avatar_url text, score integer)
LANGUAGE sql STABLE AS $$
  WITH season AS (
    SELECT
      (COALESCE(season_year, EXTRACT(YEAR FROM NOW())::int)::text || '-01-01')::timestamp AS s,
      ((COALESCE(season_year, EXTRACT(YEAR FROM NOW())::int) + 1)::text || '-01-01')::timestamp AS e
  ),
  catch_scores AS (
    SELECT p.user_id AS uid, COALESCE(SUM(p.score), 0)::int AS s
    FROM posts p
    JOIN leagues l ON l.id = p.league_id
    , season
    WHERE l.status IN ('in_progress', 'completed')
      AND p.review_status = 'approved'
      AND COALESCE(p.is_deleted, false) = false
      AND p.created_at >= season.s
      AND p.created_at < season.e
    GROUP BY p.user_id
  ),
  bonus_scores AS (
    SELECT lp.user_id AS uid, COALESCE(SUM(lp.rank_bonus), 0)::int AS s
    FROM league_participants lp, season
    WHERE lp.rank_bonus > 0
      AND lp.rank_bonus_earned_at >= season.s
      AND lp.rank_bonus_earned_at < season.e
    GROUP BY lp.user_id
  ),
  combined AS (
    SELECT uid, SUM(s)::int AS total
    FROM (
      SELECT uid, s FROM catch_scores
      UNION ALL
      SELECT uid, s FROM bonus_scores
    ) sub
    GROUP BY uid
  )
  SELECT u.id, u.username, u.avatar_url, c.total
  FROM combined c
  JOIN users u ON u.id = c.uid
  WHERE c.total > 0
  ORDER BY c.total DESC
  LIMIT top_n;
$$;
