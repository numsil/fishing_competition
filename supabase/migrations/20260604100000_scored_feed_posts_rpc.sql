-- 피드 인기도 혼합 정렬 RPC
-- 점수 = 좋아요(0.4) + 댓글(0.3) + 최신성(0.3)
-- 좋아요 20개·댓글 10개 기준으로 0~1 정규화, 최신성은 7일 선형 감쇠
-- 페이지네이션: (feed_score DESC, created_at DESC, id DESC) 복합 커서

CREATE OR REPLACE FUNCTION get_scored_feed_posts(
  p_limit             INT           DEFAULT 20,
  p_before_score      FLOAT8        DEFAULT NULL,
  p_before_created_at TIMESTAMPTZ   DEFAULT NULL,
  p_before_id         UUID          DEFAULT NULL,
  p_blocked_user_ids  UUID[]        DEFAULT '{}'::UUID[]
)
RETURNS TABLE (
  id                 UUID,
  user_id            UUID,
  league_id          UUID,
  image_url          TEXT,
  image_urls         TEXT[],
  media              JSONB,
  aspect_ratio       FLOAT8,
  video_url          TEXT,
  youtube_url        TEXT,
  caption            TEXT,
  fish_type          TEXT,
  length             FLOAT8,
  weight             FLOAT8,
  catch_count        INT,
  is_lunker          BOOLEAN,
  is_personal_record BOOLEAN,
  review_status      TEXT,
  location           TEXT,
  created_at         TIMESTAMPTZ,
  username           TEXT,
  avatar_url         TEXT,
  user_key           TEXT,
  like_count         BIGINT,
  comment_count      BIGINT,
  feed_score         FLOAT8
) LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH scored AS (
    SELECT
      p.id,
      p.user_id,
      p.league_id,
      p.image_url,
      p.image_urls,
      p.media,
      p.aspect_ratio::FLOAT8,
      p.video_url,
      p.youtube_url,
      p.caption,
      p.fish_type,
      p.length::FLOAT8,
      p.weight::FLOAT8,
      p.catch_count,
      p.is_lunker,
      p.is_personal_record,
      p.review_status,
      p.location,
      p.created_at,
      u.username,
      u.avatar_url,
      u.user_key,
      COALESCE(lk.cnt, 0)                                               AS like_count,
      COALESCE(cm.cnt, 0)                                               AS comment_count,
      (
        LEAST(1.0, COALESCE(lk.cnt, 0)::FLOAT8 / 20.0) * 0.4 +
        LEAST(1.0, COALESCE(cm.cnt, 0)::FLOAT8 / 10.0) * 0.3 +
        GREATEST(0.0, 1.0 - EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 604800.0) * 0.3
      )                                                                  AS feed_score
    FROM posts p
    JOIN users u ON u.id = p.user_id
    LEFT JOIN (
      SELECT post_id, COUNT(*) AS cnt FROM post_likes GROUP BY post_id
    ) lk ON lk.post_id = p.id
    LEFT JOIN (
      SELECT post_id, COUNT(*) AS cnt FROM post_comments GROUP BY post_id
    ) cm ON cm.post_id = p.id
    WHERE
      p.league_id IS NULL
      AND p.is_personal_record = FALSE
      AND (p.is_deleted IS NULL OR p.is_deleted = FALSE)
      AND (
        array_length(p_blocked_user_ids, 1) IS NULL
        OR p.user_id != ALL(p_blocked_user_ids)
      )
  )
  SELECT *
  FROM scored
  WHERE
    p_before_score IS NULL
    OR (scored.feed_score < p_before_score)
    OR (scored.feed_score = p_before_score AND scored.created_at < p_before_created_at)
    OR (scored.feed_score = p_before_score AND scored.created_at = p_before_created_at AND scored.id < p_before_id)
  ORDER BY scored.feed_score DESC, scored.created_at DESC, scored.id DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION get_scored_feed_posts TO authenticated;
