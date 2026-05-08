-- 마릿수 규칙에서 조과 점수를 마릿수×10 고정이 아닌
-- 인증된 길이 기반 실제 점수 합산으로 변경.
--
-- 기존: v_limit=0 → LIMIT 0 → sum=0 → count*10 fallback
-- 변경: NULLIF(v_limit, 0) → LIMIT NULL = 전체, sum_top_score 그대로 사용
-- 순위 기준(ORDER BY)은 마릿수 rule에서 여전히 count 우선 유지.

CREATE OR REPLACE FUNCTION public.get_league_ranking(p_league_id uuid)
RETURNS TABLE(
  user_id uuid,
  username text,
  avatar_url text,
  best_length numeric,
  total_length numeric,
  total_count integer,
  total_score integer,
  best_score integer,
  fish_type text,
  is_lunker boolean
)
LANGUAGE plpgsql STABLE
AS $$
  DECLARE
    v_rule text;
    v_limit int;
  BEGIN
    SELECT COALESCE(l.rule, '합산 길이'), COALESCE(l.catch_limit, 1)
    INTO v_rule, v_limit
    FROM leagues l WHERE l.id = p_league_id;

    IF v_rule IS NULL THEN
      RETURN;
    END IF;

    RETURN QUERY
    WITH user_posts AS (
      SELECT
        p.user_id AS uid,
        p.score AS sc,
        CASE WHEN v_rule = '무게' THEN p.weight ELSE p.length END AS measure,
        p.fish_type AS ft,
        p.is_lunker AS lunker_flag
      FROM posts p
      WHERE p.league_id = p_league_id
        AND p.review_status = 'approved'
        AND COALESCE(p.is_deleted, false) = false
    ),
    user_aggregates AS (
      SELECT
        up.uid,
        MAX(up.measure) AS max_measure,
        COUNT(*)::int AS cnt,
        COALESCE(MAX(up.sc), 0)::int AS max_score,
        bool_or(COALESCE(up.lunker_flag, false)) AS lunker
      FROM user_posts up
      GROUP BY up.uid
    ),
    top_measures AS (
      SELECT
        uids.uid,
        COALESCE(SUM(t.m), 0) AS sum_top_measure
      FROM (SELECT DISTINCT uid FROM user_posts) uids
      LEFT JOIN LATERAL (
        SELECT up.measure AS m
        FROM user_posts up
        WHERE up.uid = uids.uid AND up.measure IS NOT NULL
        ORDER BY up.measure DESC
        LIMIT NULLIF(v_limit, 0)
      ) t ON true
      GROUP BY uids.uid
    ),
    top_scores AS (
      SELECT
        uids.uid,
        COALESCE(SUM(t.s), 0)::int AS sum_top_score
      FROM (SELECT DISTINCT uid FROM user_posts) uids
      LEFT JOIN LATERAL (
        SELECT up.sc AS s
        FROM user_posts up
        WHERE up.uid = uids.uid
        ORDER BY up.sc DESC
        LIMIT NULLIF(v_limit, 0)
      ) t ON true
      GROUP BY uids.uid
    ),
    user_fish AS (
      SELECT DISTINCT ON (up.uid) up.uid, up.ft AS chosen_ft
      FROM user_posts up
      ORDER BY up.uid, up.ft
    )
    SELECT
      p.user_id,
      u.username,
      u.avatar_url,
      ua.max_measure,
      COALESCE(tm.sum_top_measure, 0::numeric),
      COALESCE(ua.cnt, 0),
      COALESCE(ts.sum_top_score, 0),
      COALESCE(ua.max_score, 0),
      COALESCE(uf.chosen_ft, '배스'),
      COALESCE(ua.lunker, false)
    FROM league_participants p
    JOIN users u ON u.id = p.user_id
    LEFT JOIN user_aggregates ua ON ua.uid = p.user_id
    LEFT JOIN top_measures tm ON tm.uid = p.user_id
    LEFT JOIN top_scores ts ON ts.uid = p.user_id
    LEFT JOIN user_fish uf ON uf.uid = p.user_id
    WHERE p.league_id = p_league_id
      AND p.status = 'approved'
    ORDER BY
      CASE WHEN v_rule = '마릿수' THEN COALESCE(ua.cnt, 0) ELSE 0 END DESC,
      COALESCE(ts.sum_top_score, 0) DESC,
      COALESCE(ua.cnt, 0) DESC,
      COALESCE(ua.max_score, 0) DESC;
  END;
  $$;
