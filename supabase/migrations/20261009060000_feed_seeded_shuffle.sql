-- 피드 정렬 개편: 상대 최신성 + 새로고침마다 바뀌는 시드 셔플
--
-- 기존 공식은 좋아요(0.4)+댓글(0.3)+최신성(0.3, 7일 선형 감쇠)였는데,
-- 피드에 7일 이내 글이 0건이라 최신성 항이 전부 0이 되어 사실상
-- 좋아요·댓글만으로 순위가 고정됐다. 들어올 때마다 같은 순서가 보인 이유다.
--
-- 바뀐 점
--  1) 절대 시간 감쇠 → percent_rank 기반 상대 최신성. 글이 뜸해도 가장 최근
--     글이 항상 1.0 을 받고, 나중에 글이 많아져도 자동으로 맞춰진다.
--  2) p_seed 로 결정적 지터 추가. 같은 시드면 항상 같은 순서라 커서
--     페이지네이션이 깨지지 않고, 새로고침 때 시드를 바꾸면 순서가 섞인다.
--
-- 가중치: 최신성 0.40 / 좋아요 0.25 / 댓글 0.15 / 지터 0.20

DROP FUNCTION IF EXISTS get_scored_feed_posts(INT, FLOAT8, TIMESTAMPTZ, UUID, UUID[]);

CREATE OR REPLACE FUNCTION get_scored_feed_posts(
  p_limit             INT           DEFAULT 20,
  p_before_score      FLOAT8        DEFAULT NULL,
  p_before_created_at TIMESTAMPTZ   DEFAULT NULL,
  p_before_id         UUID          DEFAULT NULL,
  p_blocked_user_ids  UUID[]        DEFAULT '{}'::UUID[],
  p_seed              TEXT          DEFAULT ''
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
  WITH base AS (
    SELECT
      p.id,
      p.user_id,
      p.league_id,
      p.image_url,
      p.image_urls,
      p.media,
      p.aspect_ratio::FLOAT8                                            AS aspect_ratio,
      p.video_url,
      p.youtube_url,
      p.caption,
      p.fish_type,
      p.length::FLOAT8                                                  AS length,
      p.weight::FLOAT8                                                  AS weight,
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
      -- 상대 최신성: 가장 최근 글 1.0, 가장 오래된 글 0.0
      PERCENT_RANK() OVER (ORDER BY p.created_at)                       AS recency_rank,
      -- 결정적 지터: 같은 (글, 시드) 조합이면 항상 같은 값 → 페이지네이션 안전
      (('x' || substr(md5(p.id::text || p_seed), 1, 8))::bit(32)::bigint
        / 4294967295.0)::FLOAT8                                         AS jitter
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
  ),
  scored AS (
    SELECT
      b.*,
      (
        b.recency_rank * 0.40 +
        LEAST(1.0, b.like_count::FLOAT8 / 20.0) * 0.25 +
        LEAST(1.0, b.comment_count::FLOAT8 / 10.0) * 0.15 +
        b.jitter * 0.20
      )::FLOAT8 AS feed_score
    FROM base b
  )
  SELECT
    s.id, s.user_id, s.league_id, s.image_url, s.image_urls, s.media,
    s.aspect_ratio, s.video_url, s.youtube_url, s.caption, s.fish_type,
    s.length, s.weight, s.catch_count, s.is_lunker, s.is_personal_record,
    s.review_status, s.location, s.created_at, s.username, s.avatar_url,
    s.user_key, s.like_count, s.comment_count, s.feed_score
  FROM scored s
  WHERE
    p_before_score IS NULL
    OR (s.feed_score < p_before_score)
    OR (s.feed_score = p_before_score AND s.created_at < p_before_created_at)
    OR (s.feed_score = p_before_score AND s.created_at = p_before_created_at AND s.id < p_before_id)
  ORDER BY s.feed_score DESC, s.created_at DESC, s.id DESC
  LIMIT p_limit;
END;
$$;

REVOKE ALL ON FUNCTION get_scored_feed_posts(INT, FLOAT8, TIMESTAMPTZ, UUID, UUID[], TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_scored_feed_posts(INT, FLOAT8, TIMESTAMPTZ, UUID, UUID[], TEXT) TO authenticated;
