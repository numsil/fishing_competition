-- 피드 RPC(get_scored_feed_posts)에서 댓글 수 집계 시 전체 스캔 방지
-- post_comments.post_id 인덱스 추가

CREATE INDEX IF NOT EXISTS idx_post_comments_post_id
  ON public.post_comments (post_id);