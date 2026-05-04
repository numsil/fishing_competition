-- catch_verifications: 인증 요청 1건
CREATE TABLE IF NOT EXISTS catch_verifications (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id       UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  submitter_id  UUID NOT NULL REFERENCES users(id),
  status        TEXT NOT NULL DEFAULT 'pending',
  approve_count INT NOT NULL DEFAULT 0,
  reject_count  INT NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at   TIMESTAMPTZ,
  UNIQUE(post_id)
);

-- verification_votes: 인증자 1명의 투표
CREATE TABLE IF NOT EXISTS verification_votes (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  verification_id     UUID NOT NULL REFERENCES catch_verifications(id) ON DELETE CASCADE,
  voter_id            UUID NOT NULL REFERENCES users(id),
  vote                TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  voted_at            TIMESTAMPTZ,
  UNIQUE(verification_id, voter_id)
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_verif_votes_voter ON verification_votes(voter_id) WHERE vote IS NULL;
CREATE INDEX IF NOT EXISTS idx_verif_votes_verif ON verification_votes(verification_id);
CREATE INDEX IF NOT EXISTS idx_catch_verif_post  ON catch_verifications(post_id);
CREATE INDEX IF NOT EXISTS idx_catch_verif_status ON catch_verifications(status);

-- RLS
ALTER TABLE catch_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE verification_votes  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "verif_select" ON catch_verifications FOR SELECT
  USING (
    submitter_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM verification_votes v
      WHERE v.verification_id = id AND v.voter_id = auth.uid()
    )
  );

CREATE POLICY "verif_insert" ON catch_verifications FOR INSERT
  WITH CHECK (submitter_id = auth.uid());

CREATE POLICY "vote_select" ON verification_votes FOR SELECT
  USING (voter_id = auth.uid());

CREATE POLICY "vote_insert" ON verification_votes FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM catch_verifications cv
      WHERE cv.id = verification_id AND cv.submitter_id != auth.uid()
    )
  );

CREATE POLICY "vote_update" ON verification_votes FOR UPDATE
  USING (voter_id = auth.uid())
  WITH CHECK (voter_id = auth.uid());
