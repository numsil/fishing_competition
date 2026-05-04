-- Add review_status column to posts table
-- Allows league hosts to mark catches as 'approved' or 'held' (pending review)

ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS review_status TEXT NOT NULL DEFAULT 'approved'
  CHECK (review_status IN ('approved', 'held'));

-- Index for efficient ranking queries filtering by review_status
CREATE INDEX IF NOT EXISTS idx_posts_league_review
  ON posts(league_id, review_status, score DESC)
  WHERE league_id IS NOT NULL;

-- Enable league hosts to update review_status on league posts only
CREATE POLICY "league host can update review_status"
  ON posts FOR UPDATE
  USING (
    league_id IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM leagues
      WHERE id = posts.league_id AND host_id = auth.uid()
    )
  )
  WITH CHECK (true);
