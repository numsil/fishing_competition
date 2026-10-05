-- 리그 순위 정렬 버그 수정
--
-- 문제: 룰이 '합산 길이'/'최대어' 일 때 ORDER BY가 합산 "점수"(sum_top_score)를
--       기준으로 정렬했는데, 앱 순위표에 표시되는 값은 합산 cm(total_length)였다.
--       점수 공식이 길이에 비선형(45cm↑ 3배 / 40~45cm 2배 / 미만 1.5배)이라
--       "큰 거 1마리(점수 높음, cm 낮음)"가 "작은 거 여러 마리"보다 위로 올라가는
--       역전이 발생 → 화면상 더 큰 합산 cm가 아래에 표시됨.
--
-- 수정: '무게'와 동일하게 실측 합산값(sum_top_measure)으로 정렬한다.
--       '마릿수'(count 우선)는 기존 동작 유지.
--       '최대어'(catch_limit=1)는 점수가 길이에 대해 단조증가이므로 순서 동일.
--
-- 함수 본문의 나머지 로직은 변경 없음 (ORDER BY 절만 수정).

CREATE OR REPLACE FUNCTION public.get_league_ranking(p_league_id uuid)
 RETURNS TABLE(user_id uuid, username text, avatar_url text, best_length numeric, total_length numeric, total_count integer, total_score integer, best_score integer, fish_type text, is_lunker boolean)
 LANGUAGE plpgsql
 STABLE
AS $function$
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
      -- 마릿수: count 우선
      CASE WHEN v_rule = '마릿수' THEN COALESCE(ua.cnt, 0) ELSE 0 END DESC,
      -- 무게(g) / 길이(cm) 모두 실측 합산값 기준 (표시값과 일치)
      COALESCE(tm.sum_top_measure, 0) DESC,
      COALESCE(ua.cnt, 0) DESC,
      COALESCE(ua.max_score, 0) DESC;
  END;
$function$;
