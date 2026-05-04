ALTER TABLE league_participants
  ADD COLUMN IF NOT EXISTS rank_bonus integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rank_bonus_earned_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_lp_rank_bonus_user
  ON league_participants (user_id, rank_bonus_earned_at)
  WHERE rank_bonus > 0;
